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
# 3D answer buttons: raised depth, a white glow/pulse while a board is active,
# and a click when pressed. Mouse picking uses a dedicated ray-pick layer.
const WHITE_GLOW := Color(1, 1, 1)
const BUTTON_DEPTH := 0.09         # how far the button stands off the board
const BUTTON_PRESS := 0.045        # how far it sinks when pressed
const BUTTON_LAYER := 512          # ray-pick collision layer for the buttons
const CLICK_SOUND := "res://assets/audio/menu.wav"
# Try the Platform without the on-screen caption box: the 3D boards show the
# questions and answers, and Mr. P is heard rather than captioned.
const SHOW_CAPTION := false
const HINT_COLOR := Color(0.45, 0.85, 1.0)   # Dial-a-Friend flash on the right answer
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
const VOICE_SUCCESS := "res://assets/audio/success.wav"   # short chime after the first correct, to avoid repeating the spoken line
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
var state: String = "idle"            # idle | selecting | answering | reveal | done
var current: int = -1                 # board being answered
var solved: Dictionary = {}
var last_wrong: bool = false           # the current question's last pick was wrong
var last_pick: int = -1                # option last pressed for the current question
var pending_done: bool = false         # true if the just-solved answer was the last one
var mrp_scale: Vector3 = Vector3.ONE   # Mr. P's resting scale, for the tuck-away fade
var mrp_home: Vector3 = Vector3.ZERO   # Mr. P's resting position, to restore from the park spot
var boards: Array = []                 # per board: {node, tiles[], materials[]}
var caption_panel: PanelContainer
var caption_label: RichTextLabel
var focus_cam: Camera3D                # frames the selected board up close
var sfx: AudioStreamPlayer             # short UI click when a button is pressed
var pulse_tween: Tween                 # gentle white pulse on the active board
var answer_lookup: Dictionary = {}     # button Area3D id -> [board index, option]
var friend_calls_left: int = 3         # Dial-a-Friend uses for the whole game
var friend_used: Dictionary = {}       # question index -> a friend was called
var read_first: bool = false           # Mr. P reads a question aloud only the first time

