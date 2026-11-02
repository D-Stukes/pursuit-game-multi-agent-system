extends Control
## The robot challenge "room". Pressing H at the classroom robot opens this
## full-screen overlay, styled like the Journey Guide (dim backdrop + the navy
## panel, plus a soft gray spotlight for a workshop feel). Three beats:
##   1. Recover the robot's scattered parts (a hidden-pieces hunt).
##   2. Build an AI agent team (pick at least two) and send them the right prompt.
##   3. On success the overlay closes and Main plays the robot's Assemble ->
##      PowerOn -> Idle animation as the payoff.
## This stays self-contained and scripted (no live AI), like Mr. P's room.
signal close_requested
signal completed

const UI = preload("res://game/GameHUD.gd")

# The six parts the AI Builder must recover, placed as fractions (x,y) of the
# scene area so the scatter survives any window size. Each has a decoy-free spot.
const PARTS := [
	{"id":"head",       "name":"Head unit",  "pos":Vector2(0.17,0.30), "kind":"head"},
	{"id":"power_core", "name":"Power core", "pos":Vector2(0.80,0.26), "kind":"core"},
	{"id":"left_arm",   "name":"Left arm",   "pos":Vector2(0.37,0.66), "kind":"arm"},
	{"id":"right_arm",  "name":"Right arm",  "pos":Vector2(0.62,0.19), "kind":"arm"},
	{"id":"left_leg",   "name":"Left leg",   "pos":Vector2(0.27,0.80), "kind":"leg"},
	{"id":"right_leg",  "name":"Right leg",  "pos":Vector2(0.72,0.74), "kind":"leg"},
]
# Non-parts scattered in to make the hunt a hunt. Clicking one is harmless.
const DECOYS := [
	{"pos":Vector2(0.50,0.44), "kind":"scrap"},
	{"pos":Vector2(0.11,0.60), "kind":"scrap"},
	{"pos":Vector2(0.89,0.58), "kind":"scrap"},
	{"pos":Vector2(0.45,0.85), "kind":"scrap"},
]

# The agent roster for beat 2. "core" marks the one agent the team cannot
# rebuild without (it actually fits the parts together).
const AGENTS := [
	{"id":"vision",  "name":"Vision Agent",  "role":"Scans the parts and works out where each one goes.", "core":false},
	{"id":"planner", "name":"Planner Agent", "role":"Puts the assembly steps in a safe, sensible order.",  "core":false},
	{"id":"builder", "name":"Builder Agent", "role":"Fits the parts together and tightens every joint.",   "core":true},
	{"id":"power",   "name":"Power Agent",   "role":"Brings the power core online without frying it.",      "core":false},
	{"id":"comms",   "name":"Comms Agent",   "role":"Writes the status report once the robot is back up.",  "core":false},
]

# The prompt choices for beat 2b. Exactly one is the strong, specific, safely
# ordered instruction; the others teach why they fall short.
const PROMPTS := [
	{"text":"Fix the robot.",
	 "ok":false,
	 "why":"Too vague — your agents don't know where to start, what \"fixed\" means, or in what order. Say the goal and the steps."},
	{"text":"Rebuild the robot: attach the head, arms and legs to the torso, then seat the power core, and only then power it on. Report when it's online.",
	 "ok":true,
	 "why":""},
	{"text":"Switch the power on first so it can help, then add the arms, legs, head and core.",
	 "ok":false,
	 "why":"Powering up before the core is seated could fry the circuits. Build it first, then bring the power online."},
]

# Steel look for the hidden part silhouettes. DIM is visible-but-faint so the
# hunt is a scan, not a guess; hover brings a part to full; FOUND turns it cyan.
const STEEL := Color(0.82, 0.86, 0.94)
const STEEL_DARK := Color(0.50, 0.55, 0.64)
const DIM := Color(0.90, 0.93, 0.99, 0.60)
const BRIGHT := Color(1.0, 1.0, 1.0, 1.0)
const FOUND := Color(0.42, 0.95, 1.0, 1.0)

var world: Node3D
var panel: PanelContainer
var column: VBoxContainer
var title: Label
var step_label: Label
var stage: Control
var close_button: Button

var beat: int = 1
var found: Dictionary = {}          # part id -> true once recovered
var part_buttons: Array[Button] = []
var picked: Dictionary = {}         # agent id -> true
var chosen_prompt: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", world.hud._panel_style())
	add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", UI.GAP)
	panel.add_child(column)
	# Header: title, a beat indicator, and a way out.
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	title = world.hud._label("ROBOT CHALLENGE", 24)
	titles.add_child(title)
	step_label = world.hud._label("", 15)
	step_label.modulate = UI.CYAN
	titles.add_child(step_label)
	close_button = world.hud._button("Leave [Esc]", false)
	close_button.pressed.connect(func(): close_requested.emit())
	header.add_child(close_button)
	# The swappable beat area.
	stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	column.add_child(stage)
	resized.connect(_fit)
	hide()
	_fit()

