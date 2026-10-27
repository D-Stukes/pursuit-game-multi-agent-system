extends Control
## Ordering and keypad interaction; visual styles come from the existing HUD.

signal closed
signal entrance_unlocked
const PuzzleState = preload("res://playtest/EntrancePuzzleState.gd")
var state: RefCounted = PuzzleState.new()
var theme_source: Control
var panel: PanelContainer
var scroll: ScrollContainer
var column: VBoxContainer
var order_label: Label
var feedback: Label
var choices: Array[Button] = []
var order: Array[int] = []
var code_box: VBoxContainer
var code_label: Label
var code_input: LineEdit
var check_button: Button
var reset_button: Button
var hint_button: Button
var unlock_button: Button
var close_button: Button

func _ready() -> void:
	name = "EntrancePuzzle"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", theme_source._panel_style())
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_add_label("UNLOCK THE ENTRANCE", 22)
	_add_label("An agent reads what is happening, chooses a next move, then does it. Select the steps in that order to reveal the entry code.")
	order_label = _add_label("Your order: —")
	# Present a deliberate scramble, not an already solved list.
	for id: int in [2, 0, 1]:
		var choice: Button = theme_source._button("%s · digit %d" % [state.STEPS[id], state.digits[id]], false)
		choice.set_meta("step_id", id)
		choice.pressed.connect(_choose.bind(id))
		column.add_child(choice)
		choices.append(choice)
	check_button = _add_button("Check order", _check_order, true)
	reset_button = _add_button("Reset order", _reset_order)
	hint_button = _add_button("Show hint", _show_hint)
	feedback = _add_label("No time limit. You can retry or come back later.")
	code_box = VBoxContainer.new()
	code_box.add_theme_constant_override("separation", 10)
	column.add_child(code_box)
	code_label = theme_source._label("", 18)
	code_box.add_child(code_label)
	code_input = LineEdit.new()
	code_input.placeholder_text = "Type the 3-digit entry code"
	code_input.max_length = 3
	code_input.custom_minimum_size.y = 42
	code_input.add_theme_font_size_override("font_size", 18)
	code_input.text_submitted.connect(func(_value: String): _unlock())
	code_box.add_child(code_input)
	unlock_button = theme_source._button("Unlock entrance", true)
	unlock_button.pressed.connect(_unlock)
	code_box.add_child(unlock_button)
	code_box.hide()
	close_button = _add_button("Back to building", close)
	# Keep Tab navigation inside this modal; Godot skips hidden/disabled controls.
	var focus_controls: Array[Control] = []
	for choice: Button in choices:
		focus_controls.append(choice)
	focus_controls.append_array([check_button, reset_button, hint_button, code_input, unlock_button, close_button])
	for i: int in range(focus_controls.size()):
		var current: Control = focus_controls[i]
		current.focus_next = current.get_path_to(focus_controls[(i + 1) % focus_controls.size()])
		current.focus_previous = current.get_path_to(focus_controls[(i - 1 + focus_controls.size()) % focus_controls.size()])
	resized.connect(_fit_panel)
	_fit_panel()
	hide()

func _add_label(text: String, font_size: int = 16) -> Label:
	var label: Label = theme_source._label(text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label

func _add_button(text: String, action: Callable, primary: bool = false) -> Button:
	var button: Button = theme_source._button(text, primary)
	button.pressed.connect(action)
	column.add_child(button)
	return button

func _fit_panel() -> void:
	panel.position = Vector2(16, 16)
	panel.size = Vector2(minf(560, size.x - 32), size.y - 32)
	panel.position.x = (size.x - panel.size.x) * 0.5

func open() -> void:
	show()
	if state.solved and not state.unlocked:
		code_input.grab_focus()
	elif state.unlocked:
		close_button.grab_focus()
	else:
		check_button.grab_focus()
		for choice: Button in choices:
			if not choice.disabled:
				choice.grab_focus()
				break

func close() -> void:
	hide()
	closed.emit()

func _choose(id: int) -> void:
	if state.solved or id in order:
		return
	order.append(id)
	var names := PackedStringArray()
	for step: int in order:
		names.append(state.STEPS[step])
	order_label.text = "Your order: " + " → ".join(names)
	for choice: Button in choices:
		choice.disabled = int(choice.get_meta("step_id")) in order
	if order.size() == 3:
		check_button.grab_focus()

func _reset_order() -> void:
	if state.solved:
		return
	order.clear()
	order_label.text = "Your order: —"
	feedback.text = "Choose the first step."
	for choice: Button in choices:
		choice.disabled = false
	choices[0].grab_focus()

func _check_order() -> void:
	if not state.check_order(order):
		feedback.text = "Choose all three steps: read the situation first, choose next, then act. Reset order to try again."
		reset_button.grab_focus()
		return
	feedback.text = "Correct. Sense reads the state; Decide chooses a move; Act performs it. An agent can then observe the result and repeat."
	code_label.text = "Entry code: " + state.revealed_code()
	code_box.show()
	check_button.disabled = true
	reset_button.disabled = true
	check_button.hide()
	reset_button.hide()
	hint_button.hide()
	for choice: Button in choices:
		choice.disabled = true
		choice.hide()
	code_input.grab_focus()
	scroll.ensure_control_visible(code_input)

func _show_hint() -> void:
	feedback.text = "Sense → Decide → Act. Read each step's digit in that order, then enter that code."

func _unlock() -> void:
	if state.unlocked:
		return
	if not state.enter_code(code_input.text):
		feedback.text = "That code does not match. Use the entry code shown above."
		code_input.select_all()
		code_input.grab_focus()
		return
	feedback.text = "Entrance unlocked. Return to the building and walk through the doorway."
	code_input.editable = false
	unlock_button.disabled = true
	entrance_unlocked.emit()
	close_button.grab_focus()
	scroll.ensure_control_visible(close_button)