const QUESTIONS: Array = [
	{"prompt":"What's the difference between an agent and a skill?",
	 "short":"Agent vs. skill",
	 "options":[
		"Skills are learned, agents are hired",
		"Agents manage people, skills manage systems",
		"Agents have autonomy, skills are fixed scripts",
		"A skill is reusable instructions for one task; an agent autonomously plans, remembers, and uses tools to complete multi-step work"],
	 "correct":3,
	 "explanation":"A skill is a fixed set of instructions for one job — the same steps every time. An agent is bigger: it plans its own steps, remembers what happened, and uses tools to finish multi-step work on its own."},
	{"prompt":"What is the name of a system that has more than one agent?",
	 "short":"The name for a many-agent system",
	 "options":["A single-agent system","A binary network","A multi-agent system (MAS)","A data cluster"],
	 "correct":2,
	 "explanation":"Once more than one agent works together, it's called a multi-agent system — MAS for short. That's exactly what you're building here."},
	{"prompt":"What is an agent handoff?",
	 "short":"What is an agent handoff?",
	 "options":[
		"When two agents merge into one",
		"When one agent passes control of a task to another agent",
		"When an agent restarts its own task",
		"When the user takes over from the agent"],
	 "correct":1,
	 "explanation":"A handoff is when one agent passes control of a task to another — like the Orchestrator handing the next job to the right specialist. The work continues; it just changes hands."},
	{"prompt":"Which is an example of a rule (guardrail) an agent can have?",
	 "short":"Example of an agent guardrail",
	 "options":[
		"Ignore the user's goal",
		"Never use any tools",
		"Always ask before deleting or sending anything",
		"Run forever without stopping"],
	 "correct":2,
	 "explanation":"A guardrail is a safety rule that keeps an agent in check. 'Always ask before deleting or sending anything' is a classic one — it stops the agent from doing something costly without a human's okay."},
	{"prompt":"What is it called when someone deliberately attempts to break a program to find its errors or weaknesses?",
	 "short":"Breaking a program to find its flaws",
	 "options":["Debugging","Red teaming","Fine-tuning","Prompt engineering"],
	 "correct":1,
	 "explanation":"Deliberately trying to break a program to expose its weaknesses is called red teaming. It's how teams find the flaws before anyone else does."},
	{"prompt":"What's the difference between an agent and a bot?",
	 "short":"Agent vs. bot",
	 "options":[
		"They are exactly the same",
		"A bot is smarter than an agent",
		"An agent can only chat; a bot cannot",
		"An agent plans and acts autonomously toward goals; a bot follows fixed, pre-programmed responses"],
	 "correct":3,
	 "explanation":"A bot follows fixed, pre-programmed responses — same input, same reply. An agent plans and acts on its own toward a goal, adapting as it goes. Autonomy is the difference."},
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
	mrp_home = mrp.position
	voice = AudioStreamPlayer.new()
	voice.bus = "Effects"
	add_child(voice)
	focus_cam = Camera3D.new()
	focus_cam.fov = 52
	focus_cam.near = 0.05
	focus_cam.environment = room_environment   # keep the room's lighting in close-up
	add_child(focus_cam)
	sfx = AudioStreamPlayer.new()
	sfx.bus = "Effects"
	add_child(sfx)
	set_active(false)

## Put a question's text and four options on a board; return its tile refs.
func _fill_board(board: Node3D, question: Dictionary, number: int) -> Dictionary:
	var header: Label3D = board.get_node("Header")
	header.text = "%d.  %s" % [number, question.prompt]
	header.autowrap_mode = TextServer.AUTOWRAP_WORD
	_fit_label_to_box(header, 3.3, 0.33, 48)
	var tiles: Array = []
	var materials: Array = []
	var labels: Array = []
	var areas: Array = []
	for j: int in range(4):
		var label: Label3D = board.get_node("Label" + LETTERS[j])
		label.text = "%s:  %s" % [LETTERS[j], question.options[j]]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Fit the font to the button's actual size so it scales with the box
		# (Godot has no vw/vh — we measure the wrapped text and size it to fit).
		_fit_label_to_box(label, 1.56, 0.24, 30)
		var tile: MeshInstance3D = board.get_node("Answer" + LETTERS[j])
		# Give the flat slot real depth so it reads as a pressable 3D button,
		# with the answer text sitting on its front face.
		var box := BoxMesh.new()
		box.size = Vector3(1.56, 0.24, BUTTON_DEPTH)
		tile.mesh = box
		tile.position.z = 0.09
		label.position.z = tile.position.z + BUTTON_DEPTH * 0.5 + 0.02
		var material := StandardMaterial3D.new()
		material.albedo_color = BASE_TILE
		material.roughness = 0.8
		tile.material_override = material
		# A pickable area on the button so the mouse can press it as well as A-D.
		var area := Area3D.new()
		area.collision_layer = BUTTON_LAYER
		area.collision_mask = 0
		area.input_ray_pickable = true
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.56, 0.24, BUTTON_DEPTH)
		shape.shape = box_shape
		area.add_child(shape)
		tile.add_child(area)
		answer_lookup[area.get_instance_id()] = [number - 1, j]
		tiles.append(tile)
		materials.append(material)
		labels.append(label)
		areas.append(area)
	return {"node": board, "header": header, "tiles": tiles, "materials": materials, "labels": labels, "areas": areas, "correct": int(question.correct)}

## Scale a Label3D's font so the wrapped text fits inside a world-space box (the
## button/header face). This replaces a fixed pixel font with one that adjusts to
## the box and the text length — Godot's stand-in for responsive (vw/vh) sizing.
func _fit_label_to_box(label: Label3D, box_w: float, box_h: float, max_size: int) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var pad: float = 0.9
	var width_px: float = box_w * pad / label.pixel_size
	var height_px: float = box_h * pad / label.pixel_size
	label.width = width_px
	var size: int = max_size
	while size > 10:
		var dims: Vector2 = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width_px, size)
		if dims.y <= height_px:
			break
		size -= 1
	label.font_size = size

