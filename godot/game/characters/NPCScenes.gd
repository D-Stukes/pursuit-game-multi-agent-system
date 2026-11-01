extends Node
## Overheard scenes: when two people are standing near each other and the player is within
## earshot, they trade a few written lines in bubbles over their heads, facing each other. Scenes
## play once per session, some only after (or before) a milestone. Scripted only; nothing changes
## progress.
const DATA_PATH: String = "res://assets/characters/npc-dialogue.json"
var world: Node3D
var population: Node3D
var scenes: Array = []
var settings: Dictionary
var played: Array[String] = []
var active: Dictionary = {}
var cooldown: float = 0
var line_index: int = 0
var line_remaining: float = 0

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	scenes = data.scenes;settings = data.scene_settings
	cooldown = float(settings.first_delay)

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
		active = {"scene":scene,"people":[a,b]}
		line_index = 0;line_remaining = 0
		played.append(scene.id)
		return

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
	var lines: Array = active.scene.lines
	# Someone was spoken to, wandered off or the player left earshot: the scene ends quietly.
	var player: Vector3 = world.player.global_position
	var broken: bool = people.any(func(body: CharacterBody3D): return not body.routine.in_scene() or body.routine.talking or not body.visible or body.global_position.distance_to(player) > float(settings.hear_distance)+3.0)
	if broken or world.building_review_mode:
		_finish();return
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
	for body: CharacterBody3D in active.get("people",[]):
		body.routine.leave_scene()
		world.npc_conversations.bubbles.clear(body)
	active = {}
	cooldown = float(settings.cooldown)
