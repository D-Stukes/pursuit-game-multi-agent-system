extends Control
## One required circuit, three optional bonuses and a physical-style code keypad. Rules verify connectivity; this screen presents results.

signal closed
signal entrance_unlocked
## Leaving after the first real unlock; Main fades out and places the player at the doorway.
signal entry_requested
const PuzzleState = preload("res://game/EntrancePuzzleState.gd")
const Tile = preload("res://game/PipeTile.gd")
const UI = preload("res://game/GameHUD.gd")
const BASE := Vector2(1040, 640)
const BOARD := Rect2(70, 130, 416, 416)
var state: RefCounted = PuzzleState.new()
var theme_source: Control
var panel: Control
var art: Control
var tiles: Array[Button] = []
var level_label: Label
var feedback: Label
var check_button: Button
var hint_button: Button
var reset_button: Button
var edit_row: HBoxContainer
var reward_label: Label
var next_button: Button
var signal_panel: PanelContainer
var keypad: GridContainer
var keypad_buttons: Array[Button]=[]
var celebration_art: Control
var celebration_remaining: float=0
var celebration_count: int=0
var code_box: VBoxContainer
var code_label: Label
var code_feedback: Label
var code_input: LineEdit
var unlock_button: Button
var guide: Control
var guide_panel: PanelContainer
var guide_button: Button
var guide_seen: bool=false
var close_button: Button
var replay_button: Button
var entry_pending: bool=false
var replaying: bool=false
var earned_state: RefCounted

func _ready() -> void:
	name = "EntrancePuzzle"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(.015, .025, .07, .94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = Control.new()
	panel.size = BASE
	add_child(panel)
	art = Control.new()
	art.size = BASE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_panel)
	panel.add_child(art)
	level_label = _label("", Vector2(32, 22), 27)
	var info := VBoxContainer.new()
	info.position = Vector2(548, 92)
	info.size = Vector2(460, 476)
	info.add_theme_constant_override("separation", 8)
	panel.add_child(info)
	edit_row = HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 8)
	info.add_child(edit_row)
	hint_button = _button(edit_row, "Hint", _show_hint)
	reset_button = _button(edit_row, "Reset", _reset_level)
	check_button = _button(edit_row, "Test circuit", _test_circuit, true)
	feedback = _add_label(info, "Click a pipe to rotate it. Join IN to OUT, then choose Test circuit.", 16)
	feedback.custom_minimum_size.y = 44
	# The door console stays beside the board; power arriving lights the code on its display.
	var console := PanelContainer.new()
	var outline: StyleBoxFlat = theme_source._panel_style()
	outline.draw_center = false
	outline.border_color = Color("36507a")
	outline.set_border_width_all(1)
	outline.set_corner_radius_all(8)
	outline.set_content_margin_all(12)
	console.add_theme_stylebox_override("panel", outline)
	info.add_child(console)
	var console_column := VBoxContainer.new()
	console_column.add_theme_constant_override("separation", 8)
	console.add_child(console_column)
	var console_header := HBoxContainer.new()
	console_column.add_child(console_header)
	var display_title: Label = _add_label(console_header, "DOOR DISPLAY", 12)
	display_title.add_theme_color_override("font_color", Color(UI.WHITE, .62))
	display_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_label = _add_label(console_header, "", 14)
	code_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	signal_panel = PanelContainer.new()
	var style: StyleBoxFlat = theme_source._panel_style()
	style.bg_color = Color("0b232e")
	style.border_color = Tile.CONDUCTOR
	style.set_border_width_all(1)
	signal_panel.add_theme_stylebox_override("panel", style)
	signal_panel.custom_minimum_size.y = 46
	console_column.add_child(signal_panel)
	reward_label = _add_label(signal_panel, "- - - -", 30)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", Tile.POWER)
	code_box = VBoxContainer.new()
	code_box.add_theme_constant_override("separation", 6)
	console_column.add_child(code_box)
	code_input = LineEdit.new()
	code_input.keep_editing_on_text_submit = true
	code_input.placeholder_text = "Type the code"
	code_input.max_length = 4
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.custom_minimum_size.y = 38
	code_input.add_theme_font_size_override("font_size", 22)
	code_input.text_submitted.connect(func(_value: String): _unlock())
	code_box.add_child(code_input)
	keypad=GridContainer.new();keypad.columns=3
	keypad.add_theme_constant_override("h_separation",6);keypad.add_theme_constant_override("v_separation",6)
	code_box.add_child(keypad)
	for value: String in ["1","2","3","4","5","6","7","8","9","Clear","0","⌫"]:
		var key: Button=_button(keypad,value,_keypad_press.bind(value))
		key.add_theme_font_size_override("font_size",16);_compact(key,28);keypad_buttons.append(key)
	unlock_button = _button(code_box, "Unlock entrance", _unlock, true)
	_compact(unlock_button, 38)
	next_button = _button(console_column, "Next level", _next_level, true)
	replay_button = _button(console_column, "Play again", start_replay)
	code_feedback = _add_label(console_column, "", 14)
	close_button = theme_source._button("Back to building [Esc]", false)
	close_button.position = Vector2(734, 580)
	close_button.size = Vector2(274, 42)
	close_button.pressed.connect(leave)
	panel.add_child(close_button)
	_label("Click / Enter: rotate    Tab / arrows: select    Esc: close", Vector2(32, 592), 16)
	resized.connect(_fit_panel)
	_build_tiles()
	_build_guide()
	celebration_art=Control.new();celebration_art.size=BASE;celebration_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(celebration_art);celebration_art.draw.connect(_draw_celebration)
	_sync()
	_fit_panel()
	hide()

