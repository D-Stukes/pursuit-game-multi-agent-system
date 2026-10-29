extends CharacterBody3D
## Third-person controller. Feet are at the node origin; geometry is independent.

signal reset_requested

const HEIGHT: float = 1.72
const RADIUS: float = 0.24
const SPEED: float = 2.8
const RUN_SPEED: float = 5.2
const MAX_STEP_HEIGHT: float = 0.24
const MIN_PITCH: float = -0.96
const MAX_PITCH: float = 0.38
const MIN_ZOOM: float = 1.1
const MAX_ZOOM: float = 5.5
const SENSITIVITY: float = 0.0022

var controls_active: bool = false
var controls_locked: bool = false
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visual: Node3D
var animation_player: AnimationPlayer
var current_animation: StringName = &""
var avatar_loaded: bool = false
var avatar_height: float = 0.0
var scripted_move_speed: float = 0.0
var camera_step_offset: float = 0.0
# Sit-at-desk state machine: "" (standing) -> entering -> sitting -> exiting -> "".
var sit_state: StringName = &""

func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1 | 4 | 8 # World, pedestrian boundaries and ambient NPC capsules.
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
	_load_character(mesh)
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
	set_controls_active(DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("--script"))

func _load_character(placeholder: MeshInstance3D) -> void:
	const CHARACTER_PATH: String = "res://assets/characters/quaternius-casual/Casual_Hoodie.glb"
	if not ResourceLoader.exists(CHARACTER_PATH):
		return
	var packed: PackedScene = load(CHARACTER_PATH)
	var character: Node3D = packed.instantiate()
	character.name = "QuaterniusCharacter"
	visual.add_child(character)
	var bounds := AABB()
	var found: bool = false
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = character.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = relative * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found or bounds.size.y < 0.01:
		character.queue_free()
		return
	var factor: float = HEIGHT / bounds.size.y
	character.scale = Vector3.ONE * factor
	character.position.y = -bounds.position.y * factor
	# Quaternius's source faces +Z; the controller's forward direction is -Z.
	character.rotation.y = PI
	avatar_height = bounds.size.y * factor
	animation_player = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		# Keep the source clips intact; expose stable names used by the controller.
		var library: AnimationLibrary = animation_player.get_animation_library("")
		# Godot's glTF importer strips the "_Loop" suffix (and loops the clip),
		# so the seated holds import as Sitting_Idle / Sitting_Talking.
		var looping := {"idle": "Idle_Neutral", "walk": "Walk", "run": "Run",
			"sit_idle": "Sitting_Idle", "sit_talk": "Sitting_Talking"}
		for alias: String in looping:
			if animation_player.has_animation(looping[alias]):
				var clip: Animation = animation_player.get_animation(looping[alias]).duplicate()
				clip.loop_mode = Animation.LOOP_LINEAR
				library.add_animation(alias, clip)
		# One-shot sit transitions must NOT loop, so animation_finished fires.
		var oneshot := {"sit_enter": "Sitting_Enter", "sit_exit": "Sitting_Exit"}
		for alias: String in oneshot:
			if animation_player.has_animation(oneshot[alias]):
				var clip: Animation = animation_player.get_animation(oneshot[alias]).duplicate()
				clip.loop_mode = Animation.LOOP_NONE
				library.add_animation(alias, clip)
		animation_player.animation_finished.connect(_on_sit_animation_finished)
	avatar_loaded = true
	placeholder.queue_free()
	_update_animation(0.0)

func _update_animation(speed: float) -> void:
	if not animation_player:
		return
	var requested: StringName = &"walk" if speed > 0.1 else &"idle"
	if speed > SPEED + 0.4:
		requested = &"run"
	if requested != current_animation and animation_player.has_animation(requested):
		animation_player.play(requested, 0.15)
		current_animation = requested
	animation_player.speed_scale = clampf(speed / 1.8, 0.7, 1.6) if requested == &"walk" else 1.0
	if requested == &"run":
		animation_player.speed_scale = clampf(speed / 4.2, 0.8, 1.5)

## Toggle sitting. Ignored while a transition is mid-flight or controls are locked.
func toggle_sit() -> void:
	if controls_locked or not avatar_loaded or animation_player == null:
		return
	if not animation_player.has_animation(&"sit_enter"):
		return
	if sit_state == &"entering" or sit_state == &"exiting":
		return
	if sit_state == &"sitting":
		_begin_sit_clip(&"sit_exit")
		sit_state = &"exiting"
	elif sit_state == &"":
		if not is_on_floor():
			return
		velocity = Vector3.ZERO
		_begin_sit_clip(&"sit_enter")
		sit_state = &"entering"

func _begin_sit_clip(clip: StringName) -> void:
	animation_player.speed_scale = 1.0
	animation_player.play(clip, 0.2)
	current_animation = clip

func _on_sit_animation_finished(anim: StringName) -> void:
	if anim == &"sit_enter" and sit_state == &"entering":
		sit_state = &"sitting"
		animation_player.play(&"sit_idle", 0.25)
		current_animation = &"sit_idle"
	elif anim == &"sit_exit" and sit_state == &"exiting":
		sit_state = &""
		current_animation = &""
		_update_animation(0.0)

func _register_controls() -> void:
	var keys := {"walk_forward": [KEY_W, KEY_UP], "walk_back": [KEY_S, KEY_DOWN],
		"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT], "run": [KEY_SHIFT],
		"sit": [KEY_C]}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func set_controls_active(active: bool) -> void:
	controls_active = active and not controls_locked
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if controls_active else Input.MOUSE_MODE_VISIBLE

