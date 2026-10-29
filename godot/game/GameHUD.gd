extends Control
## Game overlay. The scene owns movement locking and menu input.

signal menu_requested(open: bool)
signal restart_confirmed

const NAVY := Color(0.055, 0.082, 0.22, 0.94)
const WHITE := Color(0.90, 0.92, 1.0)
const CYAN := Color(0.21, 0.88, 1.0)
const SUCCESS := Color("78e6a8")
const ERROR := Color("ff8f9c")
const HINT_SECONDS: float = 5.0
const CONTROLS: String = "Move: WASD / arrow keys\nRun: hold Shift\nLook: move mouse\nZoom: mouse wheel\nSit / stand: C\nInteract: E nearby\nPause / resume: Esc\nReset location: R"
const HUD_WIDTH: float = 300.0
const STATUS_WIDTH: float = 240.0
const MENU_WIDTH: float = 340.0
const PAGE_WIDTH: float = 440.0
const EDGE: float = 24.0
const GAP: int = 12
var menu_page: String = "home"
var menu_actions: Array[Button] = []
var back_button: Button
var display_button: Button
var menu_objective: Label
var menu_scroll: ScrollContainer
var status_panel: PanelContainer
var compact_status: bool = true
var audio_controls: VBoxContainer
var window_button: Button


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
var restart_button: Button
var restart_overlay: ColorRect
var restart_panel: PanelContainer
var restart_cancel: Button
var restart_accept: Button
var restart_dialog_open: bool = false
var controls_label: Label
var menu_open: bool = false
var menu_heading: Label
var developer: RefCounted
var developer_tools_allowed: bool=true
var debug_mode: bool:
	get: return developer != null and developer.active