func _build_guide() -> void:
	guide=Control.new();guide.size=BASE;guide.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.add_child(guide)
	var shade:=ColorRect.new();shade.color=Color(UI.NAVY,.94)
	shade.size=BASE;guide.add_child(shade)
	guide_panel=PanelContainer.new();guide_panel.position=Vector2(240,150)
	guide_panel.custom_minimum_size.x=560
	guide_panel.add_theme_stylebox_override("panel",theme_source._panel_style())
	guide.add_child(guide_panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16)
	guide_panel.add_child(column)
	_add_label(column,"RESTORE THE ENTRANCE SIGNAL",24)
	var steps: Label=_add_label(column,"The door needs power. Restore one circuit to reveal its four-digit entry code.\n\n1. Click a pipe, or press Enter, to rotate it.\n2. Connect IN to OUT, then choose Test circuit.\n3. Enter the four-digit code on the number pad.\n\nThere’s no timer. Hints are free. Three bonus puzzles are optional after entry is unlocked.",18)
	steps.custom_minimum_size.x=528
	guide_button=_button(column,"Connect the first circuit",_start_puzzle,true)
	guide_button.focus_next=NodePath(".");guide_button.focus_previous=NodePath(".")
	guide.hide()

func _start_puzzle() -> void:
	guide_seen=true;guide.hide();_sync()
	tiles[state.source].grab_focus()

func _input(event: InputEvent) -> void:
	if visible and guide.visible and event is InputEventKey and event.pressed and event.keycode in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		guide_button.grab_focus();get_viewport().set_input_as_handled()

func _label(text: String, at: Vector2, font_size: int) -> Label:
	var label: Label = theme_source._label(text, font_size)
	label.position = at
	panel.add_child(label)
	return label

func _add_label(parent: Control, text: String, font_size: int) -> Label:
	var label: Label = theme_source._label(text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, action: Callable, primary: bool = false) -> Button:
	var button: Button = theme_source._button(text, primary)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	_set_disabled_look(button, false)
	parent.add_child(button)
	return button

## Locked controls stay in the game's navy style; a finished circuit reads as success, not greyed out.
func _set_disabled_look(button: Button, success: bool) -> void:
	var muted: StyleBoxFlat = theme_source._panel_style()
	muted.border_color = UI.SUCCESS if success else Color(UI.CYAN, .22)
	muted.set_border_width_all(1)
	muted.content_margin_top = button.get_theme_stylebox("normal").content_margin_top
	muted.content_margin_bottom = button.get_theme_stylebox("normal").content_margin_bottom
	button.add_theme_stylebox_override("disabled", muted)
	button.add_theme_color_override("font_disabled_color", UI.SUCCESS if success else Color(UI.WHITE, .38))

func _compact(button: Button, height: float) -> void:
	button.custom_minimum_size.y = height
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBox = button.get_theme_stylebox(state).duplicate()
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, box)

