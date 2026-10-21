extends Node3D
# "Pursuit: The Climb" — Level 1 blockout, built entirely in code.
# A walkable Pursuit-styled room with one mini-game: beat THE PLATFORM's
# question lock by picking the 3 real tasks (use AI to cut the noise).

# ---- Palette (Pursuit) ----
const NAVY := Color(0.055, 0.082, 0.22)
const NAVY_WALL := Color(0.10, 0.13, 0.30)
const WHITE := Color(0.90, 0.92, 1.0)
const CYAN := Color(0.21, 0.88, 1.0)
const GOLD := Color(1.0, 0.82, 0.29)
const RED := Color(0.94, 0.35, 0.24)
const PURPLE := Color(0.66, 0.54, 1.0)   # THE PLATFORM is purple

var player: CharacterBody3D
var terminal: Node3D
var platform_ent: Node3D
var gate: Node3D
var star_awarded := false
var won := false

# UI
var ui: CanvasLayer
var objective_lbl: Label
var prompt_lbl: Label
var game_panel: Control
var result_lbl: Label
var chip_buttons: Array = []
var selected := {}

const CHIPS := [
	{"t": "Show up / check in", "ok": true},
	{"t": "Submit your project", "ok": true},
	{"t": "Help a teammate", "ok": true},
	{"t": "Answer 100 sub-questions", "ok": false},
	{"t": "Re-read the rubric 5 times", "ok": false},
	{"t": "Refresh the page again", "ok": false},
	{"t": "Reorganize your folders", "ok": false},
	{"t": "Reflect on your reflection", "ok": false},
]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_environment()
	_build_room()
	_build_props()
	_build_platform()
	_build_player()
	_build_ui()

# ---------- helpers ----------
func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m

func _box(size: Vector3, col: Color, pos: Vector3, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, emit)
	mi.position = pos
	add_child(mi)
	return mi

func _static_box(size: Vector3, col: Color, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	body.add_child(mi)
	add_child(body)

# ---------- world ----------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NAVY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.40, 0.65)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = NAVY
	env.fog_density = 0.015
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	# warm fill lamp over the desk
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.2, -4)
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 2.0
	lamp.omni_range = 9.0
	add_child(lamp)

func _build_room() -> void:
	var W := 12.0
	var D := 14.0
	var H := 4.0
	# floor
	_static_box(Vector3(W, 0.4, D), Color(0.14, 0.16, 0.22), Vector3(0, -0.2, 0))
	# ceiling (dark) with "duct" strips
	_box(Vector3(W, 0.2, D), NAVY, Vector3(0, H, 0))
	for i in range(-2, 3):
		_box(Vector3(0.6, 0.25, D - 1.0), Color(0.75, 0.79, 0.9), Vector3(i * 2.0, H - 0.35, 0), 0.0)
	# red sprinkler pipe
	_box(Vector3(W - 1.0, 0.12, 0.12), RED, Vector3(0, H - 0.7, -2.0), 0.3)
	# walls
	_static_box(Vector3(W, H, 0.4), NAVY_WALL, Vector3(0, H / 2.0, -D / 2.0)) # back
	_static_box(Vector3(0.4, H, D), NAVY_WALL, Vector3(-W / 2.0, H / 2.0, 0)) # left
	_static_box(Vector3(0.4, H, D), WHITE * 0.3, Vector3(W / 2.0, H / 2.0, 0)) # right
	_static_box(Vector3(W, H, 0.4), NAVY_WALL, Vector3(0, H / 2.0, D / 2.0))  # front

