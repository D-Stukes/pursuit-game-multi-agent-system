extends CharacterBody3D
## Third-person controller. Feet are at the node origin; geometry is independent.

signal reset_requested

const HEIGHT: float = 1.72
const RADIUS: float = 0.24
const SPEED: float = 2.8
const MIN_PITCH: float = -0.96
const MAX_PITCH: float = 0.38
const MIN_ZOOM: float = 1.1
const MAX_ZOOM: float = 5.5
const SENSITIVITY: float = 0.0022

var controls_active: bool = false
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visual: Node3D
var animation_player: AnimationPlayer
var current_animation: StringName = &""

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.26
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.012
	_register_controls()
	var capsule := CapsuleShape3D.new()
	capsule.height = HEIGHT
	capsule.radius = RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = HEIGHT / 2.0
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var mesh := MeshInstance3D.new()
	var placeholder := CapsuleMesh.new()
	placeholder.height = HEIGHT
	placeholder.radius = RADIUS
	mesh.mesh = placeholder
	mesh.position.y = HEIGHT / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.21, 0.88, 1.0)
	mesh.material_override = material
	visual.add_child(mesh)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position.y = 1.4
	camera_pivot.rotation.x = -0.20
	add_child(camera_pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 3.0
	spring_arm.margin = 0.10
	spring_arm.collision_mask = 1
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.18
	spring_arm.shape = camera_shape
	camera_pivot.add_child(spring_arm)
	spring_arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 65.0
	camera.near = 0.05
	camera.far = 180.0
	spring_arm.add_child(camera)
	camera.current = true
	set_controls_active(DisplayServer.get_name() != "headless")

func _register_controls() -> void:
	var keys := {"walk_forward": [KEY_W, KEY_UP], "walk_back": [KEY_S, KEY_DOWN],
		"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT]}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func set_controls_active(active: bool) -> void:
	controls_active = active
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE

func apply_look(motion: Vector2) -> void:
	camera_pivot.rotation.y -= motion.x * SENSITIVITY
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - motion.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)

func change_zoom(amount: float) -> void:
	spring_arm.spring_length = clampf(spring_arm.spring_length + amount, MIN_ZOOM, MAX_ZOOM)

func teleport_to(feet: Vector3, heading: float = 0.0) -> void:
	global_position = feet + Vector3.UP * 0.08
	velocity = Vector3.ZERO
	camera_pivot.rotation = Vector3(-0.20, heading, 0.0)
	visual.rotation.y = heading
	reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			set_controls_active(not controls_active)
		elif event.keycode == KEY_R:
			reset_requested.emit()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not controls_active:
			set_controls_active(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_zoom(-0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(0.25)
	if event is InputEventMouseMotion and controls_active:
		apply_look(event.screen_relative)

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_active:
		input = Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
	var desired := camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)
	desired.y = 0.0
	if desired.length_squared() > 0.001:
		desired = desired.normalized() * minf(input.length(), 1.0)
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-desired.x, -desired.z), 12.0 * delta)
	velocity.x = move_toward(velocity.x, desired.x * SPEED, 18.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z * SPEED, 18.0 * delta)
	velocity.y = -0.1 if is_on_floor() else velocity.y - 14.0 * delta
	move_and_slide()
