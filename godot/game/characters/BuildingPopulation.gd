extends Node3D
## Shared scene resources, explicit placements and one timer for the whole population.
const ActorScene: PackedScene = preload("res://scenes/characters/AmbientNPC.tscn")
const DATA_PATH: String = "res://assets/characters/population.json"
const LIFE_PATH: String = "res://assets/characters/npc-life.json"
const Life = preload("res://game/characters/NPCLife.gd")
const MAX_ACTIVE_IDLE: int = 8
const ANIMATION_DISTANCE: float = 18.0
var actors: Array[CharacterBody3D] = []
var world: Node3D
var player: CharacterBody3D
var ready_for_test: bool = false
var resources: Dictionary = {}
var timer: Timer
var active_count: int = 0
var travel: Node
var life_data: Dictionary
var life_places: Array[Dictionary] = []
var claims: Dictionary = {}
var navigation: NavigationRegion3D

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
	_load_life()
	# World collision is registered on the next physics frame. Snap only within
	# the expected floor band so a bad placement cannot jump to a different floor.
	await get_tree().physics_frame
	for actor: CharacterBody3D in actors:
		var p: Vector3 = actor.global_position
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3, p-Vector3.UP*.45, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty() and hit.normal.y > .9, "NPC lacks a supporting floor: "+str(actor.name))
		actor.global_position.y = hit.position.y
		if life_data.actors.has(str(actor.name)):
			actor.prepare_life(Life.new(str(actor.name),life_data.actors[actor.name],life_places,life_data.actions,claims,plan_path,area_open))
		else: actor.prepare_routine()
	timer = Timer.new()
	timer.wait_time = .2
	timer.timeout.connect(update_budget)
	add_child(timer)
	timer.start()
	update_budget()
	travel=preload("res://game/characters/NPCTravel.gd").new()
	travel.world=world;travel.population=self;add_child(travel)
	ready_for_test = true

## Everyday places and the baked walkable floor. People never award progress.
func _load_life() -> void:
	life_data = JSON.parse_string(FileAccess.get_file_as_string(LIFE_PATH))
	assert(life_data.schema == 1, "Unexpected NPC life schema")
	for record: Dictionary in life_data.places:
		var place: Dictionary = record.duplicate(true)
		place.position = Vector3(record.position[0],record.position[1],record.position[2])
		place.face = Vector3(record.face[0],record.face[1],record.face[2])
		assert(life_data.actions.has(place.action), "Unknown NPC action "+str(place.action))
		life_places.append(place)
	navigation = NavigationRegion3D.new()
	navigation.name = "NPCNavigation"
	navigation.navigation_mesh = load(life_data.navigation)
	add_child(navigation)

func plan_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map: RID = get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map,NavigationServer3D.map_get_closest_point(map,from),to,true)

func area_open(area: String) -> bool:
	return area in ["street","upper"]

func people_summary() -> PackedStringArray:
	var lines := PackedStringArray()
	for actor: CharacterBody3D in actors:
		if not life_actor(actor): continue
		var life: RefCounted = actor.routine
		var doing: String = "talking" if life.talking else ("walking to " if life.phase=="walk" else "at ")+str(life.place.get("id","—"))
		lines.append("%s · %s · %s" % [actor.name,doing,life.reason])
	return lines

func life_actor(actor: Node3D) -> bool:
	return actor.routine != null and actor.routine.has_method("explore")

func update_budget() -> void:
	if not is_instance_valid(player): return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var nearby: Array[CharacterBody3D] = []
	for actor: CharacterBody3D in actors:
		var same_floor: bool = absf(actor.global_position.y-player.global_position.y) < 2.0
		# Everyday people walk the whole floor, so animate them wherever they are on screen.
		var reach: float = ANIMATION_DISTANCE*2 if life_actor(actor) else ANIMATION_DISTANCE
		var in_range: bool = actor.global_position.distance_squared_to(player.global_position) < reach*reach
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
	travel.update(delta,allowed)
	# The walkable floor syncs a physics step after it is added; plan only once it is live.
	var navigation_ready: bool = NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
	for actor: CharacterBody3D in actors:
		if travel.active(actor):continue
		if life_actor(actor) and not navigation_ready:continue
		var distance: float = actor.global_position.distance_squared_to(player.global_position)
		var nearby: bool = absf(actor.global_position.y-player.global_position.y)<2 and distance<ANIMATION_DISTANCE*ANIMATION_DISTANCE
		# Everyday life keeps going across the player's whole floor; authored loops stay local.
		if life_actor(actor): nearby = (actor.global_position.y>3.0) == (player.global_position.y>3.0)
		var close: bool = distance<=.75*.75
		actor.update_routine(delta,allowed and nearby and not close)
		# Someone stopped by the player standing in their way eventually picks another spot.
		if close and allowed and nearby and life_actor(actor): actor.routine.report_blocked(delta)
