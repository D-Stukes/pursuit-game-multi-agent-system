extends RefCounted
## Debug-only UI. The normal game does not load this script in player-only mode.
signal location_requested(index: int)
signal review_requested(enabled: bool)
signal skip_requested(gate: String)
signal view_changed
signal sample_course_requested
signal ending_preview_requested
signal intro_preview_requested
const SECTION_GAP: int=12
const ROW_GAP: int=8
const SMALL_FONT: int=15
const SMALL_HEIGHT: float=36.0
const INSET := Color(0.02, 0.035, 0.11, 0.9)
var active: bool=false
var controls: VBoxContainer
var entry_button: Button
var stats_label: Label
var bypass_toggle: CheckButton
var banner_panel: PanelContainer
var banner_label: Label
var travel_buttons: Array[Button]=[]
var intro_preview_button: Button
var sample_course_button: Button
var ending_preview_button: Button

func build_banner(row: HBoxContainer, theme_source: Control) -> void:
	banner_panel=PanelContainer.new()
	banner_panel.add_theme_stylebox_override("panel",theme_source._panel_style())
	banner_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	banner_label=theme_source._label("DEVELOPER REVIEW · Puzzle gates bypassed",14)
	banner_panel.add_child(banner_label);row.add_child(banner_panel)
	banner_panel.hide()

func build_menu(column: VBoxContainer, theme_source: Control) -> void:
	controls=VBoxContainer.new()
	controls.add_theme_constant_override("separation",SECTION_GAP)
	column.add_child(controls)
	var readout:=PanelContainer.new()
	var inset: StyleBoxFlat=theme_source._panel_style()
	inset.bg_color=INSET;inset.content_margin_top=8;inset.content_margin_bottom=8
	readout.add_theme_stylebox_override("panel",inset)
	stats_label=theme_source._label("",14);readout.add_child(stats_label)
	controls.add_child(readout)
	var gates: VBoxContainer=_section(theme_source,"GATES")
	bypass_toggle=CheckButton.new()
	bypass_toggle.text="Free exploration"
	bypass_toggle.tooltip_text="Temporarily opens both gates. Use the skip buttons below to play games independently."
	bypass_toggle.add_theme_font_size_override("font_size",SMALL_FONT)
	bypass_toggle.add_theme_color_override("font_color",theme_source.WHITE)
	var ring: StyleBoxFlat=theme_source._panel_style()
	ring.draw_center=false;ring.border_color=theme_source.WHITE;ring.set_border_width_all(2)
	bypass_toggle.add_theme_stylebox_override("focus",ring)
	bypass_toggle.toggled.connect(func(enabled: bool):review_requested.emit(enabled))
	gates.add_child(bypass_toggle)
	var skips: HBoxContainer=_row(gates)
	for gate: String in ["entrance","elevator"]:
		var skip: Button=_small_button(theme_source,skips,"Skip entrance" if gate=="entrance" else "Skip shooter")
		skip.tooltip_text=("Opens the entrance so you can play the shooter next." if gate=="entrance" else "Unlocks the elevator ride upstairs while the entrance puzzle stays playable.")+"\nNo win, energy or score is awarded. Turning free exploration off does not undo this skip. Restart Run clears skips."
		skip.pressed.connect(func():skip_requested.emit(gate))
	var travel: HBoxContainer=_row(_section(theme_source,"TRAVEL"))
	for index: int in range(3):
		var button: Button=_small_button(theme_source,travel,["Entrance  1","Reception  2","Classroom  3"][index])
		button.tooltip_text="Move here now. Number keys 1–3 also work while free exploration is on."
		button.pressed.connect(func():location_requested.emit(index))
		travel_buttons.append(button)
	var previews: VBoxContainer=_section(theme_source,"PREVIEWS")
	var shows: HBoxContainer=_row(previews)
	intro_preview_button=_small_button(theme_source,shows,"Intro panorama")
	intro_preview_button.tooltip_text="Play the opening street panorama and introduction text. Esc or Skip returns to your original view."
	intro_preview_button.pressed.connect(func():intro_preview_requested.emit())
	ending_preview_button=_small_button(theme_source,shows,"Ending")
	ending_preview_button.tooltip_text="Play the classroom / L3 story presentation without changing progress. Escape returns to your original view."
	ending_preview_button.pressed.connect(func():ending_preview_requested.emit())
	sample_course_button=_small_button(theme_source,previews,"Sample course (temporary)")
	sample_course_button.tooltip_text="Complete check-in and the classroom introduction, then enter the purple world with bypass off."
	sample_course_button.disabled=true
	sample_course_button.pressed.connect(func():sample_course_requested.emit())
	controls.hide()
	entry_button=theme_source._button("Developer Tools",false)
	entry_button.tooltip_text="Developer controls (F3). Bypass and travel never earn progress."
	entry_button.pressed.connect(func():set_active(not active))
	column.add_child(entry_button)

func _section(theme_source: Control, title: String) -> VBoxContainer:
	var section:=VBoxContainer.new()
	section.add_theme_constant_override("separation",ROW_GAP)
	var heading: Label=theme_source._label(title,12)
	heading.add_theme_color_override("font_color",theme_source.CYAN)
	section.add_child(heading)
	controls.add_child(section)
	return section

func _row(parent: Container) -> HBoxContainer:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",ROW_GAP)
	parent.add_child(row)
	return row

func _small_button(theme_source: Control, parent: Container, text: String) -> Button:
	var button: Button=theme_source._button(text,false)
	button.custom_minimum_size=Vector2(0,SMALL_HEIGHT)
	button.add_theme_font_size_override("font_size",SMALL_FONT)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.clip_text=true
	var muted: StyleBoxFlat=theme_source._panel_style()
	muted.border_color=Color(theme_source.CYAN,.25);muted.set_border_width_all(1)
	button.add_theme_stylebox_override("disabled",muted)
	button.add_theme_color_override("font_disabled_color",Color(theme_source.WHITE,.4))
	parent.add_child(button)
	return button

func set_active(enabled: bool) -> void:
	active=enabled
	controls.visible=active
	entry_button.text="Back to Controls" if active else "Developer Tools"
	view_changed.emit()

func set_bypass(enabled: bool) -> void:
	bypass_toggle.set_pressed_no_signal(enabled)
	banner_panel.visible=enabled
	banner_label.visible=enabled

func update_readout(feet: Vector3, floor_name: String) -> void:
	if active:
		stats_label.text="FPS: %d · %s · F3 to close\nPosition: %.2f, %.2f, %.2f"%[Engine.get_frames_per_second(),floor_name,feet.x,feet.y,feet.z]