func _build_tiles() -> void:
	for tile: Button in tiles:
		panel.remove_child(tile)
		tile.queue_free()
	tiles.clear()
	var side: float = BOARD.size.x / state.width
	for index: int in range(state.masks.size()):
		var tile: Button = Tile.new()
		tile.name = "Pipe_%d_%d" % [state.level, index]
		tile.position = BOARD.position + Vector2(index % state.width, index / state.width) * side
		tile.size = Vector2.ONE * side
		tile.palette=state.level
		tile.pressed.connect(_rotate.bind(index))
		panel.add_child(tile)
		tiles.append(tile)
	for i: int in range(tiles.size()):
		var x: int = i % state.width
		var y: int = i / state.width
		tiles[i].focus_neighbor_left = tiles[i].get_path_to(tiles[y * state.width + posmod(x - 1, state.width)])
		tiles[i].focus_neighbor_right = tiles[i].get_path_to(tiles[y * state.width + (x + 1) % state.width])
		tiles[i].focus_neighbor_top = tiles[i].get_path_to(tiles[posmod(y - 1, state.width) * state.width + x])
		tiles[i].focus_neighbor_bottom = tiles[i].get_path_to(tiles[((y + 1) % state.width) * state.width + x])

func _fit_panel() -> void:
	if not is_instance_valid(panel): return
	var factor: float = minf((size.x - 32) / BASE.x, (size.y - 32) / BASE.y)
	panel.scale = Vector2.ONE * factor
	panel.position = (size - BASE * factor) * .5

func open() -> void:
	show()
	guide.visible=not guide_seen and not state.solved and state.moves==0 and state.rewards.is_empty()
	_sync()
	if guide.visible: guide_button.grab_focus()
	elif state.unlocked: close_button.grab_focus()
	elif state.solved and not state.unlocked: code_input.grab_focus()
	elif state.level_cleared: next_button.grab_focus()
	else: tiles[state.source].grab_focus()

func leave() -> void:
	if entry_pending: entry_requested.emit()
	else: close()

func close() -> void:
	entry_pending=false
	if replaying: _end_replay()
	hide()
	closed.emit()

## A fresh practice copy; the earned state, gate and reserve pellet stay untouched.
func start_replay() -> void:
	if not replaying: earned_state=state
	replaying=true;state=PuzzleState.new();guide.hide()
	celebration_remaining=0;celebration_art.queue_redraw()
	code_input.text="";code_input.placeholder_text="Type the code"
	code_feedback.text=""
	feedback.text="Practice run: restore the circuit and enter its new code. Nothing is awarded."
	_build_tiles();_sync()
	tiles[state.source].grab_focus()

func _end_replay() -> void:
	state=earned_state;replaying=false
	_build_tiles();_sync()

func _rotate(index: int) -> void:
	if guide.visible:return
	if not state.rotate_tile(index): return
	GameAudio.play("pipe-turn")
	feedback.text = "Turn the pipes until power reaches OUT."
	for tile: Button in tiles: tile.hinted = false
	_sync()

func _show_hint() -> void:
	feedback.text = state.hint_text()
	var index: int = state.hint_index()
	for i: int in range(tiles.size()): tiles[i].hinted = i == index
	if index >= 0: tiles[index].grab_focus()

func _reset_level() -> void:
	state.reset_level()
	feedback.text = "This level is reset. Earlier transmissions are kept."
	for tile: Button in tiles: tile.hinted = false
	_sync()
	tiles[state.source].grab_focus()

func _test_circuit() -> void:
	if guide.visible:return
	if not state.test_circuit():
		GameAudio.play("error")
		feedback.text = "The circuit is still open. Follow the gold line from IN and check the next pipe."
		_sync()
		return
	GameAudio.play("success")
	feedback.text = "Circuit restored. The door display shows the entry code." if state.solved and not state.unlocked else "Circuit restored. Bonus complete."
	_sync()
	if state.solved and not state.unlocked: code_input.grab_focus()
	elif next_button.visible: next_button.grab_focus()
	else:close_button.grab_focus()

func _next_level() -> void:
	if not state.unlocked or not state.next_level(): return
	celebration_remaining=0
	celebration_art.queue_redraw()
	_build_tiles()
	feedback.text = "Optional bonus circuit: connect IN to OUT for fun. Hints and retries are free."
	_sync()
	tiles[state.source].grab_focus()

