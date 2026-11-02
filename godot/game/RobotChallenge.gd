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

# The room's searchable furniture and decor. Six hide a robot part; a couple
# hide nothing. Clicking a spot searches it and pops out whatever is tucked there.
const SPOTS := [
	{"obj":"painting", "pos":Vector2(0.10, 0.03), "hides":"head"},
	{"obj":"clock",    "pos":Vector2(0.45, 0.02), "hides":"right_arm"},
	{"obj":"shelf",    "pos":Vector2(0.88, 0.50), "hides":"power_core"},
	{"obj":"plant",    "pos":Vector2(0.02, 0.56), "hides":"left_arm"},
	{"obj":"crate",    "pos":Vector2(0.28, 0.78), "hides":"left_leg"},
	{"obj":"locker",   "pos":Vector2(0.63, 0.46), "hides":"right_leg"},
	{"obj":"rug",      "pos":Vector2(0.40, 0.90), "hides":""},
	{"obj":"bin",      "pos":Vector2(0.92, 0.84), "hides":""},
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
var checklist_rows: Dictionary = {} # part id -> {box: ColorRect, label: Label}
var checklist_header: Label
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
	stage.resized.connect(_layout_scene)
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

# A ColorRect anchored to a fraction of its parent, so it resizes with the room.
func _room_rect(parent: Control, l: float, t: float, r: float, b: float, color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_left = l; rect.anchor_top = t; rect.anchor_right = r; rect.anchor_bottom = b
	rect.offset_left = 0; rect.offset_top = 0; rect.offset_right = 0; rect.offset_bottom = 0
	parent.add_child(rect)

# A plain, empty classroom: a back wall, a floor, a daylit window and a door.
# Somewhere nicer to hunt than a black void, and it gives the parts a place to be.
func _add_room() -> void:
	var room := Control.new()
	room.name = "Room"
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(room)
	_room_rect(room, 0.0, 0.0,  1.0, 1.0,  Color(0.30, 0.33, 0.40))   # back wall
	_room_rect(room, 0.0, 0.62, 1.0, 0.64, Color(0.11, 0.12, 0.15))   # wall/floor seam
	_room_rect(room, 0.0, 0.64, 1.0, 1.0,  Color(0.17, 0.18, 0.22))   # floor
	# A window letting in daylight on the back wall.
	_room_rect(room, 0.60, 0.12,  0.86, 0.48,  Color(0.56, 0.69, 0.82))  # glass / light
	_room_rect(room, 0.728, 0.12, 0.738, 0.48, Color(0.30, 0.33, 0.40))  # vertical mullion
	_room_rect(room, 0.60, 0.295, 0.86, 0.305, Color(0.30, 0.33, 0.40))  # horizontal mullion
	# A door on the left wall.
	_room_rect(room, 0.07, 0.24, 0.21, 0.64, Color(0.23, 0.25, 0.31))    # door
	_room_rect(room, 0.185, 0.45, 0.197, 0.49, Color(0.62, 0.64, 0.70))  # knob
	# A soft wash of light from the window across the room.
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.12))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.73, 0.30)
	tex.fill_to = Vector2(1.2, 1.0)
	var glow := TextureRect.new()
	glow.texture = tex
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(glow)

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
	_add_room()
	var caption : Label = world.hud._label(
		"Six robot parts are hidden around this room. Search the furniture and decor —\nclick the painting, the shelf, the plant, a crate — and a part pops out if it's there.", 16)
	caption.add_theme_constant_override("line_spacing", 2)
	caption.position = Vector2(20, 12)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(caption)
	part_buttons.clear()
	for s in SPOTS:
		_spawn_spot(s.obj, s.pos, str(s.hides))
	var counter : Label = world.hud._label("", 18)
	counter.name = "Counter"
	counter.modulate = UI.CYAN
	counter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	counter.position = Vector2(20, -40)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(counter)
	_build_checklist()
	var go : Button = world.hud._button("Build the robot  ›", true)
	go.name = "Continue"
	go.disabled = true
	go.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	go.position = Vector2(-186, -52)
	go.pressed.connect(_build_beat2a)
	stage.add_child(go)
	_refresh_counter()
	_layout_scene()
	call_deferred("_layout_scene")

