extends CharacterBody3D
# First-person walker for the Level 1 blockout.

@export var speed := 4.5
@export var gravity := 14.0
@export var mouse_sens := 0.0022

var can_move := true
var pitch := 0.0

@onready var cam: Camera3D = $Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		pitch = clamp(pitch - event.relative.y * mouse_sens, -1.3, 1.3)
		cam.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if can_move and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var input := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): input.z -= 1.0
		if Input.is_key_pressed(KEY_S): input.z += 1.0
		if Input.is_key_pressed(KEY_A): input.x -= 1.0
		if Input.is_key_pressed(KEY_D): input.x += 1.0
		if input.length() > 0.0:
			input = input.normalized()
			dir = transform.basis * input
			dir.y = 0.0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