func _fit() -> void:
	if panel == null: return
	panel.position = Vector2(UI.EDGE, UI.EDGE)
	panel.size = size - Vector2(UI.EDGE * 2, UI.EDGE * 2)
	if beat == 1: _layout_scene()

# ---------------------------------------------------------------- open / reset

func open() -> void:
	# Fresh attempt each time it is opened (until the whole thing is completed).
	beat = 1
	found.clear()
	picked.clear()
	chosen_prompt = -1
	part_buttons.clear()
	show()
	_build_beat1()
	close_button.grab_focus()

func _clear_stage() -> void:
	for child in stage.get_children():
		child.queue_free()

# A soft gray spotlight behind a beat, echoing the guidebook's lit look.
func _add_backdrop() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.21, 0.23, 0.28))
	grad.set_color(1, Color(0.06, 0.07, 0.10))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.40)
	tex.fill_to = Vector2(1.0, 1.05)
	var rect := TextureRect.new()
	rect.name = "Backdrop"
	rect.texture = tex
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rect)

# A padded VBox that fills the stage, for the text-based beats.
func _page(intro: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	stage.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", UI.GAP)
	scroll.add_child(box)
	if intro != "":
		var lead : Label = world.hud._label(intro, 17)
		lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lead.custom_minimum_size.x = 520
		box.add_child(lead)
	return box

# -------------------------------------------------------------- beat 1: parts

func _build_beat1() -> void:
	beat = 1
	_clear_stage()
	step_label.text = "Step 1 of 2  ·  Recover the scattered parts"
	_add_backdrop()
	var caption : Label = world.hud._label(
		"Six robot parts are hidden in the gloom below — with a few bits of scrap mixed in.\nHover to light a shape up, then click each real part to recover it.", 16)
	caption.add_theme_constant_override("line_spacing", 2)
	caption.position = Vector2(20, 12)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(caption)
	# Decoys first so real parts sit on top where they overlap.
	for d in DECOYS:
		_spawn_find(d.pos, "scrap", "", false)
	part_buttons.clear()
	for p in PARTS:
		_spawn_find(p.pos, p.kind, p.name, true, p.id)
	var counter : Label = world.hud._label("", 18)
	counter.name = "Counter"
	counter.modulate = UI.CYAN
	counter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	counter.position = Vector2(20, -40)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(counter)
	var go : Button = world.hud._button("Build the robot  ›", true)
	go.name = "Continue"
	go.disabled = true
	go.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	go.position = Vector2(-186, -52)
	go.pressed.connect(_build_beat2a)
	stage.add_child(go)
	_refresh_counter()
	_layout_scene()

# One findable thing: a dim steel silhouette. Real parts carry an id; decoys do
# not. The clickable Button is invisible itself — a shaped glyph rides on top.
func _spawn_find(frac: Vector2, kind: String, label_text: String, is_part: bool, id: String = "") -> void:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_meta("frac", frac)
	btn.set_meta("kind", kind)
	btn.set_meta("is_part", is_part)
	btn.set_meta("found", false)
	btn.custom_minimum_size = _glyph_size(kind)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var glyph := _build_glyph(kind)
	glyph.name = "Glyph"
	glyph.modulate = DIM
	btn.add_child(glyph)
	var name_tag := Label.new()
	name_tag.name = "Tag"
	name_tag.text = label_text
	name_tag.add_theme_font_size_override("font_size", 13)
	name_tag.add_theme_color_override("font_color", UI.CYAN)
	name_tag.visible = false
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_tag)
	# Hovering lights a piece up so it is clearly findable.
	btn.mouse_entered.connect(func():
		if not bool(btn.get_meta("found")): glyph.modulate = BRIGHT)
	btn.mouse_exited.connect(func():
		if not bool(btn.get_meta("found")): glyph.modulate = DIM)
	btn.pressed.connect(_on_find.bind(btn, id))
	stage.add_child(btn)
	if is_part: part_buttons.append(btn)

func _glyph_size(kind: String) -> Vector2:
	match kind:
		"head": return Vector2(58, 52)
		"arm":  return Vector2(30, 86)
		"leg":  return Vector2(34, 92)
		"core": return Vector2(56, 56)
		_:      return Vector2(46, 40)

