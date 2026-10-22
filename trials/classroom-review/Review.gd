extends Node3D
## Isolated asset review. This does not replace the game's main scene.

const MODEL_PATH := "res://assets/classroom.glb"
const SPAWN := Vector3(0, 0.96, 6.8)
const SPEED := 3.0
const LOOK_SPEED := 0.002

var walker: CharacterBody3D
var camera: Camera3D
var status_label: Label
var verify_mode := false
var snapshot_mode := false
var mesh_count := 0
var triangle_count := 0
var bounds := AABB()
var has_bounds := false
var frame := 0
var settled_position := Vector3.ZERO
var floor_confirmed := false
var checks_finished := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	verify_mode = "--verify" in args
	snapshot_mode = "--snapshot" in args
	if not FileAccess.file_exists(MODEL_PATH) or not ResourceLoader.exists(MODEL_PATH):
		push_error("Missing assets/classroom.glb. Copy the trial GLB as described in README.md.")
		get_tree().quit(2)
		return
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("The asset did not import as a 3D scene.")
		get_tree().quit(2)
		return
	var model := packed.instantiate()
	add_child(model)
	_collect_meshes(model)
	_add_lighting()
	_add_walker()
	_add_overlay()
	if not verify_mode and not snapshot_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if snapshot_mode:
		_save_snapshot()


func _collect_meshes(node: Node) -> void:
	# Iterate the original children: collision helpers add their own children.
	var children := node.get_children()
	if node is MeshInstance3D and node.mesh != null:
		mesh_count += 1
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			if indices != null and indices.size() > 0:
				triangle_count += indices.size() / 3
			elif vertices != null:
				triangle_count += vertices.size() / 3
		var world_box: AABB = node.global_transform * node.get_aabb()
		bounds = bounds.merge(world_box) if has_bounds else world_box
		has_bounds = true
		# Full mesh collision is for this static inspection fixture only.
		# Shipping levels should use simplified authored collision shapes.
		node.create_trimesh_collision()
	for child in children:
		_collect_meshes(child)


func _add_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.92, 1.0)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	for z in [-5.0, 0.0, 5.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 3.25, z)
		lamp.light_color = Color(1.0, 0.92, 0.8)
		lamp.light_energy = 1.1
		lamp.omni_range = 10.0
		add_child(lamp)


func _add_walker() -> void:
	walker = CharacterBody3D.new()
	walker.name = "ReviewWalker"
	add_child(walker)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	collider.shape = capsule
	walker.add_child(collider)
	walker.position = SPAWN
	camera = Camera3D.new()
	camera.position.y = 0.72
	camera.fov = 72
	camera.current = true
	walker.add_child(camera)


func _add_overlay() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	status_label = Label.new()
	status_label.position = Vector2(20, 16)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_outline_size", 4)
	status_label.text = "BLENDER CLASSROOM TRIAL | estimated dimensions\nWASD: walk · mouse: look · Esc: cursor · R: reset\n%d meshes · %d triangles | temporary mesh collisions" % [mesh_count, triangle_count]
	ui.add_child(status_label)


func _unhandled_input(event: InputEvent) -> void:
	if verify_mode or snapshot_mode:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_R:
			walker.position = SPAWN
			walker.velocity = Vector3.ZERO
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.rotate_y(-event.relative.x * LOOK_SPEED)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK_SPEED, -1.3, 1.3)


func _physics_process(delta: float) -> void:
	if walker == null or checks_finished:
		return
	frame += 1
	walker.velocity.y -= 9.8 * delta
	var direction := Vector3.ZERO
	if verify_mode:
		if frame == 60:
			floor_confirmed = walker.is_on_floor()
			settled_position = walker.position
		if frame > 60 and frame <= 180:
			direction = Vector3.FORWARD
		if frame == 181:
			_finish_checks()
			return
	elif not snapshot_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var horizontal := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		var forward := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		direction = walker.basis * Vector3(horizontal, 0, forward).normalized()
	walker.velocity.x = direction.x * SPEED
	walker.velocity.z = direction.z * SPEED
	walker.move_and_slide()
	if not verify_mode and walker.position.y < -3.0:
		walker.position = SPAWN
		walker.velocity = Vector3.ZERO


func _finish_checks() -> void:
	checks_finished = true
	var distance := settled_position.z - walker.position.z
	var wall_query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, 0), Vector3(6, 1.5, 0))
	wall_query.exclude = [walker.get_rid()]
	var wall := get_world_3d().direct_space_state.intersect_ray(wall_query)
	var passed := mesh_count > 0 and bounds.size.is_finite() and bounds.size.x > 8.0 and bounds.size.y > 3.0 and bounds.size.z > 15.0 and floor_confirmed and walker.is_on_floor() and distance > 5.0 and not wall.is_empty()
	var receipt := {
		"passed": passed,
		"meshes": mesh_count,
		"triangles": triangle_count,
		"bounds_size_m": [bounds.size.x, bounds.size.y, bounds.size.z],
		"spawn_settled_on_floor": floor_confirmed,
		"walk_distance_m": distance,
		"walk_ended_on_floor": walker.is_on_floor(),
		"side_wall_ray_hit": not wall.is_empty(),
		"limits": "Estimated dimensions; temporary mesh collisions; central aisle test only. No full-level gameplay, accessibility or performance clearance."
	}
	DirAccess.make_dir_recursive_absolute("res://evidence")
	var output := FileAccess.open("res://evidence/verification.json", FileAccess.WRITE)
	if output == null:
		push_error("Cannot save trial verification receipt.")
		get_tree().quit(3)
		return
	output.store_string(JSON.stringify(receipt, "\t"))
	output.close()
	print(JSON.stringify(receipt))
	get_tree().quit(0 if passed else 1)


func _save_snapshot() -> void:
	for ignored in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://evidence")
	var result := get_viewport().get_texture().get_image().save_png("res://evidence/Godot Classroom.png")
	get_tree().quit(0 if result == OK else 1)
