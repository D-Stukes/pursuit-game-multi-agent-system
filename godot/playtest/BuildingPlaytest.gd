extends Node3D
## Local movement/camera proof. This does not modify the imported building.

signal lift_finished

const PlayerController = preload("res://playtest/BuildingPlayer.gd")
const PlaytestHUD = preload("res://playtest/PlaytestHUD.gd")
const ApprovedLayout = preload("res://playtest/ApprovedLayout.gd")
const EntrancePuzzle = preload("res://playtest/EntrancePuzzle.gd")
const BUILDING_PATH: String = "res://assets/generated/pursuit-building.glb"
var LOCATIONS: Array[Vector3] = []
const LOCATION_NAMES: Array[String] = ["Street entrance", "Second-floor reception", "Classroom"]
const LOCATION_HEADINGS: Array[float] = [0.0, PI, -PI / 2.0]
var LIFT_GROUND: Vector3
var LIFT_UPPER: Vector3
var UPPER_LIFT_EXIT: Vector3
var LOWER_LIFT_EXIT: Vector3
var LIFT_HEADING: float
const ACTIVE_FPS: int = 60
const BACKGROUND_FPS: int = 15
const LIFT_INTERACTION_RADIUS: float = 2.1

var player: CharacterBody3D
var mesh_count: int = 0
var collision_triangles: int = 0
var last_location: int = 0
var status_label: Label
var hud: Control
var ready_for_test: bool = false
var lift_in_progress: bool = false
var frame_budget_enabled: bool = false
var refresh_building_resources: bool = false
var approved_layout: RefCounted
var entrance_puzzle: Control
var entrance_gate: StaticBody3D
var ENTRANCE_POINT: Vector3
var building_review_mode: bool = false
var classroom_cast: Node3D
@export var include_classroom_cast: bool = true
var population: Node3D
@export var include_population: bool = true
var computer_portal: Node3D

func _ready() -> void:
	frame_budget_enabled = DisplayServer.get_name() != "headless"
	if frame_budget_enabled:
		_apply_frame_budget(get_window().has_focus())
	else:
		# Headless verification should not wait for the interactive frame cap.
		Engine.max_fps = 0
	_build_lighting()
	_build_hud()
	if not ResourceLoader.exists(BUILDING_PATH):
		status_label.text = "Building asset missing. Run python tools/prepare_playtest.py from the repo root, then import the Godot project."
		push_error(status_label.text)
		return
	# Only the review harness forces a refresh after an asset has been reimported.
	var cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_REPLACE_DEEP if refresh_building_resources else ResourceLoader.CACHE_MODE_REUSE
	var packed: PackedScene = ResourceLoader.load(BUILDING_PATH, "PackedScene", cache_mode)
	var building: Node3D = packed.instantiate()
	building.name = "Building"
	add_child(building)
	if refresh_building_resources:
		# Existing review windows can refresh the assembly without an OS relaunch.
		var layout_script: GDScript = load("res://playtest/ApprovedLayout.gd")
		layout_script.source_code = FileAccess.get_file_as_string("res://playtest/ApprovedLayout.gd")
		assert(layout_script.reload(true) == OK)
	approved_layout = ApprovedLayout.new()
	approved_layout.apply(building)
	for id: String in ["street_spawn", "reception_spawn", "classroom_spawn"]:
		LOCATIONS.append(approved_layout.anchor(id))
	ENTRANCE_POINT = approved_layout.anchor("entrance")
	LIFT_GROUND = approved_layout.anchor("lift_ground")
	LIFT_UPPER = approved_layout.anchor("lift_upper")
	UPPER_LIFT_EXIT = approved_layout.anchor("lift_upper_exit")
	LOWER_LIFT_EXIT = approved_layout.anchor("lift_ground_exit")
	LIFT_HEADING = float(approved_layout.manifest.lift_heading_yaw)
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
	player = CharacterBody3D.new()
	player.set_script(PlayerController)
	add_child(player)
	player.reset_requested.connect(func():
		if computer_portal == null or not computer_portal.reset_in_room(): go_location(last_location))
	if include_classroom_cast:
		classroom_cast = preload("res://scenes/ClassroomCast.tscn").instantiate()
		add_child(classroom_cast)
	if include_population:
		population = preload("res://scenes/BuildingPopulation.tscn").instantiate()
		population.player = player
		add_child(population)
	_build_entrance()
	_build_street_limits()
	computer_portal = preload("res://scenes/ComputerPortal.tscn").instantiate()
	computer_portal.world = self
	add_child(computer_portal)
	set_building_review_mode(OS.get_cmdline_user_args().has("--building-review"))
	go_location(0)
	ready_for_test = true
	print("BUILDING_READY meshes=", mesh_count, " triangles=", collision_triangles)