func set_controls_locked(locked: bool) -> void:
	controls_locked = locked
	set_controls_active(not locked)
	if locked:
		velocity = Vector3.ZERO
		_clear_sit()

## Drop any seated state and fall back to the normal standing animation.
func _clear_sit() -> void:
	if sit_state == &"":
		return
	sit_state = &""
	current_animation = &""
	if animation_player:
		animation_player.speed_scale = 1.0
		_update_animation(0.0)

func apply_look(motion: Vector2) -> void:
	camera_pivot.rotation.y -= motion.x * SENSITIVITY
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - motion.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)

func change_zoom(amount: float) -> void:
	spring_arm.spring_length = clampf(spring_arm.spring_length + amount, MIN_ZOOM, MAX_ZOOM)

func teleport_to(feet: Vector3, heading: float = 0.0) -> void:
	_clear_sit()
	global_position = feet + Vector3.UP * 0.08
	velocity = Vector3.ZERO
	camera_pivot.rotation = Vector3(-0.20, heading, 0.0)
	camera_step_offset = 0.0
	camera_pivot.position.y = 1.4
	visual.rotation.y = heading
	reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_requested.emit()
		elif event.keycode == KEY_C:
			toggle_sit()
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
	if controls_locked:
		_update_animation(scripted_move_speed)
		visual.visible = spring_arm.get_hit_length() > 0.85
		return
	if sit_state != &"":
		# Seated: stay put and grounded; the sit clip drives the pose. Camera
		# look still works, and pressing C again stands the player back up.
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.1 if is_on_floor() else velocity.y - 14.0 * delta
		move_and_slide()
		visual.visible = spring_arm.get_hit_length() > 0.85
		return
	var previous_position: Vector3 = global_position
	var input := Vector2.ZERO
	if controls_active:
		input = Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
	var desired := camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)
	desired.y = 0.0
	if desired.length_squared() > 0.001:
		desired = desired.normalized() * minf(input.length(), 1.0)
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-desired.x, -desired.z), 12.0 * delta)
	var target_speed: float = RUN_SPEED if controls_active and Input.is_action_pressed("run") else SPEED
	velocity.x = move_toward(velocity.x, desired.x * target_speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z * target_speed, 18.0 * delta)
	velocity.y = -0.1 if is_on_floor() else velocity.y - 14.0 * delta
	var horizontal_motion := Vector3(velocity.x, 0, velocity.z) * delta
	if _try_step_up(horizontal_motion):
		var horizontal_velocity := Vector2(velocity.x, velocity.z)
		var snap: float = floor_snap_length
		floor_snap_length = 0.0
		velocity = Vector3(0, -0.1, 0)
		move_and_slide()
		floor_snap_length = snap
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.y
	else:
		move_and_slide()
	var moved: Vector3 = global_position - previous_position
	_update_animation(Vector2(moved.x, moved.z).length() / maxf(delta, 0.001))
	camera_step_offset = move_toward(camera_step_offset, 0.0, delta * 2.5)
	camera_pivot.position.y = 1.4 + camera_step_offset
	# When a wall compresses the camera into the head, keep the view readable.
	visual.visible = spring_arm.get_hit_length() > 0.85

	GameAudio.walk(delta,Vector2(global_position.x-previous_position.x,global_position.z-previous_position.z).length(),is_on_floor())

func _try_step_up(motion: Vector3) -> bool:
	var grounded: bool = is_on_floor()
	if not grounded and velocity.y <= 0.0:
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.05, global_position - Vector3.UP * 0.07, 1)
		var floor_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		grounded = not floor_hit.is_empty() and floor_hit["normal"].y >= cos(floor_max_angle)
	if not grounded or motion.length_squared() < 0.00000001:
		return false
	var contact_probe: Vector3 = motion.normalized() * maxf(motion.length(), 0.06)
	if not test_move(global_transform, contact_probe, null, safe_margin):
		return false
	var up_parameters := PhysicsTestMotionParameters3D.new()
	up_parameters.from = global_transform
	up_parameters.motion = Vector3.UP * MAX_STEP_HEIGHT
	up_parameters.max_collisions = 4
	var up_result := PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(get_rid(), up_parameters, up_result):
		for collision_index in range(up_result.get_collision_count()):
			if up_result.get_collision_normal(collision_index).y < -0.1:
				return false
	var raised: Transform3D = global_transform
	raised.origin.y += MAX_STEP_HEIGHT
	var lookahead: Vector3 = motion.normalized() * maxf(motion.length(), RADIUS + 0.06)
	if test_move(raised, lookahead, null, safe_margin):
		return false
	raised.origin += lookahead
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = raised
	parameters.motion = Vector3.DOWN * (MAX_STEP_HEIGHT + 0.05)
	parameters.margin = safe_margin
	var result := PhysicsTestMotionResult3D.new()
	if not PhysicsServer3D.body_test_motion(get_rid(), parameters, result):
		return false
	var rise: float = MAX_STEP_HEIGHT + result.get_travel().y
	if rise < 0.025 or rise > MAX_STEP_HEIGHT or result.get_collision_normal().y < cos(floor_max_angle):
		return false
	# Probe past the rounded foot onto a tread, but retain this frame's actual
	# horizontal distance so step detection cannot accelerate the player.
	global_position += motion + Vector3.UP * rise
	camera_step_offset -= rise
	return true
