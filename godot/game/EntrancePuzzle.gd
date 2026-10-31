extends Control
## One required circuit, three optional bonuses and a physical-style code keypad. Rules verify connectivity; this screen presents results.

signal closed
signal entrance_unlocked
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
var moves_label: Label
var info_heading: Label
var instructions: Label
var feedback: Label
var check_button: Button
var hint_button: Button
var reset_button: Button
var edit_row: HBoxContainer
var reward_label: Label
var reward_caption: Label
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
var skip_button: Button

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
	_label("PURSUIT / ENTRY CIRCUIT", Vector2(32, 20), 25)
	_label("Restore the signal. Unlock the entrance.", Vector2(32, 56), 18)
	level_label = _label("", Vector2(776, 22), 20)
	moves_label = _label("", Vector2(776, 58), 16)
	var info := PanelContainer.new()
	info.position = Vector2(548, 108)
	info.size = Vector2(460, 460)
	info.add_theme_stylebox_override("panel", theme_source._panel_style())
	panel.add_child(info)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	info.add_child(column)
	info_heading = _add_label(column, "CONNECT IN TO OUT", 22)
	instructions = _add_label(column, "Click a pipe to rotate it. Join IN to OUT, then choose Test circuit.", 18)
	feedback = _add_label(column, "No time limit. Loose pipes can stay disconnected.", 17)
	feedback.custom_minimum_size.y = 62
	check_button = _button(column, "Test circuit", _test_circuit, true)
	edit_row = HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 12)
	column.add_child(edit_row)
	hint_button = _button(edit_row, "Hint", _show_hint)
	reset_button = _button(edit_row, "Reset level", _reset_level)
	reward_caption = _add_label(column, "TRANSMISSION / WAITING", 14)
	signal_panel = PanelContainer.new()
	var style: StyleBoxFlat = theme_source._panel_style()
	style.bg_color = Color("0b232e")
	style.border_color = Tile.CONDUCTOR
	style.set_border_width_all(1)
	signal_panel.add_theme_stylebox_override("panel", style)
	signal_panel.custom_minimum_size.y = 62
	column.add_child(signal_panel)
	reward_label = _add_label(signal_panel, "• • •", 24)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", Tile.POWER)
	next_button = _button(column, "Next level", _next_level, true)
	code_box = VBoxContainer.new()
	code_box.add_theme_constant_override("separation", 8)
	column.add_child(code_box)
	code_label = _add_label(code_box, "", 22)
	code_input = LineEdit.new()
	code_input.keep_editing_on_text_submit = true
	code_input.placeholder_text = "Enter the 4-digit code"
	code_input.max_length = 4
	code_input.custom_minimum_size.y = 44
	code_input.add_theme_font_size_override("font_size", 20)
	code_input.text_submitted.connect(func(_value: String): _unlock())
	code_box.add_child(code_input)
	keypad=GridContainer.new();keypad.columns=3
	keypad.add_theme_constant_override("h_separation",6);keypad.add_theme_constant_override("v_separation",6)
	code_box.add_child(keypad)
	for value: String in ["1","2","3","4","5","6","7","8","9","Clear","0","⌫"]:
		var key: Button=_button(keypad,value,_keypad_press.bind(value))
		key.custom_minimum_size.y=38;keypad_buttons.append(key)
	unlock_button = _button(code_box, "Unlock entrance", _unlock, true)
	code_feedback = _add_label(code_box, "Enter the displayed code to open the door.", 16)
	close_button = theme_source._button("Back to building [Esc]", false)
	close_button.position = Vector2(734, 580)
	close_button.size = Vector2(274, 42)
	close_button.pressed.connect(close)
	panel.add_child(close_button)
	skip_button = theme_source._button("Skip", false)
	skip_button.position = Vector2(560, 580)
	skip_button.size = Vector2(160, 42)
	skip_button.pressed.connect(_skip)
	panel.add_child(skip_button)
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
	# A CenterContainer keeps the card centred in the window at every size.
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guide.add_child(center)
	guide_panel=PanelContainer.new()
	guide_panel.add_theme_stylebox_override("panel",theme_source._panel_style())
	center.add_child(guide_panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16)
	column.alignment=BoxContainer.ALIGNMENT_CENTER
	guide_panel.add_child(column)
	# The illustrated instruction card replaces the old heading + steps text.
	var art:=TextureRect.new()
	art.texture=load("res://assets/ui/door_guide.png")
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Ignore the texture's native 810px size so the minimum size below is honoured.
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.custom_minimum_size=Vector2(440,440)
	art.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	column.add_child(art)
	guide_button=_button(column,"Connect the first circuit",_start_puzzle,true)
	# Skip straight past the puzzle: open the door and return to the building.
	var guide_skip: Button=_button(column,"Skip — open the door",_skip,false)
	guide_button.focus_next=guide_button.get_path_to(guide_skip)
	guide_button.focus_previous=guide_button.get_path_to(guide_skip)
	guide_skip.focus_next=guide_skip.get_path_to(guide_button)
	guide_skip.focus_previous=guide_skip.get_path_to(guide_button)
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
	parent.add_child(button)
	return button

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
	var focus_controls: Array[Control] = []
	focus_controls.append_array(tiles)
	focus_controls.append_array([check_button, hint_button, reset_button, next_button, code_input])
	focus_controls.append_array(keypad_buttons)
	focus_controls.append_array([unlock_button,close_button])
	for i: int in range(focus_controls.size()):
		var current: Control = focus_controls[i]
		current.focus_next = current.get_path_to(focus_controls[(i + 1) % focus_controls.size()])
		current.focus_previous = current.get_path_to(focus_controls[(i - 1 + focus_controls.size()) % focus_controls.size()])
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