func _notification(what: int) -> void:
	if not frame_budget_enabled:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply_frame_budget(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_apply_frame_budget(false)

func _apply_frame_budget(focused: bool) -> void:
	Engine.max_fps = ACTIVE_FPS if focused else BACKGROUND_FPS

func _collect_faces(node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		mesh_count += 1
		var vertices: PackedVector3Array = node.mesh.get_faces()
		var to_world: Transform3D = node.global_transform
		for vertex: Vector3 in vertices:
			faces.append(to_world * vertex)
	for child: Node in node.get_children():
		_collect_faces(child, faces)

func _build_lighting() -> void:
	preload("res://playtest/EnvironmentLighting.gd").setup(self)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = PlaytestHUD.new()
	layer.add_child(hud)
	status_label = hud.floor_label
	hud.menu_requested.connect(set_menu_open)
	hud.location_requested.connect(func(index: int): go_location(index); set_menu_open(false))
	hud.review_mode_requested.connect(set_building_review_mode)

func set_menu_open(open: bool) -> void:
	if not ready_for_test or (computer_portal != null and computer_portal.transitioning):
		return
	if open and entrance_puzzle.visible:
		entrance_puzzle.hide()
	hud.set_menu_open(open)
	player.set_controls_locked(open or lift_in_progress or entrance_puzzle.visible)

func _build_entrance() -> void:
	entrance_puzzle = EntrancePuzzle.new()
	entrance_puzzle.theme_source = hud
	hud.add_child(entrance_puzzle)
	entrance_puzzle.closed.connect(func(): player.set_controls_locked(hud.menu_open or lift_in_progress))
	entrance_gate = StaticBody3D.new()
	entrance_gate.name = "EntranceLock"
	entrance_gate.collision_layer = 4
	entrance_gate.collision_mask = 0
	entrance_gate.position = ENTRANCE_POINT + Vector3.UP * 1.34
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.63, 2.68, 0.12)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	entrance_gate.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(PlaytestHUD.NAVY, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	entrance_gate.add_child(mesh)
	var sign := Label3D.new()
	sign.text = "ENTRY LOCKED\nE · Entrance puzzle"
	sign.font_size = 48
	sign.pixel_size = 0.003
	sign.double_sided = false
	sign.modulate = PlaytestHUD.CYAN
	sign.position = Vector3(0, 0.2, 0.10)
	entrance_gate.add_child(sign)
	add_child(entrance_gate)
	entrance_puzzle.entrance_unlocked.connect(_refresh_entrance_gate)

func _refresh_entrance_gate() -> void:
	var open: bool = building_review_mode or entrance_puzzle.state.unlocked
	entrance_gate.collision_layer = 0 if open else 4
	entrance_gate.visible = not open

func _build_street_limits() -> void:
	# These gameplay colliders share the manifest with the visible GLB barricades.
	# They stop step-over/edge bypass without affecting the second-floor interior.
	var limits: Dictionary = approved_layout.manifest.street_review_limits
	for x: float in [float(limits.min_x),float(limits.max_x)]:
		var body := StaticBody3D.new()
		body.name = "StreetReviewBoundaryWest" if x == float(limits.min_x) else "StreetReviewBoundaryEast"
		body.collision_layer = 4
		body.collision_mask = 0
		body.position = Vector3(x,(float(limits.floor)+float(limits.top))*.5,-(float(limits.min_depth)+float(limits.max_depth))*.5)
		var shape := BoxShape3D.new()
		shape.size = Vector3(.16,float(limits.top)-float(limits.floor),float(limits.max_depth)-float(limits.min_depth))
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func set_building_review_mode(enabled: bool) -> void:
	if lift_in_progress or (computer_portal != null and computer_portal.transitioning):
		hud.set_review_mode(building_review_mode)
		return
	building_review_mode = enabled and OS.is_debug_build()
	if building_review_mode and entrance_puzzle.visible:
		entrance_puzzle.close()
	_refresh_entrance_gate()
	hud.set_review_mode(building_review_mode)

func try_entrance() -> bool:
	if lift_in_progress or hud.menu_open or entrance_puzzle.visible:
		return false
	if building_review_mode or player.global_position.distance_to(ENTRANCE_POINT) > 2.4 or entrance_puzzle.state.unlocked:
		return false
	player.set_controls_locked(true)
	entrance_puzzle.open()
	return true

func _input(event: InputEvent) -> void:
	if computer_portal != null and computer_portal.transitioning:
		if event is InputEventKey: get_viewport().set_input_as_handled()
		return
	if ready_for_test and entrance_puzzle.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		entrance_puzzle.close()
		get_viewport().set_input_as_handled()
		return
	if ready_for_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3 and OS.is_debug_build():
		var close_debug: bool = hud.menu_open and hud.debug_mode
		hud.set_debug_mode(not close_debug)
		set_menu_open(not close_debug)
		get_viewport().set_input_as_handled()
	if ready_for_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_menu_open(not hud.menu_open)
		get_viewport().set_input_as_handled()

func go_location(index: int) -> void:
	if lift_in_progress or (computer_portal != null and computer_portal.transitioning):
		return
	if computer_portal != null: computer_portal.leave_for_developer_travel()
	last_location = clampi(index, 0, LOCATIONS.size() - 1)
	player.teleport_to(LOCATIONS[last_location], LOCATION_HEADINGS[last_location])

func try_lift() -> bool:
	if lift_in_progress or hud.menu_open or entrance_puzzle.visible or (computer_portal != null and (computer_portal.inside or computer_portal.transitioning)):
		return false
	var ground_distance: float = player.global_position.distance_to(LIFT_GROUND)
	var upper_distance: float = player.global_position.distance_to(LIFT_UPPER)
	if ground_distance < LIFT_INTERACTION_RADIUS and _lift_line_clear(LIFT_GROUND):
		_perform_lift(LIFT_GROUND, LIFT_UPPER)
		return true
	if upper_distance < LIFT_INTERACTION_RADIUS and _lift_line_clear(LIFT_UPPER):
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
	player.teleport_to(destination, LIFT_HEADING)
	await get_tree().create_timer(0.35).timeout
	var fade_out := create_tween()
	fade_out.tween_method(hud.set_travel_opacity, 1.0, 0.0, 0.3)
	await fade_out.finished
	hud.travel_overlay.hide()
	player.scripted_move_speed = 2.2
	player.visual.rotation.y = LIFT_HEADING
	# Stop just outside the upper jamb; the player chooses the onward walk.
	var exit_offset: Vector3 = (UPPER_LIFT_EXIT if destination.y > source.y else LOWER_LIFT_EXIT)-destination
	var exit := create_tween()
	exit.tween_property(player, "global_position", destination + exit_offset, exit_offset.length() / 2.2)
	await exit.finished
	player.scripted_move_speed = 0.0
	lift_in_progress = false
	player.set_controls_locked(hud.menu_open)
	lift_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_test or hud.menu_open or lift_in_progress or entrance_puzzle.visible or (computer_portal != null and computer_portal.transitioning) or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		# Explicit developer-menu travel still works; normal shortcuts cannot skip the lock.
		if building_review_mode or entrance_puzzle.state.unlocked:
			go_location(event.keycode - KEY_1)
	elif event.keycode == KEY_E:
		if computer_portal.try_use():
			get_viewport().set_input_as_handled()
			return
		if not try_entrance():
			try_lift()

func _physics_process(delta: float) -> void:
	if not ready_for_test:
		return
	if player.global_position.y < -8.0:
		if not computer_portal.reset_in_room(): go_location(last_location)
	var near_lift: bool = player.global_position.distance_to(LIFT_GROUND) < LIFT_INTERACTION_RADIUS or player.global_position.distance_to(LIFT_UPPER) < LIFT_INTERACTION_RADIUS
	hud.update_location(player.global_position.y > 3.0, near_lift)
	computer_portal.update_prompts(delta)
	if computer_portal.inside: hud.floor_label.text = "Purple Room"
	var computer_prompt: String = computer_portal.context_prompt()
	if not computer_prompt.is_empty(): hud.prompt_label.text = computer_prompt
	if not building_review_mode and not hud.menu_open and not entrance_puzzle.visible and not entrance_puzzle.state.unlocked and player.global_position.distance_to(ENTRANCE_POINT) < 2.4:
		hud.prompt_label.text = "E: solve entrance puzzle"
	if entrance_puzzle.visible:
		hud.prompt_label.text = ""
	hud.update_debug(player.global_position)