func _build_props() -> void:
	# neon "Pursuit" accent bar on the back wall
	_box(Vector3(3.0, 0.5, 0.1), CYAN, Vector3(-3.0, 2.6, -D_back() + 0.1), 3.0)
	# colorful art panels
	_box(Vector3(1.2, 1.2, 0.1), Color(0.95, 0.78, 0.3), Vector3(2.0, 2.4, -D_back() + 0.1), 0.4)
	_box(Vector3(1.2, 1.2, 0.1), Color(0.35, 0.8, 0.55), Vector3(3.6, 2.4, -D_back() + 0.1), 0.4)
	# the red landmark trash can
	var can := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 1.0
	can.mesh = cyl
	can.material_override = _mat(RED, 0.15)
	can.position = Vector3(5.0, 0.5, 4.5)
	add_child(can)
	# desk
	_static_box(Vector3(2.4, 0.15, 1.0), Color(0.62, 0.45, 0.28), Vector3(0, 1.0, -4.0))
	_box(Vector3(0.12, 1.0, 0.12), Color(0.3, 0.22, 0.14), Vector3(-1.0, 0.5, -3.6))
	_box(Vector3(0.12, 1.0, 0.12), Color(0.3, 0.22, 0.14), Vector3(1.0, 0.5, -3.6))
	# the ★1 exit gate (closed = red bar; opens on solving)
	gate = Node3D.new()
	add_child(gate)
	var bar := _box(Vector3(2.4, 2.2, 0.2), Color(0.5, 0.2, 0.2), Vector3(0, 1.1, D_back() - 0.2 + 0.0), 0.2)
	bar.reparent(gate) if bar.get_parent() else gate.add_child(bar)
	gate.position = Vector3(0, 0, 0)
	var star_lbl := _box(Vector3(0.5, 0.5, 0.08), GOLD, Vector3(0, 2.6, D_back() - 0.3), 2.0)

func D_back() -> float:
	return 7.0  # half-depth (D/2)

func _build_platform() -> void:
	# THE PLATFORM — a floating purple character (blockout ghost + hat).
	platform_ent = Node3D.new()
	platform_ent.position = Vector3(0, 1.9, -3.2)
	add_child(platform_ent)
	# body (ghost): a capsule
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.4
	body.mesh = cap
	body.material_override = _mat(PURPLE, 0.8)
	platform_ent.add_child(body)
	# eyes
	for ex in [-0.18, 0.18]:
		var eye := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.07
		sp.height = 0.14
		eye.mesh = sp
		eye.material_override = _mat(CYAN, 2.0)
		eye.position = Vector3(ex, 0.25, 0.42)
		platform_ent.add_child(eye)
	# hat (a wide box + top box)
	var brim := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.0, 0.08, 1.0); brim.mesh = bm
	brim.material_override = _mat(Color(0.2, 0.12, 0.32), 0.2)
	brim.position = Vector3(0, 0.78, 0)
	platform_ent.add_child(brim)
	var top := MeshInstance3D.new()
	var tb := BoxMesh.new(); tb.size = Vector3(0.6, 0.5, 0.6); top.mesh = tb
	top.material_override = _mat(Color(0.2, 0.12, 0.32), 0.2)
	top.position = Vector3(0, 1.05, 0)
	platform_ent.add_child(top)

	# interactive terminal (the laptop/portal) in front of the platform
	terminal = _box(Vector3(0.8, 0.5, 0.1), PURPLE, Vector3(0, 1.3, -3.8), 1.2)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(load("res://Player.gd"))
	player.position = Vector3(0, 1.0, 4.5)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cs.shape = cap
	player.add_child(cs)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 0.7, 0)
	player.add_child(cam)
	add_child(player)

