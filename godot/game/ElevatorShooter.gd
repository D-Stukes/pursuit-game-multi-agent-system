extends Control
## A lightweight drawn arcade screen; one shared local rule state survives closing.

signal closed
signal ride_requested
signal victory
const Rules = preload("res://game/ElevatorShooterState.gd")
const UI = preload("res://game/GameHUD.gd")
const BASE := Vector2(1000, 640)
const SPACE := Color("080f25")
const AMBER := Color("ffc779")
const LASER_GREEN := Color("78ff83")
const ENEMY_RED := Color("ca3944")
const ENEMY_GOLD := Color("ffd45c")
## Result buttons wait briefly so held fire or frantic clicks cannot skip the outcome.
const RESULT_HOLD: float = 1.2
var state: RefCounted = Rules.new()
var theme_source: Control
var frame: Control
var art: Control
var wave_label: Label
var shields_label: Label
var progress_label: Label
var dodge_label: Label
var pause_button: Button
var close_button: Button
var center_panel: PanelContainer
var center_title: Label
var center_text: Label
var primary_button: Button
var shown_phase: String = ""
var replay_button: Button
var result_hold: float = 0.0
var replaying: bool = false
var earned_state: RefCounted

func _ready() -> void:
	name = "ElevatorShooter"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.07, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	frame = Control.new()
	frame.size = BASE
	add_child(frame)
	art = Control.new()
	art.size = BASE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_arena)
	frame.add_child(art)
	_label("LIFT / FLIGHT CONTROL", Vector2(28, 20), 25)
	_label("Clear the drones. Power the elevator.", Vector2(28, 55), 17)
	wave_label = _label("", Vector2(718, 22), 19)
	shields_label = _label("", Vector2(718, 55), 17)
	progress_label = _label("", Vector2(28, 552), 19)
	dodge_label = _label("", Vector2(28, 580), 15)
	_label("WASD / arrows: move     Hold Space: shoot     P: pause     Esc: close", Vector2(28, 604), 16)
	pause_button = theme_source._button("Pause [P]", false)
	pause_button.position = Vector2(666, 554)
	pause_button.size = Vector2(140, 42)
	pause_button.pressed.connect(toggle_pause)
	frame.add_child(pause_button)
	close_button = theme_source._button("Close [Esc]", false)
	close_button.position = Vector2(822, 554)
	close_button.size = Vector2(150, 42)
	close_button.pressed.connect(close)
	frame.add_child(close_button)
	center_panel = PanelContainer.new()
	var style: StyleBoxFlat = theme_source._panel_style()
	style.bg_color = UI.NAVY
	style.border_color = UI.CYAN
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	center_panel.add_theme_stylebox_override("panel", style)
	center_panel.position = Vector2(255, 205)
	center_panel.custom_minimum_size = Vector2(490, 0)
	frame.add_child(center_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center_panel.add_child(column)
	center_title = theme_source._label("", 26)
	column.add_child(center_title)
	center_text = theme_source._label("", 18)
	center_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_text.custom_minimum_size.x = 442
	column.add_child(center_text)
	primary_button = theme_source._button("", true)
	primary_button.pressed.connect(_primary_action)
	column.add_child(primary_button)
	replay_button = theme_source._button("Play again", false)
	replay_button.pressed.connect(start_replay)
	column.add_child(replay_button)
	# Tab stays in the arcade modal; hidden controls are skipped by Godot.
	var focus_controls: Array[Control] = [primary_button, replay_button, pause_button, close_button]
	for i: int in range(focus_controls.size()):
		focus_controls[i].focus_next = focus_controls[i].get_path_to(focus_controls[(i + 1) % focus_controls.size()])
		focus_controls[i].focus_previous = focus_controls[i].get_path_to(focus_controls[(i - 1 + focus_controls.size()) % focus_controls.size()])
	resized.connect(_fit)
	_fit()
	_sync()
	hide()

func _label(text: String, at: Vector2, font_size: int) -> Label:
	var label: Label = theme_source._label(text, font_size)
	label.position = at
	frame.add_child(label)
	return label

func _fit() -> void:
	if not is_instance_valid(frame): return
	var factor: float = minf((size.x - 32) / BASE.x, (size.y - 32) / BASE.y)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - BASE * factor) * 0.5

