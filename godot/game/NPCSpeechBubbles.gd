extends Control
## Speech bubbles over people's heads for NPC-to-NPC talk (overheard scenes and the reception
## exchange). Talk with the player stays in the bottom panel and caption. One bubble per speaker,
## pinned above the head on screen and kept inside its edges; hidden while the head is behind the
## camera or a wall. Sits under every other HUD element. While the layer is hidden (a menu, an
## overlay or the player's own conversation) the bubbles wait, just as the scenes do.
const GameHUD = preload("res://game/GameHUD.gd")
const MIN_WIDTH: float = 96.0
const MAX_WIDTH: float = 300.0
const TAIL: float = 10.0
const EDGE: float = 12.0
## How far above the top of the head the tail points.
const ABOVE_HEAD: float = .05
const FADE: float = .15
var world: Node3D
var bubbles: Array[Dictionary] = []
var history: Array[String] = [] # "Name: line" for every bubble shown; tests read this.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Show a line over someone's head for a few seconds, replacing whatever they were saying.
func show_line(body: Node3D, speaker: String, text: String, seconds: float) -> void:
	clear(body)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = world.hud._panel_style()
	style.set_corner_radius_all(10)
	style.content_margin_left = 12;style.content_margin_right = 12
	style.content_margin_top = 7;style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var name_label: Label = world.hud._label(speaker,13)
	name_label.add_theme_color_override("font_color",GameHUD.CYAN)
	column.add_child(name_label)
	var line: Label = world.hud._label(text,17)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(line)
	# Short lines get a snug bubble; long ones wrap at MAX_WIDTH.
	var font: Font = line.get_theme_font("font")
	var widest: float = maxf(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x,font.get_string_size(speaker,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)
	line.custom_minimum_size.x = clampf(ceilf(widest)+2,MIN_WIDTH,MAX_WIDTH)
	# Wrap at that width now, so the bubble's first size is already the right height.
	line.size.x = line.custom_minimum_size.x
	var tail := Polygon2D.new()
	tail.color = style.bg_color
	root.add_child(tail)
	root.modulate.a = 0
	root.create_tween().tween_property(root,"modulate:a",1.0,FADE)
	var record: Variant = body.get("record")
	var height: float = float(record.get("height",1.75)) if record is Dictionary else 1.75
	var bubble: Dictionary = {"body":body,"root":root,"panel":panel,"tail":tail,"text":text,"remaining":seconds,"height":height}
	bubbles.append(bubble)
	history.append(speaker+": "+text)
	panel.reset_size()
	_place(bubble,get_viewport().get_camera_3d())

## What someone's bubble says right now ("" when they have none).
func text_for(body: Node3D) -> String:
	for bubble: Dictionary in bubbles:
		if bubble.body == body: return bubble.text
	return ""

## Whether someone's bubble is on screen right now (not behind the camera or a wall).
func shown_for(body: Node3D) -> bool:
	for bubble: Dictionary in bubbles:
		if bubble.body == body: return visible and bubble.root.visible
	return false

## Remove one person's bubble, or everyone's.
func clear(body: Node3D = null) -> void:
	for bubble: Dictionary in bubbles.duplicate():
		if body == null or bubble.body == body: _remove(bubble)

func _remove(bubble: Dictionary) -> void:
	bubbles.erase(bubble)
	var root: Control = bubble.root
	var fade: Tween = root.create_tween()
	fade.tween_property(root,"modulate:a",0.0,FADE)
	fade.tween_callback(root.queue_free)

func _process(delta: float) -> void:
	if not visible: return
	var camera: Camera3D = get_viewport().get_camera_3d()
	for bubble: Dictionary in bubbles.duplicate():
		bubble.remaining -= delta
		if bubble.remaining <= 0 or not is_instance_valid(bubble.body) or not bubble.body.is_visible_in_tree():
			_remove(bubble);continue
		_place(bubble,camera)

func _place(bubble: Dictionary, camera: Camera3D) -> void:
	var root: Control = bubble.root
	var head: Vector3 = bubble.body.global_position+Vector3.UP*(bubble.height+ABOVE_HEAD)
	root.visible = camera != null and not camera.is_position_behind(head) and _in_sight(camera.global_position,head)
	if not root.visible: return
	var point: Vector2 = camera.unproject_position(head)
	bubble.panel.reset_size()
	var box: Vector2 = bubble.panel.size
	var at := Vector2(point.x-box.x*.5,point.y-box.y-TAIL)
	at.x = clampf(at.x,EDGE,maxf(EDGE,size.x-box.x-EDGE))
	at.y = clampf(at.y,EDGE,maxf(EDGE,size.y-box.y-TAIL-EDGE))
	root.position = at.round()
	# The tail points at the head, or as close as the bubble's edge allows when it is pinned.
	var tip: float = clampf(point.x-at.x,14,box.x-14)
	bubble.tail.polygon = PackedVector2Array([Vector2(tip-8,box.y),Vector2(tip+8,box.y),Vector2(tip,box.y+TAIL)])

## Walls and floors (layer 1) hide a bubble; people do not.
func _in_sight(from: Vector3, to: Vector3) -> bool:
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
	return hit.is_empty()