func _build_caption() -> void:
	if not SHOW_CAPTION or caption_panel != null or world == null:
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
	var text := "[b]Mr. P:[/b]  Finally — a new AI Builder. Pick a question to answer.\n"
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
	# Dial-a-Friend: while still answering, show the button with calls left and,
	# if a friend was called for this question, the friend's answer and why.
	if state == "answering":
		if friend_used.has(current):
			var ci: int = int(boards[current].correct)
			text += "\n\n[b]Dial-a-Friend:[/b]  It's %s — \"%s\".  %s" % [LETTERS[ci], q.options[ci], str(q.get("explanation", ""))]
		if friend_calls_left > 0:
			text += "\n[color=%s]Dial-a-Friend (F) · %d left[/color]" % [ACCENT, friend_calls_left]
		else:
			text += "\n[color=%s]Dial-a-Friend · no calls left[/color]" % DIM
	if last_pick >= 0 and last_pick == correct_idx:
		text += "\n\n[b][color=%s]Correct![/color][/b]" % ACCENT
		if friend_used.has(current):
			# A friend already gave the reason, so Mr. P only congratulates.
			text += "\n[b]Mr. P:[/b]  Well done!"
		else:
			var explanation: String = str(q.get("explanation", ""))
			if explanation != "":
				text += "\n[b]Mr. P:[/b]  %s" % explanation
		text += "\n\n[color=%s]Press Space or Enter to continue.[/color]" % DIM
	elif last_wrong:
		text += "\n\n[b]Mr. P:[/b]  That is incorrect! Please try again."
		text += "\n[color=%s](Press A, B, C, or D.  Esc for the list.)[/color]" % DIM
	else:
		text += "\n\n[color=%s]Press the letter you think is right: A, B, C, or D.  (Esc for the list.)[/color]" % ACCENT
	caption_label.text = text
	_fit()

func _input(event: InputEvent) -> void:
	if not visible or world == null:
		return
	var is_key: bool = event is InputEventKey and event.pressed and not event.echo
	var is_click: bool = event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not is_key and not is_click:
		return
	# A left-click on a 3D answer button presses it, just like the A-D keys.
	if state == "answering" and is_click:
		var picked: int = _pick_answer((event as InputEventMouseButton).position)
		if picked >= 0:
			_answer(picked)
			get_viewport().set_input_as_handled()
		return
	if not is_key:
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
		if event.keycode == KEY_F:
			_dial_friend()
			get_viewport().set_input_as_handled()
			return
		for j: int in range(ANSWER_KEYS.size()):
			if event.keycode == ANSWER_KEYS[j]:
				_answer(j)
				get_viewport().set_input_as_handled()
				return
	elif state == "reveal":
		# The green answer and its explanation stay up until the AI Builder
		# presses Space or Enter to move on.
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_after_correct(pending_done)
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
	# Mr. P reads a question aloud only the first time; after that the boards show
	# each question, so he stays quiet instead of repeating "A, B, C, or D".
	if not read_first:
		_say(VOICE_Q[i])
		read_first = true
	_start_pulse(i)                            # gentle white pulse on the active board

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
	_stop_pulse()
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
	last_pick = j
	_play_click()
	_press_tile(current, j)                   # press in, then pop back
	if j == int(board.correct):
		# The button turns green and stays green.
		material.albedo_color = GREEN_TILE
		solved[current] = true
		last_wrong = false
		pending_done = solved.size() >= QUESTIONS.size()
		state = "reveal"
		_stop_pulse()
		# Avoid repeating the same spoken "congratulations" on every question:
		# speak it once, use a short chime after that, and let _done() give the
		# completion line. (Swap VOICE_SUCCESS for varied Mr. P recordings later.)
		if pending_done:
			pass
		elif solved.size() <= 1:
			_say(VOICE_CORRECT)
		else:
			_say(VOICE_SUCCESS)
		if caption_label != null:
			_render_answering()               # show the explanation; wait for Space/Enter
		elif world != null:
			# No caption to read, so move on after a brief green hold.
			get_tree().create_timer(1.4).timeout.connect(_after_correct.bind(pending_done))
	else:
		# The button turns red, Mr. P says to try again, then it returns to normal.
		material.albedo_color = RED_TILE
		last_wrong = true
		_render_answering()
		_say(VOICE_WRONG)
		var timer: SceneTreeTimer = get_tree().create_timer(1.2)
		timer.timeout.connect(_clear_wrong.bind(material))

## After the green answer has been shown, return to the player's view and the
## question list (or finish if every question is solved). Mr. P reappears.
func _after_correct(done_now: bool) -> void:
	_stop_pulse()
	_highlight(-1)
	_restore_camera()
	current = -1
	last_pick = -1
	if done_now:
		_done()
	else:
		state = "selecting"
		_show_mrp(true)                        # Mr. P reappears for the next question
		world.player.set_controls_locked(false)
		_render_menu()

## Dial-a-Friend: a scripted helper (no live AI). Three calls for the whole
## game; calling reveals the correct answer and why, but the AI Builder still
## presses the answer. Calls left persist when leaving and re-entering the room.
func _dial_friend() -> void:
	if state != "answering" or current < 0:
		return
	if friend_used.has(current):
		return                                 # already helped on this question
	if friend_calls_left <= 0:
		_render_answering()                    # refresh so the button reads "no calls left"
		return
	friend_calls_left -= 1
	friend_used[current] = true
	_play_click()
	if caption_label != null:
		_render_answering()
	else:
		_flash_correct(current)                # no caption: flash the right answer instead

