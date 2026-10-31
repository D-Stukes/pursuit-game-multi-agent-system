extends Node3D
## Places Mr. P in the classroom. He floats, faces the student and gestures via
## the shared MrPDisplay behaviour; here we just give him the player to watch and
## play his recorded welcome (voice + "Welcome" gesture) the first time the
## student stands in the room.
const WELCOME_PATH := "res://assets/audio/mrp/mrp_jeter_01_full.wav"
const PM_VOICE_PATH := "res://assets/audio/pm/pm_good_morning.wav"

var world: Node3D
var mrp: Node3D
var voice: AudioStreamPlayer
var pm_voice: AudioStreamPlayer   # the Program Manager's good-morning greeting
var greeted: bool = false
var vanished: bool = false
var program_manager: Node3D   # revealed as Mr. P fades out

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
	voice.finished.connect(_vanish)   # once the welcome ends, Mr. P leaves the classroom
	add_child(voice)
	pm_voice = AudioStreamPlayer.new()
	pm_voice.bus = "Effects"
	if ResourceLoader.exists(PM_VOICE_PATH):
		pm_voice.stream = load(PM_VOICE_PATH)
	add_child(pm_voice)

func _process(_delta: float) -> void:
	if greeted or world == null or world.player == null or world.classroom_sequence == null:
		return
	if world.classroom_sequence.in_classroom():
		greeted = true
		_face_player_at_mr_p()
		mrp.play_once("Welcome")
		if voice.stream != null:
			voice.play()
		else:
			get_tree().create_timer(3.0).timeout.connect(_vanish)

## Mr. P drifts up and fades out of the classroom after greeting the student;
## he resumes hosting in his own question room.
func _vanish() -> void:
	if vanished or mrp == null:
		return
	vanished = true
	mrp.set_process(false)   # stop the hover so our exit tween holds
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mrp, "position:y", mrp.position.y + 1.8, 1.1)
	tween.parallel().tween_property(mrp, "scale", Vector3(0.02, 0.02, 0.02), 1.1)
	tween.tween_callback(mrp.hide)
	tween.tween_callback(_reveal_manager)

## The Program Manager fades in where Mr. P was, taking over the front of the room.
func _reveal_manager() -> void:
	if program_manager == null:
		return
	_face_manager_at_class()
	program_manager.visible = true
	var fade := create_tween()
	fade.tween_property(program_manager, "modulate:a", 1.0, 0.8)
	# Her good-morning greeting plays once she has faded in.
	if pm_voice != null and pm_voice.stream != null:
		fade.tween_callback(pm_voice.play)

## Turn the standee to address the student (the class) instead of staring at the
## door. Her illustrated front (+Z local) is aimed at the player's greet spot.
func _face_manager_at_class() -> void:
	if world == null or world.player == null:
		return
	var to: Vector3 = world.player.global_position - program_manager.global_position
	var flat: float = Vector2(to.x, to.z).length()
	if flat < 0.05:
		return
	program_manager.rotation.y = atan2(to.x, to.z)

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
