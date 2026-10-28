extends Control
## Compact playtest overlay. The scene owns movement locking and menu input.

signal menu_requested(open: bool)
signal location_requested(index: int)
signal review_mode_requested(enabled: bool)

const NAVY := Color(0.055, 0.082, 0.22, 0.94)
const WHITE := Color(0.90, 0.92, 1.0)
const CYAN := Color(0.21, 0.88, 1.0)
const HINT_SECONDS: float = 5.0
const CONTROLS: String = "Move: WASD / arrow keys\nRun: hold Shift\nLook: move mouse · Zoom: mouse wheel\nSettings / resume: Esc\nEntrance / Elevator / Computer: E nearby\nReset location: R\n\nEntrance: solve the puzzle and enter its code. Take the stairs or right ramp, then continue forward along the hallway. Elevators are on the left.\nUpstairs: turn right toward reception. Classroom double doors are beside the desk. The internal hallway passes two small rooms into the open commons; the restroom corridor is separate."

var floor_label: Label
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
var developer_column: VBoxContainer
var developer_label: Label
var developer_button: Button
var menu_heading: Label
var debug_mode: bool = false
var review_toggle: CheckButton
var review_button: Button
var review_status: Label
var review_panel: PanelContainer
var travel_overlay: ColorRect
var travel_label: Label

func _ready() -> void:
	name = "PlaytestHUD"
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
	title.add_child(_label("PURSUIT · BUILDING PLAYTEST", 18))
	floor_label = _label("Ground Floor", 14)
	title.add_child(floor_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	review_panel = PanelContainer.new()
	review_panel.add_theme_stylebox_override("panel", _panel_style())
	review_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	review_status = _label("BUILDING REVIEW · Entrance bypassed", 14)
	review_panel.add_child(review_status)
	review_panel.hide()
	row.add_child(review_panel)
	settings_button = _button("Settings", false)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings_button.pressed.connect(func(): set_debug_mode(false); menu_requested.emit(true))
	row.add_child(settings_button)
	hint_panel = PanelContainer.new()
	hint_panel.position = Vector2(16, 94)
	hint_panel.custom_minimum_size.y = 98
	hint_panel.add_theme_stylebox_override("panel", _panel_style())
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = _label("WASD / arrows: move · Hold Shift: run\nMouse: look · Wheel: zoom · Esc: settings\nApproach the entrance and press E to unlock it.", 16)
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
	review_button = _button("Review building", false)
	review_button.tooltip_text = "Skip the entrance puzzle for this review session."
	review_button.visible = OS.is_debug_build()
	review_button.pressed.connect(func():
		review_mode_requested.emit(not review_toggle.button_pressed)
		menu_requested.emit(false))
	controls_label = _label(CONTROLS, 16)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.minimum_size_changed.connect(_fit_menu)
	column.add_child(controls_label)
	developer_column = VBoxContainer.new()
	developer_column.add_theme_constant_override("separation", 10)
	column.add_child(developer_column)
	developer_label = _label("", 16)
	developer_column.add_child(developer_label)
	review_toggle = CheckButton.new()
	review_toggle.text = "Bypass entrance puzzle for building review"
	review_toggle.add_theme_font_size_override("font_size", 16)
	review_toggle.add_theme_color_override("font_color", WHITE)
	review_toggle.toggled.connect(func(enabled: bool): review_mode_requested.emit(enabled))
	developer_column.add_child(review_toggle)
	for index in range(3):
		var button := _button(["Entrance [1]", "Reception [2]", "Classroom [3]"][index], false)
		button.pressed.connect(func(): location_requested.emit(index))
		developer_column.add_child(button)
	developer_column.hide()
	developer_button = _button("Developer Tools (F3)", false)
	developer_button.pressed.connect(func(): set_debug_mode(not debug_mode))
	var review_actions := HBoxContainer.new()
	review_actions.add_theme_constant_override("separation", 16)
	column.add_child(review_actions)
	review_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	developer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_actions.add_child(review_button)
	if OS.is_debug_build():
		review_actions.add_child(developer_button)
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

func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled and OS.is_debug_build()
	controls_label.visible = not debug_mode
	review_button.visible = not debug_mode and OS.is_debug_build()
	developer_column.visible = debug_mode
	menu_heading.text = "Developer Tools" if debug_mode else "Settings & Controls"
	developer_button.text = "Back to Controls" if debug_mode else "Developer Tools (F3)"
	menu_panel.call_deferred("reset_size")

func update_debug(feet: Vector3) -> void:
	if debug_mode:
		developer_label.text = "FPS: %d\nPosition: %.2f, %.2f, %.2f\n%s · F3 / Esc: close" % [Engine.get_frames_per_second(), feet.x, feet.y, feet.z, floor_label.text]

func set_review_mode(enabled: bool) -> void:
	review_toggle.set_pressed_no_signal(enabled)
	review_button.text = "Return to play mode" if enabled else "Review building"
	review_status.visible = enabled
	review_panel.visible = enabled
	hint_label.text = "WASD / arrows: move · Hold Shift: run\nMouse: look · Wheel: zoom · Esc: settings\n" + ("Building review: entrance bypassed · F3: developer tools" if enabled else "Approach the entrance and press E to unlock it.")

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