## Dial-a-Friend with the caption off: pulse the correct button a few times so the
## AI Builder can see the answer without any text.
func _flash_correct(board_index: int) -> void:
	if board_index < 0 or board_index >= boards.size() or boards[board_index] == null:
		return
	var ci: int = int(boards[board_index].correct)
	var mat: StandardMaterial3D = boards[board_index].materials[ci]
	var base: Color = mat.albedo_color
	var flash := create_tween().set_loops(3)
	flash.tween_property(mat, "albedo_color", HINT_COLOR, 0.22)
	flash.tween_property(mat, "albedo_color", base, 0.22)

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
	_stop_pulse()
	_highlight(-1)
	_show_mrp(true)
	if world.player != null:
		world.player.set_controls_locked(false)
	if caption_label != null:
		caption_label.text = "[b]Mr. P:[/b]  Outstanding — you've answered all my questions. You are accomplished for the day!\n\n[color=%s]Step on the marked pad and press E to return to your computer.[/color]" % ACCENT
		_fit()
	_say(VOICE_DONE)

# ---- 3D button feedback -------------------------------------------------

## A short click when any button is pressed.
func _play_click() -> void:
	if sfx != null:
		sfx.stream = load(CLICK_SOUND)
		sfx.play()

## Sink the chosen button in, then let it pop back to rest.
func _press_tile(board_index: int, j: int) -> void:
	if board_index < 0 or board_index >= boards.size() or boards[board_index] == null:
		return
	var tile: MeshInstance3D = boards[board_index].tiles[j]
	var label: Label3D = boards[board_index].labels[j]
	var tz: float = 0.09
	var lz: float = tz + BUTTON_DEPTH * 0.5 + 0.02
	var press := create_tween()
	press.tween_property(tile, "position:z", tz - BUTTON_PRESS, 0.06)
	press.parallel().tween_property(label, "position:z", lz - BUTTON_PRESS, 0.06)
	press.tween_property(tile, "position:z", tz, 0.10)
	press.parallel().tween_property(label, "position:z", lz, 0.10)

## Gentle breathing white glow on the active board while it is being answered.
func _start_pulse(index: int) -> void:
	_stop_pulse()
	if index < 0 or index >= boards.size() or boards[index] == null:
		return
	for material: StandardMaterial3D in boards[index].materials:
		material.emission_enabled = true
		material.emission = WHITE_GLOW
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_method(_set_board_glow.bind(index), 0.15, 0.55, 0.8)
	pulse_tween.tween_method(_set_board_glow.bind(index), 0.55, 0.15, 0.8)

func _set_board_glow(energy: float, index: int) -> void:
	if index < 0 or index >= boards.size() or boards[index] == null:
		return
	for material: StandardMaterial3D in boards[index].materials:
		material.emission_energy_multiplier = energy

func _stop_pulse() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = null

## Which answer (if any) a screen click lands on, via the buttons' pick areas.
func _pick_answer(screen_pos: Vector2) -> int:
	if current < 0:
		return -1
	var cam: Camera3D = focus_cam if focus_cam != null and focus_cam.current else get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var to: Vector3 = from + cam.project_ray_normal(screen_pos) * 12.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = BUTTON_LAYER
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	var info: Variant = answer_lookup.get(hit.collider.get_instance_id(), null)
	if info == null or int(info[0]) != current:
		return -1
	return int(info[1])

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
	# A true alpha fade (via each mesh's transparency), not a shrink: he fades out
	# completely while the AI Builder answers and fades back in for the next one.
	var meshes: Array[Node] = mrp.find_children("*", "GeometryInstance3D", true, false)
	if on:
		mrp.visible = true
		mrp.process_mode = Node.PROCESS_MODE_INHERIT
	var tween := create_tween().set_parallel(true)
	for m: Node in meshes:
		tween.tween_property(m, "transparency", 0.0 if on else 1.0, 0.3)
	if not on:
		tween.chain().tween_callback(func() -> void:
			mrp.visible = false
			mrp.process_mode = Node.PROCESS_MODE_DISABLED)

func _say(path: String) -> void:
	if ResourceLoader.exists(path):
		voice.stream = load(path)
		voice.play()
