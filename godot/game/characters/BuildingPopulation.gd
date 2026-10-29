extends Node3D
## Shared scene resources, explicit placements and one timer for the whole population.
const ActorScene: PackedScene = preload("res://scenes/characters/AmbientNPC.tscn")
const DATA_PATH: String = "res://assets/characters/population.json"
const MAX_ACTIVE_IDLE: int = 8
const ANIMATION_DISTANCE: float = 18.0
var actors: Array[CharacterBody3D] = []
var world: Node3D
var player: CharacterBody3D
var ready_for_test: bool = false
var resources: Dictionary = {}
var timer: Timer
var active_count: int = 0

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(data.schema == 1 and data.coordinates == "Godot XYZ metres")
	for id: String in data.models:
		resources[id] = load(data.models[id])
	for record: Dictionary in data.placements:
		var actor: CharacterBody3D = ActorScene.instantiate()
		add_child(actor)
		actor.configure(resources[record.model], record, actors.size())
		actors.append(actor)
	# World collision is registered on the next physics frame. Snap only within
	# the expected floor band so a bad placement cannot jump to a different floor.
	await get_tree().physics_frame
	for actor: CharacterBody3D in actors:
		var p: Vector3 = actor.global_position
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3, p-Vector3.UP*.45, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty() and hit.normal.y > .9, "NPC lacks a supporting floor: "+str(actor.name))
		actor.global_position.y = hit.position.y
		actor.prepare_routine()
	timer = Timer.new()
	timer.wait_time = .2
	timer.timeout.connect(update_budget)
	add_child(timer)
	timer.start()
	update_budget()
	ready_for_test = true

func update_budget() -> void:
	if not is_instance_valid(player): return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var nearby: Array[CharacterBody3D] = []
	for actor: CharacterBody3D in actors:
		var same_floor: bool = absf(actor.global_position.y-player.global_position.y) < 2.0
		var in_range: bool = actor.global_position.distance_squared_to(player.global_position) < ANIMATION_DISTANCE*ANIMATION_DISTANCE
		var on_screen: bool = camera != null and camera.is_position_in_frustum(actor.global_position+Vector3.UP)
		if same_floor and in_range and on_screen: nearby.append(actor)
	nearby.sort_custom(func(a: CharacterBody3D,b: CharacterBody3D): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	active_count = mini(nearby.size(), MAX_ACTIVE_IDLE)
	for actor: CharacterBody3D in actors:
		var index: int = nearby.find(actor)
		actor.set_animation_active(index >= 0 and index < active_count and not world.hud.menu_open)

func _physics_process(delta: float) -> void:
	if not ready_for_test or world==null or not world.ready_for_test: return
	var allowed: bool = world.npc_conversations.can_operate() and not world.npc_conversations.dialogue.visible and not world.npc_conversations.ambient_active
	for actor: CharacterBody3D in actors:
		var distance: float = actor.global_position.distance_squared_to(player.global_position)
		var nearby: bool = absf(actor.global_position.y-player.global_position.y)<2 and distance<ANIMATION_DISTANCE*ANIMATION_DISTANCE
		actor.update_routine(delta,allowed and nearby and distance>.75*.75)
