extends Node3D
## Mr. P's question room. Everything happens in the caption box: the player
## presses 1-6 to choose one of the six questions (listed in the box), then the
## box shows that question's four answers and the player presses A-D. The chosen
## letter shades light green when right or light red when wrong (try again).
## Mr. P narrates through the caption and his voice slots. Which option is
## correct is tracked here, never shown until the player picks.
const RADIUS: float = 4.6
const HEIGHT: float = 3.8
const LETTERS: Array = ["A", "B", "C", "D"]
const BASE_TILE := Color(0.94, 0.87, 0.43)
const GREEN_TILE := Color(0.46, 0.84, 0.48)
const RED_TILE := Color(0.88, 0.35, 0.35)
# Keyboard: accept both the number row and the numpad for choosing a question.
const NUMBER_KEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const NUMPAD_KEYS: Array = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6]
const ANSWER_KEYS: Array = [KEY_A, KEY_B, KEY_C, KEY_D]
# In-box answer shading.
const HILITE_GREEN := "#b7e9bb"
const HILITE_RED := "#f2b8b8"
const INK_GREEN := "#123a1b"
const INK_RED := "#4a1414"
const ACCENT := "#7fe7ff"
const DIM := "#8aa0a0"
# Mr. P's spoken lines. Drop Jeter's recordings at these paths and they play
# automatically; until then the caption carries every line.
const VOICE_WELCOME := "res://assets/audio/mrp/mrp_welcome_room.wav"
const VOICE_CORRECT := "res://assets/audio/mrp/mrp_correct.wav"
const VOICE_WRONG := "res://assets/audio/mrp/mrp_wrong.wav"
const VOICE_DONE := "res://assets/audio/mrp/mrp_done.wav"
# Mr. P reading each question aloud (one clip per board, recorded by Jeter).
const VOICE_Q := [
	"res://assets/audio/mrp/mrp_q1.wav", "res://assets/audio/mrp/mrp_q2.wav",
	"res://assets/audio/mrp/mrp_q3.wav", "res://assets/audio/mrp/mrp_q4.wav",
	"res://assets/audio/mrp/mrp_q5.wav", "res://assets/audio/mrp/mrp_q6.wav"]

@export var room_environment: Environment
@onready var mrp: Node3D = $MrP
@onready var spawn: Marker3D = $PlayerSpawn
@onready var return_point: Marker3D = $ReturnPoint
@onready var return_prompt: Label3D = $ReturnPoint/Prompt
var world: Node3D
var panels: Array[Node] = []
var voice: AudioStreamPlayer
var state: String = "idle"            # idle | selecting | answering | done
var current: int = -1                 # board being answered
var solved: Dictionary = {}
var last_wrong: bool = false           # the current question's last pick was wrong
var last_pick: int = -1                # option last pressed for the current question
var mrp_scale: Vector3 = Vector3.ONE   # Mr. P's resting scale, for the tuck-away fade
var boards: Array = []                 # per board: {node, tiles[], materials[]}
var caption_panel: PanelContainer
var caption_label: RichTextLabel
var focus_cam: Camera3D                # frames the selected board up close

