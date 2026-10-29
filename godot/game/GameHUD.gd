extends Control
## Game overlay. The scene owns movement locking and menu input.

signal menu_requested(open: bool)

const NAVY := Color(0.055, 0.082, 0.22, 0.94)
const WHITE := Color(0.90, 0.92, 1.0)
const CYAN := Color(0.21, 0.88, 1.0)
const HINT_SECONDS: float = 5.0
const CONTROLS: String = "Move: WASD / arrow keys\nRun: hold Shift\nLook: move mouse · Zoom: mouse wheel\nSettings / resume: Esc\nEntrance / Elevator / Computer: E nearby\nReset location: R\n\nEntrance: use the keypad to the left of the door, solve the puzzle and enter its code. Take the stairs or right ramp, then continue forward along the hallway. Elevators are on the left.\nUpstairs: turn right toward reception. Classroom double doors are beside the desk. The internal hallway passes two small rooms into the open commons; the restroom corridor is separate."

var floor_label: Label
var objective_label: Label
var settings_button: Button
var hint_panel: PanelContainer
var hint_label: Label
var hint_timer: Timer
var prompt_label: Label
var menu_overlay: ColorRect
var menu_panel: PanelContainer
var resume_button: Button
var controls_label: Label
var menu_open: bool = false
var menu_heading: Label
var developer: RefCounted
var developer_tools_allowed: bool=true
var debug_mode: bool:
	get: return developer != null and developer.active
var travel_overlay: ColorRect
var travel_label: Label

func _ready() -> void:
	name = "GameHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", _panel_style())
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_panel)
	var title := VBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title)
	title.add_child(_label("PURSUIT · THE JOURNEY", 18))
	floor_label = _label("Ground Floor", 14)
	title.add_child(floor_label)
	objective_label = _label("Next: Unlock the entrance",14)
	title.add_child(objective_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	if developer_tools_allowed and OS.is_debug_build():
		developer=load("res://developer/DeveloperTools.gd").new()
		developer.build_banner(row,self)
	settings_button = _button("Settings", false)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings_button.pressed.connect(func(): set_debug_mode(false); menu_requested.emit(true))
	row.add_child(settings_button)
	hint_panel = PanelContainer.new()
	hint_panel.position = Vector2(16, 120)
	hint_panel.custom_minimum_size.y = 98
	hint_panel.add_theme_stylebox_override("panel", _panel_style())
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = _label("WASD / arrows: move · Hold Shift: run\nMouse: look · Wheel: zoom · Esc: settings\nUse the keypad left of the entrance: approach it and press E.", 16)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.minimum_size_changed.connect(func(): call_deferred("_fit_hint"))
	hint_panel.add_child(hint_label)
	add_child(hint_panel)
	hint_timer = Timer.new()
	hint_timer.one_shot = true
	hint_timer.wait_time = HINT_SECONDS
	hint_timer.timeout.connect(func(): hint_panel.hide())
	add_child(hint_timer)
	hint_panel.hide()
	call_deferred("_show_initial_hint")
	prompt_label = _label("", 18)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_left = 16
	prompt_label.offset_right = -16
	prompt_label.offset_top = -44
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)
	travel_overlay = ColorRect.new()
	travel_overlay.color = Color(0, 0, 0, 0)
	travel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(travel_overlay)
	travel_label = _label("", 22)
	travel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	travel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	travel_overlay.add_child(travel_label)
	travel_overlay.hide()
	_build_menu()
	resized.connect(_fit_layout)
	_fit_layout()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NAVY
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 42)
	button.add_theme_font_size_override("font_size", 18)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := _panel_style()
		style.bg_color = CYAN if primary else NAVY
		style.border_color = WHITE if state == "focus" else CYAN
		style.set_border_width_all(2 if state in ["hover", "focus"] else 1)
		button.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, NAVY if primary else WHITE)
	return button

func _build_menu() -> void:
	menu_overlay = ColorRect.new()
	menu_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_overlay)
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _panel_style())
	menu_overlay.add_child(menu_panel)
	menu_panel.resized.connect(_center_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	menu_panel.add_child(column)
	menu_heading = _label("Settings & Controls", 22)
	column.add_child(menu_heading)
	controls_label = _label(CONTROLS, 16)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.minimum_size_changed.connect(_fit_menu)
	column.add_child(controls_label)
	if developer != null:
		developer.build_menu(column,self)
		developer.view_changed.connect(_sync_menu)
	resume_button = _button("Resume", true)
	resume_button.pressed.connect(func(): menu_requested.emit(false))
	column.add_child(resume_button)
	menu_overlay.hide()

func _fit_layout() -> void:
	if not is_instance_valid(menu_panel):
		return
	hint_panel.size.x = minf(590.0, size.x - 32.0)
	hint_label.custom_minimum_size.x = hint_panel.size.x - 32.0
	menu_panel.custom_minimum_size.x = minf(530.0, size.x - 48.0)
	controls_label.custom_minimum_size.x = menu_panel.custom_minimum_size.x - 32.0
	_fit_hint()
	_fit_menu()

func _fit_hint() -> void:
	# Wrapped text briefly reports a tall minimum before its width is assigned.
	# Release that stale height when shaping finishes, rather than retaining it.
	if is_instance_valid(hint_panel):
		hint_panel.size.y = hint_panel.get_combined_minimum_size().y

func _show_initial_hint() -> void:
	await get_tree().process_frame
	_fit_hint()
	hint_panel.show()
	await get_tree().process_frame
	_fit_hint()
	hint_timer.start()

func _fit_menu() -> void:
	if not is_instance_valid(menu_panel):
		return
	menu_panel.reset_size()
	_center_menu()

func _center_menu() -> void:
	menu_panel.position = (size - menu_panel.size) / 2.0

func _sync_menu() -> void:
	controls_label.visible=not debug_mode
	menu_heading.text="Developer Tools" if debug_mode else "Settings & Controls"
	menu_panel.call_deferred("reset_size")

func set_debug_mode(enabled: bool) -> void:
	if developer != null: developer.set_active(enabled)
	_sync_menu()

func update_debug(feet: Vector3) -> void:
	if developer != null: developer.update_readout(feet,floor_label.text)

func set_review_mode(enabled: bool) -> void:
	if developer != null: developer.set_bypass(enabled)
	hint_label.text="WASD / arrows: move · Hold Shift: run\nMouse: look · Wheel: zoom · Esc: settings\n"+("Developer review: puzzle gates bypassed · F3: developer tools" if enabled else "Follow the current objective. Entrance: E at the keypad left of the door.")

func set_objective(objective: String) -> void:
	var next: String = "Next: "+objective
	if objective_label.text != next: objective_label.text = next

func set_travel_opacity(opacity: float) -> void:
	travel_overlay.color.a = clampf(opacity, 0.0, 1.0)

func set_menu_open(open: bool) -> void:
	menu_open = open
	menu_overlay.visible = open
	if open:
		resume_button.grab_focus()
	else:
		resume_button.release_focus()
		settings_button.release_focus()

func update_location(upper: bool, near_lift: bool) -> void:
	floor_label.text = "Second Floor" if upper else "Ground Floor"
	prompt_label.text = "E: use elevator" if near_lift and not menu_open else ""
