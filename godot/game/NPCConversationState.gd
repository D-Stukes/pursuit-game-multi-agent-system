extends RefCounted
## Authoritative session memory for social NPCs, separate from course progress.
const DATA_PATH: String = "res://assets/characters/npc-dialogue.json"
var data: Dictionary
var memories: Dictionary = {}
var public_memories: Dictionary = {}
var met_npcs: Dictionary = {}

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

func topics_for(npc_id: String) -> Dictionary:
	return data.profiles[npc_id].get("topics",data.topics).duplicate(true)

func greeting(npc_id: String) -> String:
	return data.profiles[npc_id].return_greeting if met_npcs.has(npc_id) else data.profiles[npc_id].greeting

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
	var line: String = profile.local[topic]
	return "We talked about that earlier. " + line if topic in memory(npc_id).topics else line

func remember(npc_id: String, topic: String, text: String) -> void:
	var public: bool = topic == "ambient"
	var record: Dictionary = memory(npc_id, public)
	record.turn_count += 1
	record.topics.append(topic)
	record.lines.append(text)
	if is_builder(npc_id):
		if topic == "steps": record.facts.style = "steps"
		if topic in ["hint","steps"]: record.facts.hints_given += 1
	while record.topics.size() > (2 if is_builder(npc_id) else 8): record.topics.pop_front()
	while record.lines.size() > (2 if is_builder(npc_id) else 6): record.lines.pop_front()
	var source: Dictionary = public_memories if public else memories
	source[npc_id] = record

func payload(npc_id: String, topic: String, request_id: String, world: Dictionary, context: String = "") -> Dictionary:
	return {"schema":2 if is_builder(npc_id) else 1,"request_id":request_id,"npc_id":npc_id,"topic":topic,
		"memory":memory(npc_id, topic == "ambient"),"world":world.duplicate(true),"ambient_context":context}