const QUESTIONS: Array = [
	{"prompt":"What's the difference between an agent and a skill?",
	 "short":"Agent vs. skill",
	 "options":[
		"Skills are learned, agents are hired",
		"Agents manage people, skills manage systems",
		"Agents have autonomy, skills are fixed scripts",
		"A skill is reusable instructions for one task; an agent autonomously plans, remembers, and uses tools to complete multi-step work"],
	 "correct":3},
	{"prompt":"What is the name of a system that has more than one agent?",
	 "short":"The name for a many-agent system",
	 "options":["A single-agent system","A binary network","A multi-agent system (MAS)","A data cluster"],
	 "correct":2},
	{"prompt":"What is an agent handoff?",
	 "short":"What is an agent handoff?",
	 "options":[
		"When two agents merge into one",
		"When one agent passes control of a task to another agent",
		"When an agent restarts its own task",
		"When the user takes over from the agent"],
	 "correct":1},
	{"prompt":"Which is an example of a rule (guardrail) an agent can have?",
	 "short":"Example of an agent guardrail",
	 "options":[
		"Ignore the user's goal",
		"Never use any tools",
		"Always ask before deleting or sending anything",
		"Run forever without stopping"],
	 "correct":2},
	{"prompt":"What is it called when someone deliberately attempts to break a program to find its errors or weaknesses?",
	 "short":"Breaking a program to find its flaws",
	 "options":["Debugging","Red teaming","Fine-tuning","Prompt engineering"],
	 "correct":1},
	{"prompt":"What's the difference between an agent and a bot?",
	 "short":"Agent vs. bot",
	 "options":[
		"They are exactly the same",
		"A bot is smarter than an agent",
		"An agent can only chat; a bot cannot",
		"An agent plans and acts autonomously toward goals; a bot follows fixed, pre-programmed responses"],
	 "correct":3},
]

func _ready() -> void:
	panels = find_children("QuestionBoard*", "Node3D", true, false)
	for i: int in range(QUESTIONS.size()):
		var board: Node3D = find_child("QuestionBoard%d" % (i + 1), true, false)
		if board == null:
			boards.append(null)
			continue
		boards.append(_fill_board(board, QUESTIONS[i], i + 1))
	mrp_scale = mrp.scale
	voice = AudioStreamPlayer.new()
	voice.bus = "Effects"
	add_child(voice)
	focus_cam = Camera3D.new()
	focus_cam.fov = 52
	focus_cam.near = 0.05
	focus_cam.environment = room_environment   # keep the room's lighting in close-up
	add_child(focus_cam)
	set_active(false)

## Put a question's text and four options on a board; return its tile refs.
func _fill_board(board: Node3D, question: Dictionary, number: int) -> Dictionary:
	var header: Label3D = board.get_node("Header")
	header.text = "%d.  %s" % [number, question.prompt]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD
	header.width = 1020
	header.font_size = 40
	var tiles: Array = []
	var materials: Array = []
	for j: int in range(4):
		var label: Label3D = board.get_node("Label" + LETTERS[j])
		label.text = "%s:  %s" % [LETTERS[j], question.options[j]]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.width = 520
		label.font_size = 30
		var tile: MeshInstance3D = board.get_node("Answer" + LETTERS[j])
		var material := StandardMaterial3D.new()
		material.albedo_color = BASE_TILE
		material.roughness = 0.8
		tile.material_override = material
		tiles.append(tile)
		materials.append(material)
	return {"node": board, "header": header, "tiles": tiles, "materials": materials, "correct": int(question.correct)}

func _build_caption() -> void:
	if caption_panel != null or world == null:
		return
	caption_panel = PanelContainer.new()
	caption_panel.add_theme_stylebox_override("panel", world.hud._panel_style())
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label = RichTextLabel.new()
	caption_label.bbcode_enabled = true
	caption_label.fit_content = true
	caption_label.scroll_active = false
	caption_label.custom_minimum_size = Vector2(480, 0)
	caption_label.add_theme_font_size_override("normal_font_size", 19)
	caption_label.add_theme_font_size_override("bold_font_size", 21)
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel.add_child(caption_label)
	world.hud.add_child(caption_panel)
	caption_panel.resized.connect(_fit)
	world.hud.resized.connect(_fit)
	_fit()

## A compact box pinned to the lower-left, sized to its contents.
func _fit() -> void:
	if caption_panel == null:
		return
	caption_panel.reset_size()
	caption_panel.position = Vector2(24, world.hud.size.y - caption_panel.size.y - 54)

# ---- flow ----------------------------------------------------------------

func set_active(active: bool) -> void:
	visible = active
	mrp.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active:
		_build_caption()
		if caption_panel != null:
			caption_panel.show()
		_begin()
	else:
		if caption_panel != null:
			caption_panel.hide()
		_restore_camera()
		state = "idle"
		current = -1

