extends Node3D
## Places Mr. P in the classroom. He floats, faces the student and gestures via
## the shared MrPDisplay behaviour; here we just give him the player to watch and
## play his recorded welcome (voice + "Welcome" gesture) the first time the
## student stands in the room.
const WELCOME_PATH := "res://assets/audio/mrp/mrp_jeter_01_full.wav"

var world: Node3D
var mrp: Node3D
var voice: AudioStreamPlayer
var greeted: bool = false

func _ready() -> void:
	mrp = preload("res://scenes/characters/MrP.tscn").instantiate()
	mrp.hover_lift = 0.12   # a slight ghostly hover, not a balloon to the ceiling
	add_child(mrp)
	if world != null:
		mrp.look_target = world.player
	voice = AudioStreamPlayer.new()
	voice.bus = "Effects"
	if ResourceLoader.exists(WELCOME_PATH):
		voice.stream = load(WELCOME_PATH)
	add_child(voice)

func _process(_delta: float) -> void:
	if greeted or world == null or world.player == null or world.classroom_sequence == null:
		return
	if world.classroom_sequence.in_classroom():
		greeted = true
		_face_player_at_mr_p()
		mrp.play_once("Welcome")
		if voice.stream != null:
			voice.play()

## When Mr. P starts talking, turn the player's camera to look straight at him,
## no matter which way they were facing. Skipped while a scripted presentation
## camera (the program-manager stand-up) is the live view.
func _face_player_at_mr_p() -> void:
	var player: Node3D = world.player
	if player == null or player.camera == null or not player.camera.current:
		return
	var pivot: Node3D = player.camera_pivot
	var eye: Vector3 = player.global_position + Vector3.UP * pivot.position.y
	var to: Vector3 = mrp.look_point() - eye
	var flat: float = Vector2(to.x, to.z).length()
	if flat < 0.05:
		return
	var yaw: float = atan2(-to.x, -to.z)
	var pitch: float = clampf(atan2(to.y, flat), player.MIN_PITCH, player.MAX_PITCH)
	# Take the shortest way round so the camera never spins the long way.
	var target_yaw: float = pivot.rotation.y + angle_difference(pivot.rotation.y, yaw)
	var turn := create_tween()
	turn.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	turn.parallel().tween_property(pivot, "rotation:y", target_yaw, 0.5)
	turn.parallel().tween_property(pivot, "rotation:x", pitch, 0.5)