# ---------- UI ----------
func _lbl(text: String, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", WHITE)
	return l

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	# objective (top-left)
	objective_lbl = _lbl("LEVEL 1 — THE FOUNDATION\nFind THE PLATFORM's desk. Press E to face it.", 18)
	objective_lbl.position = Vector2(24, 20)
	ui.add_child(objective_lbl)

	# interact prompt (bottom center)
	prompt_lbl = _lbl("", 22)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.anchor_left = 0.0; prompt_lbl.anchor_right = 1.0
	prompt_lbl.anchor_top = 0.86; prompt_lbl.anchor_bottom = 0.86
	prompt_lbl.add_theme_color_override("font_color", GOLD)
	ui.add_child(prompt_lbl)

	# mini-game panel (hidden)
	game_panel = Control.new()
	game_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_panel.visible = false
	ui.add_child(game_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.14, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_panel.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := _lbl("THE PLATFORM: \"Answer ALL my questions!\"", 24)
	title.add_theme_color_override("font_color", PURPLE)
	box.add_child(title)
	box.add_child(_lbl("Don't. Use AI to cut the noise — pick ONLY the 3 real tasks:", 16))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	chip_buttons.clear()
	for i in CHIPS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = CHIPS[i]["t"]
		b.custom_minimum_size = Vector2(270, 44)
		b.toggled.connect(_on_chip_toggled.bind(i))
		grid.add_child(b)
		chip_buttons.append(b)

	var confirm := Button.new()
	confirm.text = "Focus with AI  ✨"
	confirm.custom_minimum_size = Vector2(0, 48)
	confirm.pressed.connect(_on_confirm)
	box.add_child(confirm)

	result_lbl = _lbl("", 16)
	result_lbl.add_theme_color_override("font_color", GOLD)
	box.add_child(result_lbl)

func _on_chip_toggled(pressed: bool, idx: int) -> void:
	selected[idx] = pressed

func _on_confirm() -> void:
	var picked := []
	for k in selected.keys():
		if selected[k]:
			picked.append(k)
	var ok := picked.size() == 3
	if ok:
		for idx in picked:
			if not CHIPS[idx]["ok"]:
				ok = false
	if ok:
		result_lbl.text = "Focused! Hidden Objective #1: use AI to beat the busywork. ★ Star earned."
		star_awarded = true
		await get_tree().create_timer(1.4).timeout
		_close_game(true)
	else:
		result_lbl.text = "The Platform grins. That's not the 3 that matter — try again."

# ---------- interaction loop ----------
func _near_terminal() -> bool:
	return player and terminal and player.global_position.distance_to(terminal.global_position) < 3.0

func _near_gate() -> bool:
	return player and player.global_position.z > (D_back() - 1.6)

func _process(_delta: float) -> void:
	if platform_ent:
		platform_ent.rotation.y += _delta_safe() * 0.6
		platform_ent.position.y = 1.9 + sin(Time.get_ticks_msec() / 500.0) * 0.08
	if won:
		return
	if game_panel.visible:
		return
	if _near_terminal() and not star_awarded:
		prompt_lbl.text = "[E] Face the Platform"
	elif star_awarded and not _near_gate():
		prompt_lbl.text = "The ★1 gate is open — walk through it."
	else:
		prompt_lbl.text = ""
	if star_awarded and _near_gate():
		_win()

func _delta_safe() -> float:
	return get_process_delta_time()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and _near_terminal() and not star_awarded and not game_panel.visible:
			_open_game()
		elif event.keycode == KEY_ESCAPE:
			if game_panel.visible:
				_close_game(false)
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _open_game() -> void:
	game_panel.visible = true
	prompt_lbl.text = ""
	if player: player.can_move = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_game(solved: bool) -> void:
	game_panel.visible = false
	if player: player.can_move = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if solved and gate:
		# open the gate: lift it out of the way
		var tw := create_tween()
		tw.tween_property(gate, "position", Vector3(0, 4.0, 0), 0.8)
		objective_lbl.text = "LEVEL 1 — THE FOUNDATION\n★ Do the Work earned. Walk through the ★1 gate!"

func _win() -> void:
	won = true
	prompt_lbl.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player: player.can_move = false
	var win := ColorRect.new()
	win.color = Color(0.03, 0.05, 0.14, 0.92)
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(win)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	var t := _lbl("★1 — LEVEL 1 COMPLETE", 34)
	t.add_theme_color_override("font_color", GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _lbl("You reached the star floor and beat the Platform by using AI.\nNext: the tactile puzzle room (The Room-style). Press Esc to free the mouse.", 18)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
