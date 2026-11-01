extends Node3D
## Places Mr. P in the classroom. He floats, faces the student and gestures via
## the shared MrPDisplay behaviour; here we just give him the player to watch and
## play his recorded welcome (voice + "Welcome" gesture) the first time the
## student stands in the room.
const WELCOME_PATH := "res://assets/audio/mrp/mrp_jeter_01_full.wav"
# The Program Manager's real voice (LaNice), greeting 1 — her good-morning line.
const PM_VOICE_PATH := "res://assets/audio/pm/pm_lanice_greeting1.wav"
const PM_GREETING := "Good morning everyone! I need you to do your Daily Standup and then get to work in your Platform. I will be checking your progress, so let's go!"

var world: Node3D
var mrp: Node3D
var voice: AudioStreamPlayer
var pm_voice: AudioStreamPlayer   # the Program Manager's good-morning greeting
var greeted: bool = false
var vanished: bool = false
var program_manager: Node3D   # revealed as Mr. P fades out
var greeting_started_msec: int = -1
var pm_caption: PanelContainer   # on-screen text for the Program Manager's greeting
var pm_line: Label
## Slack on top of the two recordings, in case the audio never reports that it finished.
const GREETING_MARGIN_SECONDS: float = 6.0

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
	_build_pm_caption()

## A lower-left caption that shows the Program Manager's greeting as on-screen
## text while her recording plays.
func _build_pm_caption() -> void:
	if world == null or world.hud == null:
		return
	pm_caption = PanelContainer.new()
	pm_caption.add_theme_stylebox_override("panel", world.hud._panel_style())
	pm_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", world.hud.GAP)
	pm_caption.add_child(column)
	column.add_child(world.hud._label("Program Manager", 18))
	pm_line = world.hud._label(PM_GREETING, 20)
	pm_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pm_line.custom_minimum_size.x = 540
	column.add_child(pm_line)
	world.hud.add_child(pm_caption)
	pm_caption.hide()
	pm_voice.finished.connect(_hide_pm_caption)

func _show_pm_caption() -> void:
	if pm_caption == null:
		return
	pm_line.text = PM_GREETING
	pm_caption.reset_size()
	pm_caption.position = Vector2(16, world.hud.size.y - pm_caption.size.y - 62)
	pm_caption.show()

func _hide_pm_caption() -> void:
	if pm_caption != null:
		pm_caption.hide()

func _process(_delta: float) -> void:
	if greeted or world == null or world.player == null or world.classroom_sequence == null:
		return
	if world.classroom_sequence.in_classroom():
		greeted = true
		greeting_started_msec = Time.get_ticks_msec()
		_face_player_at_mr_p()
		mrp.play_once("Welcome")
		if voice.stream != null:
			voice.play()
		else:
			get_tree().create_timer(3.0).timeout.connect(_vanish)

## True from Mr. P's welcome until the Program Manager has faded in and finished her greeting.
## The game keeps the classroom computers locked meanwhile.
func speaking() -> bool:
	if not greeted or (Time.get_ticks_msec()-greeting_started_msec)/1000.0 > talk_limit(): return false
	if voice.playing or not vanished or pm_voice.playing: return true
	return program_manager != null and program_manager.visible and program_manager.modulate.a < .99

## Longest the welcome plus the Program Manager's greeting can take: both recordings, the hand-off
## fades and a margin.
func talk_limit() -> float:
	var welcome: float = voice.stream.get_length() if voice != null and voice.stream != null else 3.0
	var good_morning: float = pm_voice.stream.get_length() if pm_voice != null and pm_voice.stream != null else 0.0
	return welcome+good_morning+GREETING_MARGIN_SECONDS

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
	_show_pm_caption()
	var fade := create_tween()
	fade.tween_property(program_manager, "modulate:a", 1.0, 0.8)
	# Her good-morning greeting plays once she has faded in.
	if pm_voice != null and pm_voice.stream != null:
		fade.tween_callback(pm_voice.play)
	else:
		get_tree().create_timer(5.0).timeout.connect(_hide_pm_caption)

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
