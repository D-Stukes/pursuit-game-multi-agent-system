extends RefCounted
## Debug-only UI. The normal game does not load this script in player-only mode.
signal location_requested(index: int)
signal review_requested(enabled: bool)
signal skip_requested(gate: String)
signal view_changed
signal sample_course_requested
signal ending_preview_requested
var active: bool=false
var controls: VBoxContainer
var entry_button: Button
var stats_label: Label
var bypass_toggle: CheckButton
var banner_panel: PanelContainer
var banner_label: Label
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
	controls.add_theme_constant_override("separation",10)
	column.add_child(controls)
	stats_label=theme_source._label("",16);controls.add_child(stats_label)
	bypass_toggle=CheckButton.new()
	bypass_toggle.text="Free exploration (temporary)"
	bypass_toggle.tooltip_text="Temporarily opens both gates. Use the skip buttons below to play games independently."
	bypass_toggle.add_theme_font_size_override("font_size",16)
	bypass_toggle.add_theme_color_override("font_color",theme_source.WHITE)
	bypass_toggle.toggled.connect(func(enabled: bool):review_requested.emit(enabled))
	controls.add_child(bypass_toggle)
	for gate: String in ["entrance","elevator"]:
		var skip: Button=theme_source._button("Skip entrance → play shooter" if gate=="entrance" else "Skip shooter (keep entrance playable)",false)
		skip.tooltip_text="Skip this gate for the current run. No win, energy or score is awarded. Turning free exploration off does not undo this skip. Restart Run clears skips."
		skip.pressed.connect(func():skip_requested.emit(gate))
		controls.add_child(skip)
	for index: int in range(3):
		var button: Button=theme_source._button(["Entrance [1]","Reception [2]","Classroom [3]"][index],false)
		button.pressed.connect(func():location_requested.emit(index));controls.add_child(button)
	sample_course_button=theme_source._button("Sample course (temporary)",false)
	sample_course_button.tooltip_text="Complete check-in and the classroom introduction, then enter the purple world with bypass off."
	sample_course_button.disabled=true
	sample_course_button.pressed.connect(func():sample_course_requested.emit())
	controls.add_child(sample_course_button)
	ending_preview_button=theme_source._button("Preview Ending",false)
	ending_preview_button.tooltip_text="Play the classroom / L3 story presentation without changing progress. Escape returns to your original view."
	ending_preview_button.pressed.connect(func():ending_preview_requested.emit())
	controls.add_child(ending_preview_button)
	controls.hide()
	entry_button=theme_source._button("Developer Tools",false)
	entry_button.tooltip_text="Developer controls (F3). Bypass and travel never earn progress."
	entry_button.pressed.connect(func():set_active(not active))
	column.add_child(entry_button)

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
		stats_label.text="FPS: %d\nPosition: %.2f, %.2f, %.2f\n%s · F3 / Esc: close"%[Engine.get_frames_per_second(),feet.x,feet.y,feet.z,floor_name]
