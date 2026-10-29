extends Button
## Native scalable pipe art and Button input/focus; no texture or per-tile process.

const Rules = preload("res://game/PipePuzzleState.gd")
const TILE := Color("153b39")
const SHELL := Color("9ba9af")
const CONDUCTOR := Color("bb8b40")
const POWER := Color("ffdb83")
const FOCUS := Color("35e0ff")
var mask: int = 10:
	set(value):
		mask = value
		queue_redraw()
var powered: bool = false:
	set(value):
		powered = value
		queue_redraw()
var hinted: bool = false:
	set(value):
		hinted = value
		queue_redraw()

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		event.connect(queue_redraw)

func _draw() -> void:
	var edge: float = minf(size.x, size.y)
	var center: Vector2 = size * 0.5
	var rect := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	var plate := StyleBoxFlat.new()
	plate.bg_color = TILE.lightened(0.08) if is_hovered() and not disabled else TILE
	plate.border_color = Color("436461")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(6)
	draw_style_box(plate, rect)
	var ends: Array[Vector2] = []
	for i: int in range(4):
		if mask & (1 << i): ends.append(center + Vector2(Rules.DIRECTIONS[i]) * edge * 0.5)
	var points := PackedVector2Array()
	if ends.size() == 2:
		for i: int in range(25):
			var t: float = i / 24.0
			points.append((1 - t) * (1 - t) * ends[0] + 2 * (1 - t) * t * center + t * t * ends[1])
		draw_polyline(points, Color("081c20"), edge * .28, true)
		draw_polyline(points, Color("50666f"), edge * .22, true)
		draw_polyline(points, SHELL, edge * .16, true)
		draw_polyline(points, Color("293a41"), edge * .10, true)
		draw_polyline(points, POWER if powered else CONDUCTOR, edge * .045, true)
		if powered: draw_polyline(points, Color("fff4c9"), edge * .015, true)
	# Connector collars identify where neighboring tile ports must meet.
	for end: Vector2 in ends:
		var inward: Vector2 = (center - end).normalized()
		var across := Vector2(-inward.y, inward.x)
		var at: Vector2 = end + inward * edge * .12
		draw_line(at - across * edge * .105, at + across * edge * .105, Color("293a41"), edge * .06, true)
		draw_line(at - across * edge * .10, at + across * edge * .10, SHELL, edge * .025, true)
	for at: Vector2 in [Vector2(9, 9), size - Vector2(9, 9)]:
		draw_circle(at, 2.0, Color("59766d"))
		draw_line(at - Vector2(1, 1), at + Vector2(1, 1), Color("112b30"), 1)
	if has_focus() or hinted:
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = FOCUS if has_focus() else POWER
		outline.set_border_width_all(3)
		outline.set_corner_radius_all(6)
		draw_style_box(outline, rect)