func _sync() -> void:
	level_label.text = ("Practice · " if replaying else "")+("Entry circuit" if state.level==0 else "Optional bonus %d of 3"%state.level)
	var powered: Array = state.reachable_tiles()
	for i: int in range(tiles.size()):
		tiles[i].mask = state.masks[i]
		tiles[i].powered = i in powered
		tiles[i].disabled = state.level_cleared or guide.visible
		tiles[i].tooltip_text = "Row %d, column %d: %s. Activate to rotate clockwise." % [i / state.width + 1, i % state.width + 1, state.ports_text(state.masks[i])]
	check_button.disabled=guide.visible or state.level_cleared
	hint_button.disabled=guide.visible or state.level_cleared
	reset_button.disabled=guide.visible or state.level_cleared
	var check_text: String = "Circuit ✓" if state.level_cleared else "Test circuit"
	if check_button.text != check_text:
		check_button.text = check_text
		_set_disabled_look(check_button, state.level_cleared)
	next_button.visible = state.unlocked and state.level_cleared and state.level<state.BOARDS.size()-1
	next_button.text="Play optional bonus %d / 3"%(state.level+1)
	replay_button.visible = state.unlocked
	# The keypad is always on the console; it accepts input once power reveals the code.
	code_box.visible = not state.unlocked
	var typing: bool = state.solved and not state.unlocked
	code_input.editable = typing
	code_input.focus_mode = Control.FOCUS_ALL if typing else Control.FOCUS_NONE
	for key: Button in keypad_buttons: key.disabled=not typing
	unlock_button.disabled = not typing
	close_button.text="Enter building [Esc]" if entry_pending else "Back to building [Esc]"
	code_label.text = "Door open" if state.unlocked and state.level==0 else ("Signal received · type the code" if typing else ("Bonus circuit" if state.level>0 else "Waiting for power"))
	if state.level>0: reward_label.text = "COMPLETE" if state.level_cleared else "BONUS %d / 3"%state.level
	elif state.unlocked: reward_label.text = "OPEN"
	elif state.solved:
		var digits: PackedStringArray = []
		for digit: String in state.revealed_code(): digits.append(digit)
		reward_label.text = " ".join(digits)
	else: reward_label.text = "- - - -"
	reward_label.add_theme_color_override("font_color", UI.SUCCESS if state.unlocked and state.level==0 else Tile.POWER)
	_link_focus()
	art.queue_redraw()

## Tab walks only live controls in reading order, so locked or hidden ones never trap focus.
func _link_focus() -> void:
	var order: Array[Control] = []
	order.append_array(tiles)
	order.append_array([hint_button, reset_button, check_button, next_button, replay_button, code_input])
	order.append_array(keypad_buttons)
	order.append_array([unlock_button, close_button])
	var chain: Array[Control] = []
	for control: Control in order:
		var locked: bool = control is BaseButton and control.disabled
		if control is BaseButton: control.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
		var in_console: bool = control == code_input or control == unlock_button or keypad_buttons.has(control)
		if control.visible and not locked and control.focus_mode != Control.FOCUS_NONE and (code_box.visible or not in_console):
			chain.append(control)
	for i: int in range(chain.size()):
		chain[i].focus_next = chain[i].get_path_to(chain[(i + 1) % chain.size()])
		chain[i].focus_previous = chain[i].get_path_to(chain[(i - 1 + chain.size()) % chain.size()])

func _unlock() -> void:
	if state.unlocked: return
	if not state.enter_code(code_input.text):
		GameAudio.play("error")
		code_feedback.text = "That code does not match. Use the code on the door display."
		code_input.select_all()
		code_input.grab_focus()
		code_input.placeholder_text = "Use the code on the display"
		return
	GameAudio.play("unlock")
	celebration_count+=1
	celebration_remaining=0.0 if GamePreferences.reduced_motion else .85
	if replaying:
		code_feedback.text="Practice complete. Nothing is awarded for practice runs."
		feedback.text="Play again, try the bonus circuits, or leave."
	else:
		entrance_unlocked.emit()
		code_feedback.text = "Door unlocked. +1 reserve energy pellet saved for later."
		feedback.text="Choose Enter building when you're ready, or try the optional bonus circuits."
	_sync()
	close_button.grab_focus()

