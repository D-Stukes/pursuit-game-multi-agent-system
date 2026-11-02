extends Node
## Overheard scenes: when two people are standing near each other and the player is within
## earshot, they trade a few written lines in bubbles over their heads, facing each other. Scenes
## play once per session, some only after (or before) a milestone. With the NPC service on
## (--agents), a scene first asks for a fresh take written from both characters' cards and waits a
## moment while they face each other; the written lines play if it doesn't come or doesn't check
## out. Nothing changes progress.
const DATA_PATH: String = "res://assets/characters/npc-dialogue.json"
const ServiceClient = preload("res://game/NPCServiceClient.gd")
## The service gives up after six seconds; waiting a little longer means a reply it was charged
## for is never thrown away.
const LIVE_WAIT: float = 6.5
const LIVE_MAX_TOKENS: int = 260
const LIVE_MAX_CHARS: int = 140
var world: Node3D
var population: Node3D
var scenes: Array = []
var settings: Dictionary
var played: Array[String] = []
var active: Dictionary = {}
var cooldown: float = 0
var line_index: int = 0
var line_remaining: float = 0
var client: Node
var request_serial: int = 0
var live_requests: int = 0
## The last scene that ended: its id and whether its lines were "written" or "claude".
var last_scene: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	scenes = data.scenes;settings = data.scene_settings
	cooldown = float(settings.first_delay)
	client = ServiceClient.new();client.name = "SceneClient"
	add_child(client)
	client.completed.connect(_live_received)
	client.failed.connect(_live_failed)

func person(id: String) -> CharacterBody3D:
	return population.get_node_or_null(NodePath(id))

func update(delta: float) -> void:
	if not active.is_empty():
		_continue(delta);return
	cooldown = maxf(0, cooldown-delta)
	if cooldown > 0 or world.building_review_mode or world.npc_conversations.dialogue.visible or world.npc_conversations.ambient_active: return
	var facts: Dictionary = world.npc_conversations._progress_facts()
	for scene: Dictionary in scenes:
		if scene.id in played or not _fits(scene, facts): continue
		var a: CharacterBody3D = person(scene.speakers[0])
		var b: CharacterBody3D = person(scene.speakers[1])
		if not _can_start(a, b): continue
		if not a.routine.join_scene(b.global_position+Vector3.UP*1.55): continue
		if not b.routine.join_scene(a.global_position+Vector3.UP*1.55):
			a.routine.leave_scene();continue
		active = {"scene":scene,"people":[a,b],"lines":scene.lines,"source":"written"}
		line_index = 0;line_remaining = 0
		played.append(scene.id)
		_ask_live(scene)
		return

## One request per scene, only when the service is on and both speakers can be voiced.
func _ask_live(scene: Dictionary) -> void:
	var social: Node = world.npc_conversations
	if social.client.provider != "claude": return
	for actor: Variant in scene.speakers:
		if not social.state.in_scene_cast(social.profile_for_actor(str(actor))): return
	client.provider = social.client.provider;client.base_url = social.client.base_url
	client.timeout_seconds = LIVE_WAIT
	request_serial += 1
	var body: Dictionary = {"schema":4,"request_id":"scene-%d"%request_serial,"scene_id":str(scene.id)}
	if client.start(body) != OK: return
	active.request_id = body.request_id
	live_requests += 1

func _live_received(request_id: String, result: Dictionary) -> void:
	if active.get("request_id","") != request_id: return
	active.erase("request_id")
	var lines: Array = _live_lines(result)
	if lines.is_empty(): return
	active.lines = lines;active.source = "claude"

func _live_failed(request_id: String, _reason: String) -> void:
	if active.get("request_id","") == request_id: active.erase("request_id")

## Lines a scene can play: two to four, taking turns, short plain text, from one call.
func _live_lines(result: Dictionary) -> Array:
	if not world.npc_conversations.valid_character_usage(result,LIVE_MAX_TOKENS): return []
	var lines: Array = result.lines
	if lines.size() < 2 or lines.size() > 4: return []
	var checked: Array = []
	for line: Variant in lines:
		if not line is Array or line.size() != 2 or not (line[0] is int or line[0] is float) or not line[1] is String: return []
		if float(line[0]) != 0.0 and float(line[0]) != 1.0: return []
		var speaker: int = int(line[0])
		var text: String = str(line[1]).strip_edges()
		if text.is_empty() or text.length() > LIVE_MAX_CHARS: return []
		if not checked.is_empty() and checked[-1][0] == speaker: return []
		checked.append([speaker,text])
	return checked

func _fits(scene: Dictionary, facts: Dictionary = {}) -> bool:
	if facts.is_empty(): facts = world.npc_conversations._progress_facts()
	if scene.has("after") and not facts.get(scene.after,false): return false
	if scene.has("before") and facts.get(scene.before,false): return false
	return true

func _can_start(a: CharacterBody3D, b: CharacterBody3D) -> bool:
	if a == null or b == null or not a.visible or not b.visible: return false
	if not population.life_actor(a) or not population.life_actor(b): return false
	if a.global_position.distance_to(b.global_position) > float(settings.pair_distance) or absf(a.global_position.y-b.global_position.y) > .5: return false
	var player: Vector3 = world.player.global_position
	var hear: float = float(settings.hear_distance)
	return absf(player.y-a.global_position.y) < 1.5 and a.global_position.distance_to(player) < hear and b.global_position.distance_to(player) < hear

func _continue(delta: float) -> void:
	var people: Array = active.people
	var lines: Array = active.lines
	# Someone was spoken to, wandered off or the player left earshot: the scene ends quietly.
	var player: Vector3 = world.player.global_position
	var broken: bool = people.any(func(body: CharacterBody3D): return not body.routine.in_scene() or body.routine.talking or not body.visible or body.global_position.distance_to(player) > float(settings.hear_distance)+3.0)
	if broken or world.building_review_mode:
		_finish();return
	# Waiting for the live take: they face each other quietly until it arrives or times out.
	if active.has("request_id"): return
	line_remaining -= delta
	if line_remaining > 0: return
	if line_index >= lines.size():
		_finish();return
	var speaker: int = int(lines[line_index][0])
	if not world.npc_conversations.bubble(people[speaker], str(lines[line_index][1]), float(settings.line_seconds), people):
		_finish();return
	for i: int in range(people.size()):
		people[i].routine.scene_clip = "Interact" if i == speaker else "Idle_Neutral"
	line_index += 1
	line_remaining = float(settings.line_seconds)

func _finish() -> void:
	client.cancel()
	if not active.is_empty(): last_scene = {"id":active.scene.id,"source":active.source}
	for body: CharacterBody3D in active.get("people",[]):
		body.routine.leave_scene()
		world.npc_conversations.bubbles.clear(body)
	active = {}
	cooldown = float(settings.cooldown)
