extends RefCounted
## Authoritative session memory for social NPCs, separate from course progress.
const DATA_PATH: String = "res://assets/characters/npc-dialogue.json"
var data: Dictionary
var memories: Dictionary = {}
var public_memories: Dictionary = {}

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(data.schema == 1)

func memory(npc_id: String, public: bool = false) -> Dictionary:
	var source: Dictionary = public_memories if public else memories
	return source.get(npc_id, {"turn_count":0,"topics":[],"lines":[]}).duplicate(true)

func greeting(npc_id: String) -> String:
	return data.profiles[npc_id].return_greeting if memory(npc_id).turn_count > 0 else data.profiles[npc_id].greeting

func local_reply(npc_id: String, topic: String) -> String:
	var profile: Dictionary = data.profiles[npc_id]
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
	while record.topics.size() > 8: record.topics.pop_front()
	while record.lines.size() > 6: record.lines.pop_front()
	var source: Dictionary = public_memories if public else memories
	source[npc_id] = record

func payload(npc_id: String, topic: String, request_id: String, world: Dictionary, context: String = "") -> Dictionary:
	return {"schema":1,"request_id":request_id,"npc_id":npc_id,"topic":topic,
		"memory":memory(npc_id, topic == "ambient"),"world":world.duplicate(true),"ambient_context":context}
