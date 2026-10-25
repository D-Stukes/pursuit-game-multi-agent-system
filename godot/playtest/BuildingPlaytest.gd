extends Node3D
## Local movement/camera proof. This does not modify the imported building.

signal lift_finished

const PlayerController = preload("res://playtest/BuildingPlayer.gd")
const ExteriorBackdrop = preload("res://playtest/ExteriorBackdrop.gd")
const PlaytestHUD = preload("res://playtest/PlaytestHUD.gd")
const BUILDING_PATH: String = "res://assets/generated/pursuit-building.glb"
const LOCATIONS: Array[Vector3] = [Vector3(0, 0, 6.7), Vector3(8.3, 5.05, -12.8), Vector3(18.56, 5.05, -2.0)]
const LOCATION_NAMES: Array[String] = ["Street entrance", "Second-floor reception", "Classroom"]
const LIFT_GROUND := Vector3(-0.95, 0.85, -12.1)
const LIFT_UPPER := Vector3(-0.95, 5.05, -12.1)

var player: CharacterBody3D
var mesh_count: int = 0
var collision_triangles: int = 0
var last_location: int = 0
var status_label: Label
var hud: Control
var ready_for_test: bool = false
var lift_in_progress: bool = false

func _ready() -> void:
	_build_lighting()
	_build_hud()
	if not ResourceLoader.exists(BUILDING_PATH):
		status_label.text = "Building asset missing. Run python tools/prepare_playtest.py from the repo root, then import the Godot project."
		push_error(status_label.text)
		return
	var packed: PackedScene = load(BUILDING_PATH)
	var building: Node3D = packed.instantiate()
	building.name = "Building"
	add_child(building)
	var faces := PackedVector3Array()
	_collect_faces(building, faces)
	var static_body := StaticBody3D.new()
	static_body.name = "BuildingCollision"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	static_body.add_child(collision)
	add_child(static_body)
	collision_triangles = faces.size() / 3
	add_child(ExteriorBackdrop.new())
	player = CharacterBody3D.new()
	player.set_script(PlayerController)
	add_child(player)
	player.reset_requested.connect(func(): go_location(last_location))
	go_location(0)
	ready_for_test = true
	print("BUILDING_READY meshes=", mesh_count, " triangles=", collision_triangles)

func _collect_faces(node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		mesh_count += 1
		var vertices: PackedVector3Array = node.mesh.get_faces()
		for vertex: Vector3 in vertices:
			faces.append(node.global_transform * vertex)
	for child: Node in node.get_children():
		_collect_faces(child, faces)

func _build_lighting() -> void:
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.38, 0.60, 0.77)
	sky_material.sky_horizon_color = Color(0.91, 0.84, 0.70)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color(0.36, 0.38, 0.36)
	sky_material.sky_curve = 0.3
	sky_material.sun_angle_max = 3.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.92, 0.95, 1.0)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0018
	environment.fog_light_color = Color(0.72, 0.80, 0.84)
	environment.fog_sky_affect = 0.15
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	# Keep the accepted room lighting; place only the visible disk above the street.
	var sky_sun := DirectionalLight3D.new()
	sky_sun.name = "BackdropSun"
	sky_sun.rotation_degrees = Vector3(-18, -25, 0)
	sky_sun.light_color = Color(1.0, 0.87, 0.61)
	sky_sun.light_angular_distance = 1.0
	sky_sun.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	add_child(sky_sun)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = PlaytestHUD.new()
	layer.add_child(hud)
	status_label = hud.floor_label
	hud.menu_requested.connect(set_menu_open)
	hud.location_requested.connect(func(index: int): go_location(index); set_menu_open(false))

func set_menu_open(open: bool) -> void:
	if not ready_for_test:
		return
	hud.set_menu_open(open)
	player.set_controls_locked(open or lift_in_progress)

func _input(event: InputEvent) -> void:
	if ready_for_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3 and OS.is_debug_build():
		var close_debug: bool = hud.menu_open and hud.debug_mode
		hud.set_debug_mode(not close_debug)
		set_menu_open(not close_debug)
		get_viewport().set_input_as_handled()
	if ready_for_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_menu_open(not hud.menu_open)
		get_viewport().set_input_as_handled()

func go_location(index: int) -> void:
	if lift_in_progress:
		return
	last_location = clampi(index, 0, LOCATIONS.size() - 1)
	player.teleport_to(LOCATIONS[last_location])

func try_lift() -> bool:
	if lift_in_progress or hud.menu_open:
		return false
	var ground_distance: float = player.global_position.distance_to(LIFT_GROUND)
	var upper_distance: float = player.global_position.distance_to(LIFT_UPPER)
	if ground_distance < 2.0 and _lift_line_clear(LIFT_GROUND):
		_perform_lift(LIFT_GROUND, LIFT_UPPER)
		return true
	if upper_distance < 2.0 and _lift_line_clear(LIFT_UPPER):
		_perform_lift(LIFT_UPPER, LIFT_GROUND)
		return true
	return false

func _lift_line_clear(source: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, source + Vector3.UP * 0.8, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _perform_lift(source: Vector3, destination: Vector3) -> void:
	lift_in_progress = true
	player.set_controls_locked(true)
	var approach: Vector3 = source + Vector3.UP * 0.012 - player.global_position
	player.scripted_move_speed = 2.2 if approach.length() > 0.1 else 0.0
	if approach.length() > 0.1:
		player.visual.rotation.y = atan2(-approach.x, -approach.z)
	var entry := create_tween()
	entry.tween_property(player, "global_position", source + Vector3.UP * 0.012, clampf(approach.length() / 2.2, 0.15, 0.9))
	await entry.finished
	player.scripted_move_speed = 0.0
	hud.travel_label.text = "Elevator · " + ("Second Floor" if destination.y > source.y else "Ground Floor")
	hud.travel_overlay.show()
	var fade_in := create_tween()
	fade_in.tween_method(hud.set_travel_opacity, 0.0, 1.0, 0.25)
	await fade_in.finished
	player.teleport_to(destination, -PI / 2.0)
	await get_tree().create_timer(0.35).timeout
	var fade_out := create_tween()
	fade_out.tween_method(hud.set_travel_opacity, 1.0, 0.0, 0.3)
	await fade_out.finished
	hud.travel_overlay.hide()
	player.scripted_move_speed = 2.2
	player.visual.rotation.y = -PI / 2.0
	var exit := create_tween()
	exit.tween_property(player, "global_position", destination + Vector3(1.5, 0.012, 0), 0.65)
	await exit.finished
	player.scripted_move_speed = 0.0
	lift_in_progress = false
	player.set_controls_locked(hud.menu_open)
	lift_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_test or hud.menu_open or lift_in_progress or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		go_location(event.keycode - KEY_1)
	elif event.keycode == KEY_E:
		try_lift()

func _physics_process(_delta: float) -> void:
	if not ready_for_test:
		return
	if player.global_position.y < -8.0:
		go_location(last_location)
	var near_lift: bool = player.global_position.distance_to(LIFT_GROUND) < 2.0 or player.global_position.distance_to(LIFT_UPPER) < 2.0
	hud.update_location(player.global_position.y > 3.0, near_lift)
	hud.update_debug(player.global_position)