func open() -> void:
	show()
	state.paused = false
	shown_phase = ""
	_sync()
	if center_panel.visible: primary_button.grab_focus()
	else: pause_button.grab_focus()

func close() -> void:
	state.paused = true
	if replaying:
		state = earned_state;replaying = false;shown_phase = ""
	hide()
	closed.emit()

## A fresh practice flight; the earned elevator unlock is kept on the original state.
func start_replay() -> void:
	if not replaying and state.completed(): earned_state = state
	if earned_state == null: return
	replaying = true
	state = Rules.new()
	shown_phase = ""
	state.start()
	_sync()
	pause_button.grab_focus()

func toggle_pause() -> void:
	if state.phase not in ["playing", "between"]: return
	state.paused = not state.paused
	_sync()

func _primary_action() -> void:
	if state.completed():
		ride_requested.emit()
	elif state.paused:
		state.paused = false
	else:
		state.start()
	_sync()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P:
			toggle_pause()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_SPACE and not state.paused and state.phase in ["playing", "between"]:
		get_viewport().set_input_as_handled()
	# Space is the fire key: it never confirms a result screen. Click, or Enter after the hold.
	if event is InputEventKey and event.keycode == KEY_SPACE and state.phase in ["won", "lost"]:
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and visible and state.phase in ["playing", "between"]:
		state.paused = true
		_sync()

func _process(delta: float) -> void:
	if not visible: return
	if result_hold > 0:
		result_hold = maxf(0, result_hold - delta)
		primary_button.disabled = result_hold > 0
		replay_button.disabled = result_hold > 0
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var previous_cooldown: float=state.cooldown
	var previous_cleared: int=state.cleared
	var previous_shields: int=state.shields
	var previous_phase: String=state.phase
	state.step(delta, direction, Input.is_physical_key_pressed(KEY_SPACE))
	if state.cooldown>previous_cooldown: GameAudio.play("shot")
	if state.cleared>previous_cleared: GameAudio.play("hit")
	if state.shields<previous_shields: GameAudio.play("damage")
	if state.phase!=previous_phase and state.phase in ["won","between"]: GameAudio.play("success")
	if state.phase!=previous_phase and state.phase=="lost": GameAudio.play("error")
	_sync()
	art.queue_redraw()

func _sync() -> void:
	wave_label.text = "WAVE %02d / 03" % maxi(1, state.wave)
	shields_label.text = "SHIELDS  " + "● ".repeat(state.shields) + "○ ".repeat(Rules.MAX_SHIELDS - state.shields)
	progress_label.text = "%02d / %02d DRONES CLEARED" % [state.cleared, Rules.TOTAL_DRONES]
	dodge_label.text = "Amber lane: move up/down with W/S or arrows" if state.wave >= 2 else "Keep moving and hold Space to fire"
	pause_button.disabled = state.phase not in ["playing", "between"]
	pause_button.text = "Resume [P]" if state.paused else "Pause [P]"
	var phase: String = "paused" if state.paused else state.phase
	if phase == shown_phase: return
	shown_phase = phase
	center_panel.visible = phase in ["ready", "paused", "lost", "won"]
	replay_button.visible = phase == "won"
	result_hold = RESULT_HOLD if phase in ["won", "lost"] and DisplayServer.get_name() != "headless" else 0.0
	primary_button.disabled = result_hold > 0
	replay_button.disabled = result_hold > 0
	match phase:
		"ready":
			center_title.text = "PREPARE FOR TAKEOFF"
			center_text.text = "Clear three short waves to unlock the ride upstairs. Move with WASD or arrows and hold Space to fire. Later waves add bursts, spread shots and marked horizontal lanes. Move up/down to leave a marked lane before it fires. Amber markers warn before firing. Three shields. Unlimited retries."
			primary_button.text = "Launch flight"
		"paused":
			center_title.text = "FLIGHT PAUSED"
			center_text.text = "Your run is saved while this screen is closed. Resume whenever you're ready."
			primary_button.text = "Resume flight"
		"lost":
			center_title.text = "SHIELDS DEPLETED"
			center_text.text = "Try again. Keep moving to dodge the amber shots. Retrying starts all three waves with full shields."
			primary_button.text = "Retry flight"
		"won":
			victory.emit()
			center_title.text = "PRACTICE COMPLETE" if replaying else "ELEVATOR ONLINE"
			center_text.text = ("All 18 drones cleared again. The elevator was already unlocked." if replaying else "All 18 drones cleared. The elevator is unlocked for this session.") + " Click Ride upstairs when you're ready, or play again."
			primary_button.text = "Ride upstairs"
	if center_panel.visible:
		center_panel.reset_size()
		primary_button.grab_focus()

