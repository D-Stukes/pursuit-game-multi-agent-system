extends RefCounted
## Authoritative session memory for social NPCs, separate from course progress.
const DATA_PATH: String = "res://assets/characters/npc-dialogue.json"
var data: Dictionary
var memories: Dictionary = {}
var public_memories: Dictionary = {}
var met_npcs: Dictionary = {}
var greeting_counts: Dictionary = {}
var gossip_told: Dictionary = {}
## Story progress the game shares before each conversation (see NPCConversations._progress_facts).
var progress: Dictionary = {}
## Question variants each character has answered, for follow-ups and repeats.
var asked: Dictionary = {}
## Newest first, so the latest milestone is the one mentioned.
const MILESTONES: Array[String] = ["classroom","checked_in","elevator","entrance"]

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(data.schema == 1)

func memory(npc_id: String, public: bool = false) -> Dictionary:
	var source: Dictionary = public_memories if public else memories
	var initial: Dictionary = {"turn_count":0,"topics":[],"lines":[]}
	if is_builder(npc_id) and not public: initial.facts={"style":"brief","hints_given":0}
	return source.get(npc_id,initial).duplicate(true)

func is_builder(npc_id: String) -> bool:
	return data.profiles.get(npc_id,{}).get("mode","") == "builder"

## Each question slot can change with progress and what was already asked; the first fitting variant wins.
func slot_variant(npc_id: String, slot: String) -> Dictionary:
	var done: Array = asked.get(npc_id,[])
	for variant: Dictionary in data.profiles[npc_id].get("slots",{}).get(slot,[]):
		if variant.has("after") and not progress.get(variant.after,false): continue
		if variant.has("before") and progress.get(variant.before,false): continue
		if variant.has("requires") and variant.requires not in done: continue
		if variant.get("once",false) and variant.id in done: continue
		return variant
	return {}

func topics_for(npc_id: String) -> Dictionary:
	var result: Dictionary=data.profiles[npc_id].get("topics",data.topics).duplicate(true)
	for slot: String in result.keys():
		var variant: Dictionary = slot_variant(npc_id,slot)
		if not variant.is_empty(): result[slot] = variant.ask
	if not is_builder(npc_id):result["roam"]="Go explore — I’ll catch up with you."
	return result

func greeting(npc_id: String, facts: Dictionary = {}) -> String:
	var profile: Dictionary=data.profiles[npc_id]
	# Memory: people you have already met remember each milestone you reach after meeting them
	# (solved or skipped) and mention it once the next time you talk. Milestones reached before
	# you met someone are simply what they know when you meet.
	var told: Array = gossip_told.get(npc_id,[])
	if not met_npcs.has(npc_id):
		for fact: String in MILESTONES:
			if facts.get(fact,false) and fact not in told: told.append(fact)
		gossip_told[npc_id] = told
	for fact: String in MILESTONES:
		if not facts.get(fact,false) or fact in told: continue
		# Only the newest new milestone matters; the older ones are understood. If this person has
		# nothing to say about it, they say nothing rather than bring up something stale.
		for other: String in MILESTONES:
			if facts.get(other,false) and other not in told: told.append(other)
		gossip_told[npc_id] = told
		var line: String = str(profile.get("gossip",{}).get(fact,""))
		if line.is_empty(): break
		return line.format({"name":str(facts.get("name","")).strip_edges() if not str(facts.get("name","")).strip_edges().is_empty() else "friend"})
	var count: int=int(greeting_counts.get(npc_id,0));greeting_counts[npc_id]=count+1
	var greetings: Array=profile.get("greetings",[])
	if not greetings.is_empty():return greetings[count%greetings.size()]
	return profile.return_greeting if met_npcs.has(npc_id) else profile.greeting

func local_reply(npc_id: String, topic: String, world: Dictionary = {}) -> String:
	var profile: Dictionary = data.profiles[npc_id]
	if is_builder(npc_id):
		var catalogue: Dictionary = data.builder_help
		var objective: String = catalogue.objectives[world.stage]
		var arrival_hint: String = catalogue.get("arrival_hints",{}).get(world.stage,catalogue.pending)
		if world.stage not in ["entrance","elevator"] and topic == "next":
			return objective+" "+(str(catalogue.travel[world.zone]) if world.challenge.kind=="travel" else arrival_hint)
		if topic == "next": return objective
		var challenge: Dictionary = world.challenge
		var hint: String = arrival_hint
		if challenge.kind == "pipe":
			var fields: Dictionary = challenge.duplicate(true)
			fields.ports = " and ".join(challenge.ports)
			hint = str(catalogue.pipe[challenge.phase]).format(fields)
		elif challenge.kind == "shooter":
			hint = str(catalogue.shooter.get(challenge.phase,catalogue.shooter.playing)).format(challenge)
		elif challenge.kind == "travel":
			hint = str(catalogue.travel[world.zone])
		if topic == "steps" or memory(npc_id).facts.style == "steps":
			return "1. %s\n2. %s\n3. Try it, then ask again if you need another hint."%[objective,hint]
		return hint
	if topic == "ambient":
		return profile.ambient[int(memory(npc_id, true).turn_count) % profile.ambient.size()]
	var variant: Dictionary = slot_variant(npc_id,topic)
	if not variant.is_empty():
		var replies: Array = variant.reply if variant.reply is Array else [variant.reply]
		var times: int = Array(asked.get(npc_id,[])).count(variant.id)
		return ("We talked about that earlier. " if times > 0 else "")+str(replies[times%replies.size()])
	var variants: Array=profile.get("local_variants",{}).get(topic,[])
	var line: String = str(variants[int(memory(npc_id).turn_count)%variants.size()]) if not variants.is_empty() else str(profile.local[topic])
	return "We talked about that earlier. " + line if topic in memory(npc_id).topics else line

func remember(npc_id: String, topic: String, text: String) -> void:
	var variant: Dictionary = {} if topic == "ambient" or is_builder(npc_id) else slot_variant(npc_id,topic)
	if not variant.is_empty():
		var done: Array = asked.get(npc_id,[]);done.append(variant.id);asked[npc_id] = done
	var public: bool = topic == "ambient"
	var record: Dictionary = memory(npc_id, public)
	record.turn_count += 1
	record.topics.append(topic)
	record.lines.append(text)
	if is_builder(npc_id):
		if topic == "steps": record.facts.style = "steps"
		if topic in ["hint","steps"]: record.facts.hints_given += 1
	while record.topics.size() > 2: record.topics.pop_front()
	while record.lines.size() > 2: record.lines.pop_front()
	var source: Dictionary = public_memories if public else memories
	source[npc_id] = record

func payload(npc_id: String, topic: String, request_id: String, world: Dictionary, context: String = "") -> Dictionary:
	return {"schema":2 if is_builder(npc_id) else 1,"request_id":request_id,"npc_id":npc_id,"topic":topic,
		"memory":memory(npc_id, topic == "ambient"),"world":world.duplicate(true),"ambient_context":context}