# A searchable room object (painting, shelf, plant…). Clicking it searches it;
# if a part is tucked there, the part pops out above it. Spots with no part just
# report "nothing here". The clickable Button is invisible; the art rides on top.
func _spawn_spot(obj: String, frac: Vector2, hides: String) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_meta("frac", frac)
	btn.set_meta("hides", hides)
	btn.set_meta("searched", false)
	btn.custom_minimum_size = _furniture_size(obj)
	btn.tooltip_text = "Search"
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art := _build_furniture(obj)
	art.name = "Art"
	btn.add_child(art)
	# Hovering highlights the object so it reads as searchable.
	btn.mouse_entered.connect(func():
		if not bool(btn.get_meta("searched")): art.modulate = Color(1.18, 1.18, 1.22, 1.0))
	btn.mouse_exited.connect(func():
		if not bool(btn.get_meta("searched")): art.modulate = BRIGHT)
	btn.pressed.connect(_on_search.bind(btn))
	stage.add_child(btn)
	if hides != "": part_buttons.append(btn)

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

func _furniture_size(obj: String) -> Vector2:
	match obj:
		"painting": return Vector2(96, 74)
		"clock":    return Vector2(62, 62)
		"shelf":    return Vector2(128, 96)
		"plant":    return Vector2(66, 100)
		"crate":    return Vector2(90, 74)
		"locker":   return Vector2(72, 124)
		"rug":      return Vector2(160, 48)
		"bin":      return Vector2(50, 66)
		_:          return Vector2(64, 64)

# A piece of room furniture/decor, built from flat colored rects.
func _build_furniture(obj: String) -> Control:
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz: Vector2 = _furniture_size(obj)
	g.custom_minimum_size = sz
	g.size = sz
	for r: Dictionary in _furniture_rects(obj):
		var rect := ColorRect.new()
		rect.color = r.color
		rect.position = r.pos
		rect.size = r.size
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(rect)
	return g