func close() -> void:
	hide()
	closed.emit()

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
	feedback.text = "Signal received. Another part of the message is decoded."
	_sync()
	if state.solved and not state.unlocked: code_input.grab_focus()
	elif next_button.visible: next_button.grab_focus()
	else:close_button.grab_focus()

func _next_level() -> void:
	if not state.unlocked or not state.next_level(): return
	celebration_remaining=0
	celebration_art.queue_redraw()
	_build_tiles()
	instructions.text="Optional bonus circuit. Entry is already unlocked; connect IN to OUT for fun."
	feedback.text = "Hints and retries are free. You can leave whenever you like."
	_sync()
	tiles[state.source].grab_focus()

func _sync() -> void:
	level_label.text = "ENTRY CIRCUIT" if state.level==0 else "OPTIONAL BONUS %d / 3"%state.level
	moves_label.text = "%02d TURNS" % state.moves
	moves_label.tooltip_text = state.BOARDS[state.level].name
	var powered: Array = state.reachable_tiles()
	for i: int in range(tiles.size()):
		tiles[i].mask = state.masks[i]
		tiles[i].powered = i in powered
		tiles[i].disabled = state.level_cleared or guide.visible
		tiles[i].tooltip_text = "Row %d, column %d: %s. Activate to rotate clockwise." % [i / state.width + 1, i % state.width + 1, state.ports_text(state.masks[i])]
	check_button.disabled=guide.visible
	hint_button.disabled=guide.visible
	reset_button.disabled=guide.visible
	check_button.visible = not state.level_cleared
	edit_row.visible = not state.level_cleared
	next_button.visible = state.unlocked and state.level_cleared and state.level<state.BOARDS.size()-1
	next_button.text="Play optional bonus %d / 3"%(state.level+1)
	code_box.visible = state.solved and not state.unlocked
	instructions.visible = not code_box.visible
	feedback.visible = not code_box.visible
	signal_panel.visible=not code_box.visible
	reward_caption.visible=not code_box.visible
	check_button.visible=not state.level_cleared
	edit_row.visible=not state.level_cleared
	close_button.text="Enter building [Esc]" if state.unlocked else "Back to building [Esc]"
	info_heading.text = "ENTER FOUR-DIGIT CODE" if code_box.visible else ("ENTRANCE UNLOCKED" if state.unlocked else "CONNECT IN TO OUT")
	reward_caption.text = "ENTRY COMPLETE · BONUSES OPTIONAL" if state.unlocked and state.level==0 else "OPTIONAL BONUS %d / 3"%state.level if state.level>0 else "SIGNAL / WAITING"
	reward_label.text = ("Welcome to Pursuit" if state.level==0 else "Bonus circuit complete" if state.level_cleared else "Connect IN to OUT") if state.solved else "• • •"
	code_label.text = "Entry code: " + state.revealed_code() if state.solved else ""
	code_input.editable = not state.unlocked
	for key: Button in keypad_buttons:key.disabled=state.unlocked
	unlock_button.disabled = state.unlocked
	art.queue_redraw()

## Skip the circuit entirely: unlock the entrance and return to the building.
func _skip() -> void:
	if not state.unlocked:
		state.force_complete()   # completed + unlocked so the gate accepts the unlock
		GameAudio.play("unlock")
		entrance_unlocked.emit()
	close()

func _unlock() -> void:
	if state.unlocked: return
	if not state.enter_code(code_input.text):
		GameAudio.play("error")
		code_feedback.text = "That code does not match. Use the entry code shown above."
		code_input.select_all()
		code_input.grab_focus()
		code_input.placeholder_text = "Use the entry code shown above"
		return
	GameAudio.play("unlock")
	celebration_count+=1
	celebration_remaining=0.0 if GamePreferences.reduced_motion else .85
	entrance_unlocked.emit()
	code_feedback.text = "Door unlocked. +1 reserve energy pellet."
	instructions.text="Walk through the entrance, or try the optional bonus circuits."
	feedback.text="+1 reserve energy pellet saved for later. Bonus puzzles are just for fun."
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
	for i: int in range(4):
		var at := Vector2(612 + i * 94, 89)
		art.draw_line(at, at+Vector2(68,0),(Tile.POWER if i==0 else UI.CYAN) if state.rewards.size()>i else Color(UI.WHITE,.16),4,true)
		art.draw_string(ThemeDB.fallback_font,at+Vector2(0,14),"ENTRY" if i==0 else "BONUS "+str(i),HORIZONTAL_ALIGNMENT_LEFT,-1,10,UI.WHITE)

func _draw_celebration() -> void:
	if celebration_remaining<=0:return
	var elapsed: float=.85-celebration_remaining
	for i in range(30):
		var origin: Vector2=BOARD.get_center()+Vector2((i%5-2)*38,(i/5-2)*32)
		var direction:=Vector2.from_angle(float(i)*2.39996)
		var at: Vector2=origin+direction*elapsed*(110+i%4*25)+Vector2(0,elapsed*elapsed*95)
		celebration_art.draw_rect(Rect2(at,Vector2(8+i%3*3,6)),Color(UI.SUCCESS,celebration_remaining/.85))