var travel_overlay: ColorRect
var travel_label: Label
var title_panel: PanelContainer
var header_row: HBoxContainer
var progress_display: VBoxContainer

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
	header_row=row
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	title_panel = PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", _panel_style())
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_panel)
	var title := VBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title)
	title.add_child(_label("CURRENT OBJECTIVE", 12))
	floor_label = _label("Ground Floor", 14)
	floor_label.hide()
	title.add_child(floor_label)
	objective_label = _label("Unlock the entrance",18)
	objective_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.add_child(objective_label)
	progress_display=preload("res://game/ProgressHUD.gd").new()
	progress_display.theme_source=self
	status_panel=PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel",_panel_style())
	status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_panel.offset_left=EDGE
	status_panel.offset_top=-100
	status_panel.add_child(progress_display)
	add_child(status_panel)
	progress_display.minimum_size_changed.connect(func():call_deferred("_fit_status"))
	title_panel.resized.connect(_fit_hint_position)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	if developer_tools_allowed and OS.is_debug_build():
		developer=load("res://developer/DeveloperTools.gd").new()
		developer.build_banner(row,self)
	settings_button = _button("Esc  Pause", false)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings_button.pressed.connect(func(): set_debug_mode(false); menu_requested.emit(true))
	row.add_child(settings_button)
	hint_panel = PanelContainer.new()
	hint_panel.position = Vector2(16, 120)
	hint_panel.custom_minimum_size.y = 0
	hint_panel.add_theme_stylebox_override("panel", _panel_style())
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = _label("Approach the keypad left of the entrance and press E.\nEsc opens controls and help.", 16)
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
	style.set_corner_radius_all(6)
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
	button.pressed.connect(func():GameAudio.play("menu"))
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
	menu_scroll=ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	menu_panel.add_child(menu_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", GAP)
	menu_scroll.add_child(column)
	column.add_child(_label("PURSUIT: THE JOURNEY",12))
	menu_heading = _label("Paused", 28)
	column.add_child(menu_heading)
	menu_objective=_label("Unlock the entrance",16)
	menu_objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(menu_objective)
	controls_label = _label(CONTROLS, 16)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.minimum_size_changed.connect(_fit_menu)
	column.add_child(controls_label)
	resume_button = _button("Resume", true)
	resume_button.pressed.connect(func(): menu_requested.emit(false))
	column.add_child(resume_button)
	menu_actions.append(resume_button)
	for page: String in ["Controls","Help & objective","Display","Audio"]:
		var button: Button = _button(page,false)
		button.pressed.connect(func():_show_page(page))
		column.add_child(button)
		menu_actions.append(button)
	display_button=_button("HUD: Compact",false)
	display_button.pressed.connect(func():
		compact_status=not compact_status
		progress_display.set_compact(compact_status)
		display_button.text="HUD: Compact" if compact_status else "HUD: Expanded"
		_fit_status())
	column.add_child(display_button)
	window_button=_button("Window: 1280 × 720" if get_window().size.x>=1600 else "Larger window: 1600 × 900",false)
	window_button.pressed.connect(func():
		var window: Window=get_window()
		var target:=Vector2i(1600,900) if window.size.x<1600 else Vector2i(1280,720)
		var usable: Rect2i=DisplayServer.screen_get_usable_rect(window.current_screen)
		target=target.min(usable.size-Vector2i(48,64))
		window.size=target
		window.position=usable.position+(usable.size-target)/2
		window_button.text="Window: 1280 × 720" if target.x>=1600 else "Larger window: 1600 × 900")
	column.add_child(window_button)
	audio_controls=VBoxContainer.new()
	audio_controls.add_theme_constant_override("separation",GAP)
	column.add_child(audio_controls)
	for bus: String in ["Master","Music","Effects"]:
		var volume_label: Label=_label("",16)
		audio_controls.add_child(volume_label)
		var slider:=HSlider.new()
		slider.min_value=0;slider.max_value=100;slider.step=1
		slider.value=float(GameAudio.levels[bus])*100
		slider.custom_minimum_size.y=32
		var track:=StyleBoxFlat.new();track.bg_color=NAVY;track.set_content_margin_all(3)
		slider.add_theme_stylebox_override("slider",track)
		var filled: StyleBoxFlat=track.duplicate();filled.bg_color=CYAN
		slider.add_theme_stylebox_override("grabber_area",filled)
		slider.add_theme_stylebox_override("grabber_area_highlight",filled)
		slider.tooltip_text=bus+" volume; zero mutes"
		slider.value_changed.connect(func(value: float):
			GameAudio.set_volume(bus,value/100.0)
			volume_label.text=("Sound effects" if bus=="Effects" else bus)+": %d%%"%int(value))
		volume_label.text=("Sound effects" if bus=="Effects" else bus)+": %d%%"%int(slider.value)
		audio_controls.add_child(slider)
	var credit:=RichTextLabel.new()
	credit.bbcode_enabled=true
	credit.fit_content=true
	credit.scroll_active=false
	credit.add_theme_color_override("default_color",WHITE)
	credit.add_theme_font_size_override("normal_font_size",14)
	credit.text="Music: [url=https://www.scottbuckley.com.au/library/hymn/]Hymn[/url] by [url=https://www.scottbuckley.com.au]Scott Buckley[/url]\nReleased under [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url]"
	credit.meta_clicked.connect(func(url: Variant):
		if str(url) in ["https://www.scottbuckley.com.au/library/hymn/","https://www.scottbuckley.com.au","https://creativecommons.org/licenses/by/4.0/"]: OS.shell_open(str(url)))
	audio_controls.add_child(credit)
	if developer != null:
		developer.build_menu(column,self)
		developer.view_changed.connect(_sync_menu)
	restart_button=_button("Restart Run",false)
	restart_button.pressed.connect(show_restart_confirmation)
	column.add_child(HSeparator.new())
	column.add_child(restart_button)
	menu_actions.append(restart_button)
	back_button=_button("Back to menu",false)
	back_button.pressed.connect(func():_show_page("home"))
	column.add_child(back_button)
	_sync_menu()
	_build_restart_confirmation()
	menu_overlay.hide()

func _build_restart_confirmation() -> void:
	restart_overlay=ColorRect.new()
	restart_overlay.color=Color(0,0,0,.8)
	restart_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.add_child(restart_overlay)
	restart_panel=PanelContainer.new()
	restart_panel.add_theme_stylebox_override("panel",_panel_style())
	restart_overlay.add_child(restart_panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	restart_panel.add_child(column)
	column.add_child(_label("Restart this run?",22))
	var message:=_label("This clears puzzle progress, energy, score and conversations. You will start outside again. Progress is kept only for this run.",16)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x=340
	column.add_child(message)
	var actions:=HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	column.add_child(actions)
	restart_cancel=_button("Cancel",true)
	restart_accept=_button("Restart Run",false)
	for button: Button in [restart_cancel,restart_accept]:
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	restart_cancel.pressed.connect(cancel_restart_confirmation)
	restart_accept.pressed.connect(func(): restart_accept.disabled=true; restart_confirmed.emit())
	restart_cancel.focus_next=restart_cancel.get_path_to(restart_accept)
	restart_cancel.focus_previous=restart_cancel.focus_next
	restart_accept.focus_next=restart_accept.get_path_to(restart_cancel)
	restart_accept.focus_previous=restart_accept.focus_next
	restart_panel.resized.connect(func():restart_panel.position=(size-restart_panel.size)/2)
	restart_overlay.hide()

func show_restart_confirmation() -> void:
	if not menu_open: return
	restart_dialog_open=true
	restart_accept.disabled=false
	menu_panel.hide()
	restart_overlay.show()
	restart_panel.reset_size()
	restart_panel.position=(size-restart_panel.size)/2
	restart_cancel.grab_focus()

func cancel_restart_confirmation() -> void:
	restart_dialog_open=false
	restart_overlay.hide()
	menu_panel.show()
	if menu_open: restart_button.grab_focus()

func _fit_layout() -> void:
	if not is_instance_valid(menu_panel):
		return
	_fit_header()
	hint_panel.size.x = minf(590.0, size.x - 32.0)
	hint_label.custom_minimum_size.x = hint_panel.size.x - 32.0
	menu_panel.custom_minimum_size.x = minf(MENU_WIDTH if menu_page=="home" and not debug_mode else PAGE_WIDTH, size.x - EDGE*2)
	controls_label.custom_minimum_size.x = menu_panel.custom_minimum_size.x - 48.0
	menu_objective.custom_minimum_size.x=controls_label.custom_minimum_size.x
	menu_scroll.custom_minimum_size=Vector2(controls_label.custom_minimum_size.x,minf(menu_scroll.get_child(0).get_combined_minimum_size().y,size.y-EDGE*2-24))
	menu_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_fit_status()
	_fit_hint()
	_fit_menu()
	if is_instance_valid(restart_panel): restart_panel.position=(size-restart_panel.size)/2

func _fit_header() -> void:
	var separation: float = header_row.get_theme_constant("separation")
	var reserved: float = settings_button.get_combined_minimum_size().x+separation*2
	if developer!=null and developer.banner_panel.visible:
		reserved+=developer.banner_panel.get_combined_minimum_size().x+separation
	title_panel.custom_minimum_size.x=minf(HUD_WIDTH,maxf(0,size.x-32-reserved))
	call_deferred("_fit_hint_position")

func _fit_hint_position() -> void:
	if is_instance_valid(hint_panel): hint_panel.position.y=title_panel.get_global_rect().end.y-global_position.y+12

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
	menu_panel.position = Vector2(EDGE,maxf(EDGE,(size.y-menu_panel.size.y)/2.0))

func _show_page(page: String) -> void:
	menu_page=page
	_sync_menu()
	if page=="home": resume_button.grab_focus()
	else: back_button.grab_focus()

func _sync_menu() -> void:
	if not is_instance_valid(back_button): return
	var home: bool = menu_page=="home" and not debug_mode
	for button: Button in menu_actions: button.visible=home
	menu_objective.visible=home
	controls_label.visible=not home and not debug_mode
	display_button.visible=menu_page=="Display" and not debug_mode
	window_button.visible=display_button.visible
	audio_controls.visible=menu_page=="Audio" and not debug_mode
	back_button.visible=not home and not debug_mode
	if developer!=null:
		developer.entry_button.visible=home or debug_mode
		developer.entry_button.text="Back to menu" if debug_mode else "Developer Tools"
	menu_heading.text="Developer Tools" if debug_mode else ("Paused" if home else menu_page)
	if menu_page=="Controls": controls_label.text=CONTROLS
	elif menu_page=="Help & objective": controls_label.text=_objective_help()
	elif menu_page=="Audio": controls_label.text="Adjust music and effects separately. Zero mutes a channel. Your volume settings are saved on this device."
	elif menu_page=="Display": controls_label.text="Compact keeps energy visible and shows score and activities when the course begins. Expanded always shows all progress details."
	call_deferred("_fit_layout")

func _objective_help() -> String:
	var objective: String = objective_label.text
	var help: String = "Follow the current objective. Approach an object or character and press E when its prompt appears."
	if "entrance" in objective.to_lower(): help="Use the keypad left of the entrance. Rotate pipes and connect IN to OUT on all four boards. Test each circuit, then enter the revealed code to unlock the door. Hints and retries cost no energy."
	elif "elevator" in objective.to_lower(): help="Take the stairs or right ramp, then follow the hallway to the elevators on the left. Press E at the lower cab. Clear three shooter waves, then choose Ride upstairs. WASD moves, Space shoots, P pauses."
	elif "check" in objective.to_lower(): help="Upstairs, turn right toward reception. Use the Check-In Console, enter your name, take the simulated avatar photo and confirm check-in."
	elif "classroom" in objective.to_lower() and "computer" not in objective.to_lower(): help="The classroom double doors are beside reception. Enter the classroom or choose Continue to classroom on your check-in receipt. Listen to the Program Manager's introduction."
	elif "computer" in objective.to_lower() or "mr. p" in objective.to_lower(): help="Approach a classroom computer and press E to visit the purple world. Its return pad takes you back to the same computer. Mr. P's real course is not connected yet."
	return objective+"\n\n"+help

func _fit_status() -> void:
	if not is_instance_valid(status_panel): return
	status_panel.custom_minimum_size.x=minf(STATUS_WIDTH,size.x-EDGE*2)
	progress_display.metrics.custom_minimum_size.x=status_panel.custom_minimum_size.x-32
	progress_display.activity.custom_minimum_size.x=status_panel.custom_minimum_size.x-32
	status_panel.size.x=status_panel.custom_minimum_size.x
	status_panel.reset_size()
	status_panel.position=Vector2(EDGE,size.y-status_panel.size.y-EDGE)

func set_debug_mode(enabled: bool) -> void:
	if developer != null: developer.set_active(enabled)
	_sync_menu()

func update_debug(feet: Vector3) -> void:
	if developer != null: developer.update_readout(feet,floor_label.text)

func set_review_mode(enabled: bool) -> void:
	if developer != null: developer.set_bypass(enabled)
	_fit_header()
	hint_label.text="WASD / arrows: move · Hold Shift: run\nMouse: look · Wheel: zoom · Esc: settings\n"+("Developer review: puzzle gates bypassed · F3: developer tools" if enabled else "Follow the current objective. Entrance: E at the keypad left of the door.")

func set_objective(objective: String) -> void:
	var next: String = objective
	if objective_label.text != next: objective_label.text = next
	menu_objective.text=objective

func set_progress(snapshot: Dictionary) -> void:
	progress_display.apply_snapshot(snapshot)

func set_travel_opacity(opacity: float) -> void:
	travel_overlay.color.a = clampf(opacity, 0.0, 1.0)

func set_menu_open(open: bool) -> void:
	if not open and restart_dialog_open: cancel_restart_confirmation()
	menu_open = open
	menu_overlay.visible = open
	GameAudio.set_menu_open(open)
	header_row.visible=not open
	status_panel.visible=not open
	prompt_label.visible=not open
	if open:
		hint_panel.hide()
		menu_page="home"
		_sync_menu()
	if open:
		if debug_mode: developer.bypass_toggle.grab_focus()
		else: resume_button.grab_focus()
	else:
		resume_button.release_focus()
		settings_button.release_focus()

func update_location(upper: bool, near_lift: bool) -> void:
	floor_label.text = "Second Floor" if upper else "Ground Floor"
	prompt_label.text = "E: use elevator" if near_lift and not menu_open else ""
