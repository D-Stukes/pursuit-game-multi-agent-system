extends Node3D
## Local movement/camera proof. This does not modify the imported building.

const PlayerController = preload("res://playtest/BuildingPlayer.gd")
const ExteriorBackdrop = preload("res://playtest/ExteriorBackdrop.gd")
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
var ready_for_test: bool = false

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
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.082, 0.22, 0.9)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.90, 0.92, 1.0))
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_label)

func go_location(index: int) -> void:
	last_location = clampi(index, 0, LOCATIONS.size() - 1)
	player.teleport_to(LOCATIONS[last_location])

func try_lift() -> bool:
	var ground_distance: float = player.global_position.distance_to(LIFT_GROUND)
	var upper_distance: float = player.global_position.distance_to(LIFT_UPPER)
	if ground_distance < 2.0:
		player.teleport_to(LIFT_UPPER)
		return true
	if upper_distance < 2.0:
		player.teleport_to(LIFT_GROUND)
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_test or not event is InputEventKey or not event.pressed or event.echo:
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
	var level: String = "Second floor" if player.global_position.y > 3.0 else "Ground floor"
	var lift_text: String = ""
	if player.global_position.distance_to(LIFT_GROUND) < 2.0 or player.global_position.distance_to(LIFT_UPPER) < 2.0:
		lift_text = "\nE: change elevator floor (playtest transition)"
	var guidance: String = "Turn right before the stair railing and use the ramp."
	if player.global_position.y > 3.0:
		guidance = "Reception: single door to separate room; double doors to classroom."
	status_label.text = "PURSUIT · BUILDING PLAYTEST — " + level + "\nWASD / arrows: walk · Mouse: look · Wheel: zoom · Esc: release · Click: resume\n1: entrance · 2: reception · 3: classroom · R: reset location\n" + guidance + lift_text
