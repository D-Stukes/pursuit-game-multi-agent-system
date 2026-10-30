extends Node3D
## Reusable rigged art actor for Mr. P. Question content and AI remain separate.
## Ghost behaviour: he hovers (bob + sway), turns to face the player, and plays
## his baked gesture clips (Idle / Guide / Welcome). Facing is measured from the
## arm bones so it is correct for any model orientation.

# Set by the room/greeter to the node Mr. P should watch (usually the player).
var look_target: Node3D
@export var hover_lift: float = 0.0   ## extra height so he floats off the ground
@export var bob_amp: float = 0.06     ## vertical hover amount
@export var bob_speed: float = 1.5
@export var turn_speed: float = 2.5   ## radians/sec he rotates to face the player
@export var engage_range: float = 6.0 ## within this, he gestures ("Guide") at you

var skeleton: Skeleton3D
var animation: AnimationPlayer
var _base_y: float
var _t: float = 0.0
var _arm_l: int = -1
var _arm_r: int = -1
var _head: int = -1
var _one_shot: bool = false   ## true while a one-off clip (Welcome) is playing

func _ready() -> void:
	skeleton = $Model.find_children("*", "Skeleton3D", true, false)[0]
	animation = $Model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip: String in ["Idle", "Guide"]:
		if animation.has_animation(clip):
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play("Idle")
	animation.animation_finished.connect(_on_clip_finished)
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 35.0
		mesh.visibility_range_end_margin = 3.0
	_arm_l = skeleton.find_bone("upper_arm_L")
	_arm_r = skeleton.find_bone("upper_arm_R")
	_head = skeleton.find_bone("head")
	_base_y = position.y   # original placed height; hover is added each frame

## World position of Mr. P's head, so the camera can look him in the eye.
func look_point() -> Vector3:
	if skeleton != null and _head >= 0:
		return (skeleton.global_transform * skeleton.get_bone_global_pose(_head)).origin
	return global_position + Vector3.UP * 2.0

## Play a one-off clip (e.g. "Welcome"); returns to the ambient clip when done.
func play_once(clip: String) -> void:
	if animation != null and animation.has_animation(clip):
		_one_shot = true
		animation.play(clip)

func _on_clip_finished(_name: StringName) -> void:
	_one_shot = false

func _process(delta: float) -> void:
	_t += delta
	# Ghostly hover (lift + gentle bob).
	position.y = _base_y + hover_lift + sin(_t * bob_speed) * bob_amp
	if look_target == null:
		return
	var to: Vector3 = look_target.global_position - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	# Turn to face the player, using the arm line to find his true forward axis.
	if _arm_l >= 0 and _arm_r >= 0:
		var lp: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_rest(_arm_l)).origin
		var rp: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_rest(_arm_r)).origin
		var right: Vector3 = rp - lp
		right.y = 0.0
		if right.length() > 0.001:
			var forward: Vector3 = right.normalized().rotated(Vector3.UP, PI / 2.0)
			var desired: Vector3 = to.normalized()
			var angle: float = atan2(forward.cross(desired).y, forward.dot(desired))
			rotation.y += clampf(angle, -turn_speed * delta, turn_speed * delta)
	# Gesture when the player is close and engaging; rest to Idle otherwise.
	if not _one_shot:
		var engaged: bool = to.length() <= engage_range and animation.has_animation("Guide")
		var want: String = "Guide" if engaged else "Idle"
		if animation.current_animation != want:
			animation.play(want, 0.3)