func _begin() -> void:
	state = "selecting"
	current = -1
	last_wrong = false
	last_pick = -1
	_highlight(-1)
	_show_mrp(true)
	if solved.size() >= QUESTIONS.size():
		_done()
		return
	_render_menu()
	_say(VOICE_WELCOME)

## The question list the player chooses from. Solved ones are checked and dimmed.
func _render_menu() -> void:
	if caption_label == null:
		return
	var text := "[b]Mr. P:[/b]  Finally — new student. Pick a question to answer.\n"
	for i: int in range(QUESTIONS.size()):
		var label: String = str(QUESTIONS[i].get("short", QUESTIONS[i].prompt))
		if solved.has(i):
			text += "\n[color=%s]%d.  %s  ✓[/color]" % [DIM, i + 1, label]
		else:
			text += "\n[b]%d.[/b]  %s" % [i + 1, label]
	text += "\n\n[color=%s]Press 1–6 on your keyboard.[/color]" % ACCENT
	caption_label.text = text
	_fit()

## Answer mode: the box shows the question and all four options so the player
## can read and choose; the wall board lights the same answer green or red.
func _render_answering() -> void:
	if caption_label == null or current < 0:
		return
	var q: Dictionary = QUESTIONS[current]
	var correct_idx: int = int(boards[current].correct)
	var text := "[b]Mr. P — Question %d:[/b]  %s\n" % [current + 1, q.prompt]
	for j: int in range(4):
		var row := "%s:  %s" % [LETTERS[j], q.options[j]]
		if j == last_pick and j == correct_idx:
			text += "\n[bgcolor=%s][color=%s] %s [/color][/bgcolor]" % [HILITE_GREEN, INK_GREEN, row]
		elif j == last_pick:
			text += "\n[bgcolor=%s][color=%s] %s [/color][/bgcolor]" % [HILITE_RED, INK_RED, row]
		else:
			text += "\n[b]%s:[/b]  %s" % [LETTERS[j], q.options[j]]
	if last_pick >= 0 and last_pick == correct_idx:
		text += "\n\n[color=%s]Correct![/color]" % ACCENT
	elif last_wrong:
		text += "\n\n[color=%s]Not quite — try again. Press A, B, C, or D.  (Esc for the list.)[/color]" % ACCENT
	else:
		text += "\n\n[color=%s]Press the letter you think is right: A, B, C, or D.  (Esc for the list.)[/color]" % ACCENT
	caption_label.text = text
	_fit()

func _input(event: InputEvent) -> void:
	if not visible or world == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if state == "selecting":
		for i: int in range(NUMBER_KEYS.size()):
			if event.keycode == NUMBER_KEYS[i] or event.keycode == NUMPAD_KEYS[i]:
				_select(i)
				get_viewport().set_input_as_handled()
				return
	elif state == "answering":
		if event.keycode == KEY_ESCAPE:
			_cancel_answer()
			get_viewport().set_input_as_handled()
			return
		for j: int in range(ANSWER_KEYS.size()):
			if event.keycode == ANSWER_KEYS[j]:
				_answer(j)
				get_viewport().set_input_as_handled()
				return

func _select(i: int) -> void:
	if i >= QUESTIONS.size() or boards[i] == null:
		return
	if solved.has(i):
		_render_menu()
		return
	current = i
	state = "answering"
	last_wrong = false
	last_pick = -1
	_highlight(i)
	world.player.set_controls_locked(true)   # so A-D pick answers instead of moving
	_show_mrp(false)                           # tuck Mr. P away so he doesn't block the board
	_focus_board(i)                            # bring the wall board into view
	_render_answering()
	_say(VOICE_Q[i])                           # Mr. P reads the question aloud

## Frame the chosen board up close so its question and options read large and
## the player sees it light up green or red when they answer.
func _focus_board(i: int) -> void:
	var board_node: Node3D = boards[i].node
	var bpos: Vector3 = board_node.global_position
	var inward: Vector3 = global_position - bpos
	inward.y = 0.0
	inward = inward.normalized() if inward.length() > 0.01 else Vector3.FORWARD
	focus_cam.global_position = bpos + inward * 3.05
	focus_cam.look_at(bpos, Vector3.UP)
	focus_cam.make_current()