func _furniture_rects(obj: String) -> Array:
	match obj:
		"painting": return [
			{"pos":Vector2(0,0),   "size":Vector2(96,74), "color":Color(0.52,0.42,0.22)},   # frame
			{"pos":Vector2(6,6),   "size":Vector2(84,56), "color":Color(0.40,0.52,0.62)},   # sky
			{"pos":Vector2(6,46),  "size":Vector2(84,16), "color":Color(0.30,0.50,0.34)},   # hill
			{"pos":Vector2(64,12), "size":Vector2(16,16), "color":Color(0.90,0.80,0.45)}]   # sun
		"clock": return [
			{"pos":Vector2(0,0),   "size":Vector2(62,62), "color":Color(0.26,0.28,0.33)},   # rim
			{"pos":Vector2(6,6),   "size":Vector2(50,50), "color":Color(0.90,0.90,0.86)},   # face
			{"pos":Vector2(29,14), "size":Vector2(4,17),  "color":Color(0.20,0.20,0.24)},   # hand
			{"pos":Vector2(31,29), "size":Vector2(16,4),  "color":Color(0.20,0.20,0.24)},   # hand
			{"pos":Vector2(27,27), "size":Vector2(8,8),   "color":Color(0.20,0.20,0.24)}]   # hub
		"shelf": return [
			{"pos":Vector2(0,0),   "size":Vector2(128,96),"color":Color(0.42,0.31,0.21)},   # body
			{"pos":Vector2(0,30),  "size":Vector2(128,5), "color":Color(0.30,0.22,0.15)},   # shelf
			{"pos":Vector2(0,62),  "size":Vector2(128,5), "color":Color(0.30,0.22,0.15)},   # shelf
			{"pos":Vector2(8,6),   "size":Vector2(10,22), "color":Color(0.55,0.30,0.30)},   # books
			{"pos":Vector2(20,6),  "size":Vector2(9,22),  "color":Color(0.35,0.45,0.55)},
			{"pos":Vector2(31,6),  "size":Vector2(11,22), "color":Color(0.45,0.52,0.35)},
			{"pos":Vector2(96,6),  "size":Vector2(10,22), "color":Color(0.50,0.45,0.30)},
			{"pos":Vector2(10,38), "size":Vector2(9,20),  "color":Color(0.40,0.40,0.55)},
			{"pos":Vector2(22,38), "size":Vector2(11,20), "color":Color(0.55,0.40,0.35)}]
		"plant": return [
			{"pos":Vector2(8,34),  "size":Vector2(50,40), "color":Color(0.28,0.52,0.32)},   # bush
			{"pos":Vector2(16,10), "size":Vector2(34,36), "color":Color(0.33,0.58,0.37)},
			{"pos":Vector2(4,40),  "size":Vector2(22,26), "color":Color(0.24,0.46,0.28)},
			{"pos":Vector2(40,38), "size":Vector2(22,26), "color":Color(0.30,0.54,0.34)},
			{"pos":Vector2(16,72), "size":Vector2(34,28), "color":Color(0.55,0.33,0.24)},   # pot
			{"pos":Vector2(16,72), "size":Vector2(34,6),  "color":Color(0.33,0.20,0.15)}]   # soil
		"crate": return [
			{"pos":Vector2(0,6),   "size":Vector2(90,68), "color":Color(0.46,0.35,0.23)},   # body
			{"pos":Vector2(0,0),   "size":Vector2(90,10), "color":Color(0.33,0.24,0.16)},   # lid
			{"pos":Vector2(41,6),  "size":Vector2(8,68),  "color":Color(0.33,0.24,0.16)},   # plank
			{"pos":Vector2(0,34),  "size":Vector2(90,7),  "color":Color(0.33,0.24,0.16)}]   # plank
		"locker": return [
			{"pos":Vector2(0,0),   "size":Vector2(72,124),"color":Color(0.44,0.48,0.55)},   # body
			{"pos":Vector2(35,0),  "size":Vector2(3,124), "color":Color(0.28,0.31,0.37)},   # seam
			{"pos":Vector2(10,10), "size":Vector2(20,4),  "color":Color(0.28,0.31,0.37)},   # vents
			{"pos":Vector2(10,18), "size":Vector2(20,4),  "color":Color(0.28,0.31,0.37)},
			{"pos":Vector2(44,10), "size":Vector2(20,4),  "color":Color(0.28,0.31,0.37)},
			{"pos":Vector2(44,18), "size":Vector2(20,4),  "color":Color(0.28,0.31,0.37)},
			{"pos":Vector2(8,58),  "size":Vector2(10,18), "color":Color(0.26,0.29,0.34)},   # handle
			{"pos":Vector2(46,58), "size":Vector2(10,18), "color":Color(0.26,0.29,0.34)}]
		"rug": return [
			{"pos":Vector2(0,0),   "size":Vector2(160,48),"color":Color(0.46,0.27,0.30)},   # base
			{"pos":Vector2(8,8),   "size":Vector2(144,32),"color":Color(0.38,0.22,0.25)},   # inner
			{"pos":Vector2(0,20),  "size":Vector2(160,8), "color":Color(0.55,0.45,0.32)}]   # stripe
		"bin": return [
			{"pos":Vector2(4,10),  "size":Vector2(42,56), "color":Color(0.40,0.44,0.50)},   # body
			{"pos":Vector2(0,0),   "size":Vector2(50,12), "color":Color(0.28,0.31,0.37)},   # lid
			{"pos":Vector2(4,30),  "size":Vector2(42,4),  "color":Color(0.28,0.31,0.37)}]   # band
		_: return [
			{"pos":Vector2(0,0),   "size":Vector2(64,64), "color":Color(0.44,0.40,0.34)}]

func _on_search(btn: Button) -> void:
	if bool(btn.get_meta("searched")): return
	btn.set_meta("searched", true)
	var art: Control = btn.get_node_or_null("Art")
	var hides: String = str(btn.get_meta("hides"))
	if hides == "":
		if art != null: art.modulate = Color(0.72, 0.75, 0.82, 1.0)   # searched, dimmed
		_float_text(btn, "— nothing here —", UI.WHITE)
		_play_menu()
		return
	if art != null: art.modulate = Color(0.78, 0.82, 0.90, 1.0)
	found[hides] = true
	_reveal_part(btn, hides)
	_play_menu()
	_refresh_counter()