# A blocky robot-part silhouette built from rects (robots are blocky — it reads).
func _build_glyph(kind: String) -> Control:
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.custom_minimum_size = _glyph_size(kind)
	g.size = _glyph_size(kind)
	for r: Dictionary in _shape_rects(kind):
		var rect := ColorRect.new()
		rect.color = STEEL_DARK if r.get("dark", false) else STEEL
		rect.position = r.pos
		rect.size = r.size
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(rect)
	return g

func _shape_rects(kind: String) -> Array:
	match kind:
		"head": return [
			{"pos":Vector2(26,0),  "size":Vector2(6,9)},                  # antenna
			{"pos":Vector2(6,8),   "size":Vector2(46,42)},                # skull
			{"pos":Vector2(16,22), "size":Vector2(9,9),  "dark":true},    # eye
			{"pos":Vector2(33,22), "size":Vector2(9,9),  "dark":true}]    # eye
		"arm": return [
			{"pos":Vector2(8,0),   "size":Vector2(14,50)},               # upper arm
			{"pos":Vector2(6,46),  "size":Vector2(18,30)},               # forearm
			{"pos":Vector2(3,74),  "size":Vector2(24,12), "dark":true}]  # hand
		"leg": return [
			{"pos":Vector2(9,0),   "size":Vector2(16,52)},               # thigh
			{"pos":Vector2(7,50),  "size":Vector2(20,32)},               # shin
			{"pos":Vector2(2,82),  "size":Vector2(30,10), "dark":true}]  # foot
		"core": return [
			{"pos":Vector2(4,4),   "size":Vector2(48,48), "dark":true},  # casing
			{"pos":Vector2(14,14), "size":Vector2(28,28)},               # cell
			{"pos":Vector2(26,10), "size":Vector2(4,36)},                # + bar
			{"pos":Vector2(10,26), "size":Vector2(36,4)}]                # + bar
		_: return [
			{"pos":Vector2(4,16),  "size":Vector2(20,10), "dark":true},  # scrap
			{"pos":Vector2(22,6),  "size":Vector2(14,22), "dark":true},
			{"pos":Vector2(12,26), "size":Vector2(16,8)}]

func _on_find(btn: Button, id: String) -> void:
	if bool(btn.get_meta("found")): return
	var glyph: Control = btn.get_node_or_null("Glyph")
	if not bool(btn.get_meta("is_part")):
		# A decoy: a red flash, then back into the gloom.
		if glyph != null: glyph.modulate = Color(1.0, 0.5, 0.55, 1.0)
		btn.tooltip_text = "Just scrap metal."
		var t := get_tree().create_timer(0.4)
		t.timeout.connect(func():
			if is_instance_valid(glyph): glyph.modulate = DIM)
		return
	btn.set_meta("found", true)
	found[id] = true
	if glyph != null: glyph.modulate = FOUND
	var tag: Label = btn.get_node("Tag")
	tag.visible = true
	tag.position = Vector2(-4, btn.custom_minimum_size.y + 2)
	_play_menu()
	_refresh_counter()

func _refresh_counter() -> void:
	var n: int = found.size()
	var counter: Label = stage.get_node_or_null("Counter")
	if counter != null:
		counter.text = "Parts recovered:  %d / %d" % [n, PARTS.size()]
	var go: Button = stage.get_node_or_null("Continue")
	if go != null:
		go.disabled = n < PARTS.size()
		if not go.disabled:
			go.grab_focus()

# Place the scattered finds for the current stage size.
func _layout_scene() -> void:
	if beat != 1 or stage == null: return
	var area: Vector2 = stage.size
	if area.x <= 0: return
	for child in stage.get_children():
		if child is Button and child.has_meta("frac"):
			var frac: Vector2 = child.get_meta("frac")
			var sz: Vector2 = child.custom_minimum_size
			var pad := Vector2(70, 90)
			var origin := Vector2(pad.x, pad.y)
			var span := area - pad * 2 - sz
			child.position = origin + Vector2(frac.x * span.x, frac.y * span.y)

# ------------------------------------------------------- beat 2a: pick agents