func _draw_arena() -> void:
	art.draw_style_box(theme_source._panel_style(), Rect2(Vector2.ZERO, BASE))
	art.draw_rect(Rules.ARENA, SPACE)
	art.draw_rect(Rules.ARENA, Color(UI.CYAN, 0.45), false, 1)
	# Stable star positions; only their scrolling offset follows simulation time.
	for i: int in range(90):
		var star := Vector2(32 + fmod(i * 137.7, 930), 108 + fmod(i * 83.3 + state.clock * (12 + i % 3 * 9), 416))
		art.draw_circle(star, 1.0 if i % 5 else 1.7, Color(UI.WHITE, 0.22 if i % 5 else 0.6))
	for x: int in range(64, 977, 76):
		art.draw_line(Vector2(x, 101), Vector2(x, 533), Color(UI.CYAN, 0.035), 1)
	# Orbital rings and horizon give depth without textures or extra scene nodes.
	art.draw_arc(Vector2(500, 318), 165, PI, TAU, 80, Color(UI.CYAN, 0.09), 1.5, true)
	art.draw_arc(Vector2(500, 318), 255, PI, TAU, 100, Color(UI.CYAN, 0.05), 1, true)
	art.draw_line(Vector2(25, 325), Vector2(975, 325), Color(UI.CYAN, 0.1), 1)
	for enemy: Dictionary in state.enemies: _draw_drone(enemy.at)
	for shot: Vector2 in state.shots:
		art.draw_line(shot, shot + Vector2(0, 18), Color(LASER_GREEN, 0.16), 12, true)
		art.draw_line(shot, shot + Vector2(0, 14), LASER_GREEN, 4, true)
		art.draw_line(shot, shot + Vector2(0, 10), UI.WHITE, 1.5, true)
	for warning: Dictionary in state.warnings:
		if warning.get("lane",false):
			_draw_lane(warning.at.y, false)
			continue
		art.draw_arc(warning.at,14,0,TAU,20,AMBER,2,true)
		art.draw_line(warning.at,warning.at+warning.velocity.normalized()*32,Color(AMBER,.6),1,true)
	for hazard: Dictionary in state.hazards:
		if hazard.get("lane",false):
			_draw_lane(hazard.at.y, true)
			continue
		art.draw_circle(hazard.at, 10, Color(AMBER, 0.12))
		# Enemy shots are amber diamonds; friendly fire is a green beam.
		art.draw_colored_polygon(PackedVector2Array([hazard.at+Vector2(0,-7),hazard.at+Vector2(5,0),hazard.at+Vector2(0,7),hazard.at+Vector2(-5,0)]),AMBER)
	for burst: Dictionary in state.bursts:
		var fraction: float = burst.age / 0.5
		art.draw_arc(burst.at, 7 + fraction * 35, 0, TAU, 24, Color(AMBER, 1 - fraction), 2, true)
		for i: int in range(6):
			var outward := Vector2.from_angle(i * TAU / 6)
			art.draw_line(burst.at + outward * fraction * 40, burst.at + outward * (fraction * 40 + 8), Color(UI.CYAN, 1 - fraction), 2, true)
	if state.invulnerable <= 0 or fmod(state.clock, 0.16) < 0.08: _draw_ship()
	if state.phase == "between":
		var font: Font = ThemeDB.fallback_font
		art.draw_string(font, Vector2(355, 285), "SECTOR CLEAR / NEXT WAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.CYAN)
	# Completion strip communicates progress without inventing course points.
	art.draw_rect(Rect2(28, 582, 575, 4), Color(UI.WHITE, 0.12))
	art.draw_rect(Rect2(28, 582, 575.0 * state.cleared / Rules.TOTAL_DRONES, 4), UI.CYAN)

func _draw_drone(at: Vector2) -> void:
	art.draw_set_transform(at)
	art.draw_circle(Vector2.ZERO, 29, Color(AMBER, 0.055))
	art.draw_colored_polygon(PackedVector2Array([Vector2(-27,-12),Vector2(-12,-7),Vector2(-8,10),Vector2(-29,7),Vector2(-20,-1)]), ENEMY_GOLD)
	art.draw_colored_polygon(PackedVector2Array([Vector2(27,-12),Vector2(12,-7),Vector2(8,10),Vector2(29,7),Vector2(20,-1)]), ENEMY_GOLD)
	art.draw_colored_polygon(PackedVector2Array([Vector2(0,-20),Vector2(15,-4),Vector2(11,15),Vector2(0,23),Vector2(-11,15),Vector2(-15,-4)]), ENEMY_RED)
	art.draw_line(Vector2(-10,-1), Vector2(0,10), AMBER, 3, true)
	art.draw_line(Vector2(0,10), Vector2(10,-1), AMBER, 3, true)
	art.draw_circle(Vector2(0,-4), 4, UI.WHITE)
	art.draw_set_transform(Vector2.ZERO)

func _draw_ship() -> void:
	art.draw_set_transform(state.ship)
	var flame: float = 22 + sin(state.clock * 35) * 5
	art.draw_colored_polygon(PackedVector2Array([Vector2(-8,16),Vector2(0,flame+16),Vector2(8,16)]), Color(UI.CYAN, 0.45))
	art.draw_colored_polygon(PackedVector2Array([Vector2(-3,17),Vector2(0,flame+6),Vector2(3,17)]), UI.WHITE)
	art.draw_colored_polygon(PackedVector2Array([Vector2(0,-27),Vector2(13,-3),Vector2(32,19),Vector2(11,13),Vector2(0,21),Vector2(-11,13),Vector2(-32,19),Vector2(-13,-3)]), Color("d5e6fa"))
	art.draw_colored_polygon(PackedVector2Array([Vector2(0,-23),Vector2(8,5),Vector2(0,14),Vector2(-8,5)]), Color("4f6a94"))
	art.draw_line(Vector2(-23,14), Vector2(-10,3), UI.CYAN, 3, true)
	art.draw_line(Vector2(23,14), Vector2(10,3), UI.CYAN, 3, true)
	art.draw_circle(Vector2(0,-3), 4, UI.CYAN)
	art.draw_set_transform(Vector2.ZERO)

func _draw_lane(y: float, firing: bool) -> void:
	var left: float=Rules.ARENA.position.x
	var right: float=Rules.ARENA.end.x
	# The marked band covers the real 22px collision radius and stays steady.
	var band:=Rect2(Vector2(left,y-22),Vector2(right-left,44)).intersection(Rules.ARENA)
	art.draw_rect(band,Color(AMBER,.24 if firing else .1))
	if firing:
		art.draw_line(Vector2(left,y),Vector2(right,y),AMBER,8,true)
		art.draw_line(Vector2(left,y),Vector2(right,y),UI.WHITE,2,true)
	else:
		art.draw_line(Vector2(left,y-22),Vector2(right,y-22),Color(AMBER,.65),1,true)
		art.draw_line(Vector2(left,y+22),Vector2(right,y+22),Color(AMBER,.65),1,true)
		for x: int in range(int(left+12),int(right-12),28):
			art.draw_line(Vector2(x,y),Vector2(x+12,y),AMBER,2,true)