func _keypad_press(value: String) -> void:
	if state.unlocked:return
	if value=="Clear":code_input.text=""
	elif value=="⌫":code_input.text=code_input.text.left(maxi(0,code_input.text.length()-1))
	elif code_input.text.length()<4:code_input.text+=value
	GameAudio.play("menu")

func _process(delta: float) -> void:
	if celebration_remaining>0:
		celebration_remaining=maxf(0,celebration_remaining-delta)
		celebration_art.queue_redraw()

func _draw_panel() -> void:
	art.draw_style_box(theme_source._panel_style(), Rect2(Vector2.ZERO, BASE))
	var enclosure := Rect2(32, 108, 488, 460)
	art.draw_rect(enclosure, Color("29353e"))
	art.draw_rect(enclosure.grow(-3), Color("0b1c22"))
	art.draw_line(enclosure.position, enclosure.position + Vector2(enclosure.size.x, 0), Tile.SHELL, 4, true)
	art.draw_line(enclosure.position + enclosure.size, enclosure.position + Vector2(0, enclosure.size.y), Color("50666f"), 4, true)
	for at: Vector2 in [enclosure.position+Vector2(12,12),enclosure.position+Vector2(476,12),enclosure.position+Vector2(12,448),enclosure.position+Vector2(476,448)]:
		art.draw_circle(at, 4, Tile.SHELL)
		art.draw_line(at-Vector2(2,0),at+Vector2(2,0),Color("29353e"),1)
	var side: float = BOARD.size.y / state.width
	var input := Vector2(49, BOARD.position.y + (state.source / state.width + .5) * side)
	var output := Vector2(506, BOARD.position.y + (state.target / state.width + .5) * side)
	art.draw_line(input, Vector2(BOARD.position.x,input.y), Tile.POWER, 5, true)
	art.draw_line(Vector2(BOARD.end.x,output.y), output, Tile.POWER if state.connected() else Tile.CONDUCTOR, 5, true)
	for at: Vector2 in [input, output]:
		art.draw_circle(at, 12, Color("263843"))
		art.draw_arc(at, 12, 0, TAU, 24, Tile.SHELL, 2, true)
	art.draw_circle(input, 7, Tile.POWER)
	art.draw_circle(output, 7, UI.CYAN if state.level_cleared else Color("a34b45"))
	art.draw_string(ThemeDB.fallback_font, input+Vector2(-9,-21),"IN", HORIZONTAL_ALIGNMENT_LEFT,-1,13,UI.WHITE)
	art.draw_string(ThemeDB.fallback_font, output+Vector2(-13,-21),"OUT", HORIZONTAL_ALIGNMENT_LEFT,-1,13,UI.WHITE)
	# Level pills: cleared levels fill, the current level is outlined.
	for i: int in range(4):
		var pill := Rect2(712 + i * 74, 26, 70, 26)
		var done: bool = state.rewards.size()>i
		var pill_style := StyleBoxFlat.new()
		pill_style.set_corner_radius_all(13)
		pill_style.bg_color = Tile.POWER if done else Color(0,0,0,0)
		pill_style.border_color = UI.CYAN if i==state.level and not done else Color(UI.WHITE,.22)
		pill_style.set_border_width_all(0 if done else 1)
		art.draw_style_box(pill_style, pill)
		art.draw_string(ThemeDB.fallback_font,pill.position+Vector2(0,18),("Entry" if i==0 else "Bonus "+str(i))+(" ✓" if done else ""),HORIZONTAL_ALIGNMENT_CENTER,pill.size.x,13,Color("2a1d05") if done else UI.WHITE)

func _draw_celebration() -> void:
	if celebration_remaining<=0:return
	var elapsed: float=.85-celebration_remaining
	for i in range(30):
		var origin: Vector2=BOARD.get_center()+Vector2((i%5-2)*38,(i/5-2)*32)
		var direction:=Vector2.from_angle(float(i)*2.39996)
		var at: Vector2=origin+direction*elapsed*(110+i%4*25)+Vector2(0,elapsed*elapsed*95)
		celebration_art.draw_rect(Rect2(at,Vector2(8+i%3*3,6)),Color(UI.SUCCESS,celebration_remaining/.85))
