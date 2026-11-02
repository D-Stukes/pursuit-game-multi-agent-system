extends Node3D
## Places Mr. P in the classroom. He floats, faces the student and gestures via
## the shared MrPDisplay behaviour; here we just give him the player to watch and
## play his recorded welcome (voice + "Welcome" gesture) the first time the
## student stands in the room.
const WELCOME_PATH := "res://assets/audio/mrp/mrp_jeter_01_full.wav"
# The Program Manager's real voice (LaNice), greeting 1 — her good-morning line.
const PM_VOICE_PATH := "res://assets/audio/pm/pm_lanice_greeting1.wav"
const PM_GREETING := "Good morning everyone! I need you to do your Daily Standup and then get to work in your Platform. I will be checking your progress, so let's go!"
# Greeting 2 — her come-back line, the first time the AI Builder returns from the
# Platform with questions still unanswered.
const PM_RETURN_PATH := "res://assets/audio/pm/pm_lanice_greeting2.wav"
const PM_RETURN := "Ok, how is everyone doing? If you need help, or have any blockers, please let me know!"
# Greeting 3 — her closing line, played at the start of the ending.
const PM_ENDING_PATH := "res://assets/audio/pm/pm_lanice_greeting3.wav"
const PM_ENDING := "Great job today! Let's keep building, and get ready to present next week!"
# Her lines play as voice only; set true to also show them in an on-screen box.
const SHOW_PM_CAPTION := false

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
var pm_return_voice: AudioStreamPlayer   # greeting 2, the come-back line
var pm_ending_voice: AudioStreamPlayer   # greeting 3, the closing line
var return_greeted: bool = false
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
	pm_return_voice = AudioStreamPlayer.new()
	pm_return_voice.bus = "Effects"
	if ResourceLoader.exists(PM_RETURN_PATH):
		pm_return_voice.stream = load(PM_RETURN_PATH)
	add_child(pm_return_voice)
	pm_ending_voice = AudioStreamPlayer.new()
	pm_ending_voice.bus = "Effects"
	if ResourceLoader.exists(PM_ENDING_PATH):
		pm_ending_voice.stream = load(PM_ENDING_PATH)
	add_child(pm_ending_voice)
	_build_pm_caption()

## The Program Manager's lines are voice-only (no on-screen caption box). We still
## connect her greeting-finished handler so she turns to face the class after it.
func _build_pm_caption() -> void:
	pm_voice.finished.connect(_on_greeting_done)
	if pm_return_voice != null:
		pm_return_voice.finished.connect(_hide_pm_caption)
	if pm_ending_voice != null:
		pm_ending_voice.finished.connect(_hide_pm_caption)
	if not SHOW_PM_CAPTION or world == null or world.hud == null:
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

func _show_pm_caption(text: String = PM_GREETING) -> void:
	if pm_caption == null:
		return
	pm_line.text = text
	pm_caption.reset_size()
	pm_caption.position = Vector2(16, world.hud.size.y - pm_caption.size.y - 62)
	pm_caption.show()

func _hide_pm_caption() -> void:
	if pm_caption != null:
		pm_caption.hide()

## When her greeting ends, hide the caption and move her up to the front desk,
## turned to face the class. NOTE: the target spot is a placeholder near the added
## podium; tell me the real white-desk location to place her exactly.
func _on_greeting_done() -> void:
	_hide_pm_caption()
	get_tree().create_timer(0.3).timeout.connect(_move_to_front)

func _move_to_front() -> void:
	if program_manager == null:
		return
	# Stand at the classroom's own Facilitator desk (front-right corner, ~x 2.9,
	# z -0.6), turned to face the class seating.
	var target: Vector3 = Vector3(2.5, program_manager.global_position.y, -0.6)
	var aim: Vector3 = Vector3(-6.0, target.y, 0.5)   # the classroom seating area
	var to: Vector3 = aim - target
	var move := create_tween().set_parallel(true)
	move.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.tween_property(program_manager, "global_position", target, 1.0)
	move.tween_property(program_manager, "rotation:y", atan2(to.x, to.z), 1.0)

## The come-back line (greeting 2): played once, the first time the AI Builder
## returns to the classroom from the Platform with questions still unanswered.
func greet_return() -> void:
	if return_greeted or not vanished or program_manager == null:
		return
	return_greeted = true
	_show_pm_caption(PM_RETURN)
	if pm_return_voice != null and pm_return_voice.stream != null:
		pm_return_voice.play()
	else:
		get_tree().create_timer(5.0).timeout.connect(_hide_pm_caption)

## The ending's opening line (greeting 3), shown as on-screen text with her voice.
func greet_ending() -> void:
	if program_manager == null:
		return
	_show_pm_caption(PM_ENDING)
	if pm_caption != null:
		pm_caption.move_to_front()
	if pm_ending_voice != null and pm_ending_voice.stream != null:
		pm_ending_voice.play()
	else:
		get_tree().create_timer(5.0).timeout.connect(_hide_pm_caption)

func _process(_delta: float) -> void:
	if greeted or world == null or world.player == null or world.classroom_sequence == null:
		return
	if world.classroom_sequence.in_classroom():
		greeted = true
		greeting_started_msec = Time.get_ticks_msec()
		_face_player_at_mr_p()
		mrp.play_once("Welcome")
		# The AI Builder greets back — a friendly wave a beat after being welcomed.
		if world.player.has_method("wave"):
			get_tree().create_timer(0.8).timeout.connect(world.player.wave)
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
	# She starts talking about half a second after she appears (not after the fade).
	if pm_voice != null and pm_voice.stream != null:
		get_tree().create_timer(0.5).timeout.connect(pm_voice.play)
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