func _restore_camera() -> void:
	if world != null and world.player != null and world.player.camera != null:
		world.player.camera.make_current()

func _cancel_answer() -> void:
	current = -1
	state = "selecting"
	last_wrong = false
	last_pick = -1
	_highlight(-1)
	_restore_camera()
	_show_mrp(true)
	world.player.set_controls_locked(false)
	_render_menu()

func _answer(j: int) -> void:
	if current < 0:
		return
	var board: Dictionary = boards[current]
	var material: StandardMaterial3D = board.materials[j]
	var tile: MeshInstance3D = board.tiles[j]
	last_pick = j
	if j == int(board.correct):
		# The wall tile lights green; hold on it, then back to the list.
		material.albedo_color = GREEN_TILE
		tile.position.z -= 0.02
		solved[current] = true
		last_wrong = false
		state = "reveal"                      # ignore keys while the green answer shows
		_render_answering()
		_say(VOICE_CORRECT)
		var done_now: bool = solved.size() >= QUESTIONS.size()
		var pause: SceneTreeTimer = get_tree().create_timer(1.8)
		pause.timeout.connect(_after_correct.bind(done_now))
	else:
		# The wall tile lights red; Mr. P says to try again.
		material.albedo_color = RED_TILE
		last_wrong = true
		_render_answering()
		_say(VOICE_WRONG)
		var timer: SceneTreeTimer = get_tree().create_timer(1.2)
		timer.timeout.connect(_clear_wrong.bind(material))

## After the green answer has been shown, return to the player's view and the
## question list (or finish if every question is solved). Mr. P reappears.
func _after_correct(done_now: bool) -> void:
	_highlight(-1)
	_restore_camera()
	current = -1
	last_pick = -1
	if done_now:
		_done()
	else:
		state = "selecting"
		_show_mrp(true)
		world.player.set_controls_locked(false)
		_render_menu()

## Clear a wrong pick's red shading on the wall so the player can try again.
func _clear_wrong(mat: StandardMaterial3D) -> void:
	if is_instance_valid(mat):
		mat.albedo_color = BASE_TILE
	if state == "answering":
		last_wrong = false
		last_pick = -1
		_render_answering()

func _done() -> void:
	state = "done"
	current = -1
	last_wrong = false
	last_pick = -1
	_highlight(-1)
	_show_mrp(true)
	if world.player != null:
		world.player.set_controls_locked(false)
	if caption_label != null:
		caption_label.text = "[b]Mr. P:[/b]  Outstanding — you've answered all my questions. You are accomplished for the day!\n\n[color=%s]Step on the marked pad and press E to return to your computer.[/color]" % ACCENT
		_fit()
	_say(VOICE_DONE)

## Brighten the chosen board's tiles; dim the rest.
func _highlight(index: int) -> void:
	for b: int in range(boards.size()):
		if boards[b] == null:
			continue
		for material: StandardMaterial3D in boards[b].materials:
			material.emission_enabled = b == index
			material.emission = Color(1, 1, 1)
			material.emission_energy_multiplier = 0.3 if b == index else 0.0

## Fade Mr. P in or out. He steps aside while the player answers a question so he
## never blocks the board, then returns between questions and at the end.
func _show_mrp(on: bool) -> void:
	if mrp == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if on:
		mrp.process_mode = Node.PROCESS_MODE_INHERIT
		mrp.visible = true
		tween.tween_property(mrp, "scale", mrp_scale, 0.3)
	else:
		tween.tween_property(mrp, "scale", mrp_scale * 0.02, 0.3)
		tween.tween_callback(func() -> void:
			mrp.visible = false
			mrp.process_mode = Node.PROCESS_MODE_DISABLED)

func _say(path: String) -> void:
	if ResourceLoader.exists(path):
		voice.stream = load(path)
		voice.play()