func _part_info(id: String) -> Dictionary:
	for p: Dictionary in PARTS:
		if p.id == id: return p
	return {"id": id, "name": id, "kind": "scrap"}

# Pop a recovered part out just above the object it was hidden in.
func _reveal_part(anchor: Button, id: String) -> void:
	var info: Dictionary = _part_info(id)
	var gsize: Vector2 = _glyph_size(str(info.kind))
	var wrap := Control.new()
	wrap.name = "Reveal_" + id
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.custom_minimum_size = gsize
	wrap.size = gsize
	wrap.position = Vector2((anchor.custom_minimum_size.x - gsize.x) * 0.5, -gsize.y - 18)
	anchor.add_child(wrap)
	var glyph := _build_glyph(str(info.kind))
	glyph.modulate = FOUND
	wrap.add_child(glyph)
	var tag := Label.new()
	tag.text = str(info.name)
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", UI.CYAN)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.position = Vector2(-6, gsize.y + 2)
	wrap.add_child(tag)
	wrap.pivot_offset = gsize * 0.5
	wrap.scale = Vector2(0.5, 0.5)
	wrap.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wrap, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(wrap, "modulate:a", 1.0, 0.28)

# A short message that floats up and fades from an object (e.g. "nothing here").
func _float_text(anchor: Control, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, -22)
	anchor.add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", -46.0, 0.9)
	tw.tween_property(label, "modulate:a", 0.0, 0.9)
	tw.set_parallel(false)
	tw.tween_callback(label.queue_free)

# The "find these" checklist in the top-right corner, ticked off as parts turn up.
func _build_checklist() -> void:
	checklist_rows = {}
	var box_panel := PanelContainer.new()
	box_panel.name = "Checklist"
	box_panel.add_theme_stylebox_override("panel", world.hud._panel_style())
	box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(box_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_panel.add_child(col)
	checklist_header = world.hud._label("FIND THESE PARTS", 15)
	checklist_header.modulate = UI.CYAN
	col.add_child(checklist_header)
	for p: Dictionary in PARTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(row)
		var tick := ColorRect.new()
		tick.custom_minimum_size = Vector2(14, 14)
		tick.color = Color(0.30, 0.33, 0.40)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tick)
		var name_l : Label = world.hud._label(str(p.name), 15)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_l)
		checklist_rows[p.id] = {"box": tick, "label": name_l}

func _refresh_checklist() -> void:
	for id: String in checklist_rows:
		var row: Dictionary = checklist_rows[id]
		var got: bool = found.has(id)
		row.box.color = UI.SUCCESS if got else Color(0.30, 0.33, 0.40)
		row.label.modulate = UI.SUCCESS if got else UI.WHITE
	if checklist_header != null:
		checklist_header.text = "FIND THESE PARTS   %d / %d" % [found.size(), PARTS.size()]

func _refresh_counter() -> void:
	var n: int = found.size()
	_refresh_checklist()
	var counter: Label = stage.get_node_or_null("Counter")
	if counter != null:
		counter.text = "Parts recovered:  %d / %d" % [n, PARTS.size()]
	var go: Button = stage.get_node_or_null("Continue")
	if go != null:
		go.disabled = n < PARTS.size()
		if not go.disabled:
			go.grab_focus()

# Place the scattered finds for the current stage size. Falls back to the panel
# size until the stage is measured, so the parts never pile up at the origin.
func _layout_scene() -> void:
	if beat != 1 or stage == null: return
	var area: Vector2 = stage.size
	if area.x <= 4 and panel != null:
		area = panel.size - Vector2(36, 150)
	if area.x <= 4: return
	for child in stage.get_children():
		if child is Button and child.has_meta("frac"):
			var frac: Vector2 = child.get_meta("frac")
			var sz: Vector2 = child.custom_minimum_size
			var pad := Vector2(80, 96)
			var origin := Vector2(pad.x, pad.y)
			var span := (area - pad * 2 - sz).max(Vector2(40, 40))
			child.position = origin + Vector2(frac.x * span.x, frac.y * span.y)
	var chk: Control = stage.get_node_or_null("Checklist")
	if chk != null:
		var w: float = maxf(chk.size.x, chk.get_combined_minimum_size().x)
		chk.position = Vector2(area.x - w - 16, 12)

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