func _build_beat2a() -> void:
	beat = 2
	_clear_stage()
	step_label.text = "Step 2 of 2  ·  Build your AI agent team"
	_add_backdrop()
	var box := _page("All six parts are on the bench. You can't rebuild the robot alone — so direct a team of AI agents.\n\nPick at least TWO agents. Each one has a different job; choose the ones who can actually get the robot built.")
	for a in AGENTS:
		var row := Button.new()
		row.toggle_mode = true
		row.focus_mode = Control.FOCUS_ALL
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 56
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.text = "   " + a.name + "  —  " + a.role
		row.add_theme_font_size_override("font_size", 16)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style : StyleBoxFlat = world.hud._panel_style()
			style.bg_color = UI.NAVY
			style.border_color = UI.CYAN if state in ["hover", "focus"] else Color(UI.CYAN, 0.35)
			style.set_border_width_all(2 if state in ["hover", "focus"] else 1)
			row.add_theme_stylebox_override(state, style)
		row.toggled.connect(func(on: bool):
			picked[a.id] = on
			row.modulate = UI.SUCCESS if on else UI.WHITE
			_play_menu())
		box.add_child(row)
	var hint : Label = world.hud._label("", 15)
	hint.name = "Hint"
	hint.modulate = UI.ERROR
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 520
	box.add_child(hint)
	var nav := HBoxContainer.new()
	box.add_child(nav)
	var back : Button = world.hud._button("‹ Back", false)
	back.pressed.connect(_build_beat1)
	nav.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var go : Button = world.hud._button("Send the team  ›", true)
	go.pressed.connect(_submit_team.bind(hint))
	nav.add_child(go)

func _submit_team(hint: Label) -> void:
	var team: Array = picked.keys().filter(func(k): return picked[k])
	if team.size() < 2:
		hint.text = "A single agent can't do it all. Pick at least two."
		return
	if not picked.get("builder", false):
		hint.text = "Your team needs someone who actually fits the parts together — add the Builder Agent."
		return
	_build_beat2b()

# -------------------------------------------------------- beat 2b: the prompt

func _build_beat2b() -> void:
	_clear_stage()
	_add_backdrop()
	var team: Array = picked.keys().filter(func(k): return picked[k])
	var names: Array = []
	for a in AGENTS:
		if a.id in team: names.append(a.name)
	var box := _page("Your team is standing by: " + ", ".join(names) + ".\n\nNow send them the prompt. A good prompt names the goal, puts the steps in order, and keeps things safe. Pick the strongest one.")
	chosen_prompt = -1
	var choice_buttons: Array[Button] = []
	for i in range(PROMPTS.size()):
		var p = PROMPTS[i]
		var row := Button.new()
		row.toggle_mode = true
		row.focus_mode = Control.FOCUS_ALL
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.clip_text = false
		row.custom_minimum_size = Vector2(540, 60)
		row.text = "   " + p.text
		row.add_theme_font_size_override("font_size", 15)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style : StyleBoxFlat = world.hud._panel_style()
			style.border_color = UI.CYAN if state in ["hover", "focus"] else Color(UI.CYAN, 0.35)
			style.set_border_width_all(2 if state in ["hover", "focus"] else 1)
			row.add_theme_stylebox_override(state, style)
		row.toggled.connect(func(on: bool):
			if not on: return
			chosen_prompt = i
			for j in range(choice_buttons.size()):
				if j != i: choice_buttons[j].button_pressed = false
				choice_buttons[j].modulate = UI.CYAN if j == i else UI.WHITE
			_play_menu())
		box.add_child(row)
		choice_buttons.append(row)
	var hint : Label = world.hud._label("", 15)
	hint.name = "Hint"
	hint.modulate = UI.ERROR
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 540
	box.add_child(hint)
	var nav := HBoxContainer.new()
	box.add_child(nav)
	var back : Button = world.hud._button("‹ Team", false)
	back.pressed.connect(_build_beat2a)
	nav.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var go : Button = world.hud._button("Send prompt  ›", true)
	go.pressed.connect(_submit_prompt.bind(hint))
	nav.add_child(go)

func _submit_prompt(hint: Label) -> void:
	if chosen_prompt < 0:
		hint.text = "Choose a prompt to send."
		return
	if not bool(PROMPTS[chosen_prompt].ok):
		hint.text = str(PROMPTS[chosen_prompt].why)
		return
	_build_done()

# ------------------------------------------------------------- beat 3: launch

func _build_done() -> void:
	beat = 3
	_clear_stage()
	_add_backdrop()
	step_label.text = "Challenge complete"
	var box := _page("")
	var head : Label = world.hud._label("Prompt sent. Your agents get to work…", 20)
	head.modulate = UI.SUCCESS
	box.add_child(head)
	var body : Label = world.hud._label(
		"Vision finds each joint, the Planner orders the steps, the Builder fits the parts, and the Power Agent brings the core online — in the right order, safely.\n\nWatch the robot come back together.", 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 520
	box.add_child(body)
	_play_menu()
	# Hand off to Main for the 3D payoff after a short beat.
	var t := get_tree().create_timer(1.6)
	t.timeout.connect(func():
		completed.emit())

func _play_menu() -> void:
	GameAudio.play("menu")
