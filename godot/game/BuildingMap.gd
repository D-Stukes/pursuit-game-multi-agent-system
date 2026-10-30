extends Control
## Orthographic floor textures and markers share the renderer's exact world bounds.
const UI=preload("res://game/GameHUD.gd")
const WIDTH: float=52.0
const DEPTH: float=31.2
const CENTER:=Vector2(1,6.325)
const GROUND_DEPTH: float=45.0
const GROUND_CENTER:=Vector2(1,-2.5)
signal view_changed
var view_zoom: float=1.0
var view_pan:=Vector2.ZERO
var dragging: bool=false
var world: Node3D
var floor_id: int=0
var ground: Texture2D
var upper: Texture2D
var labels: Array=[]
var image_rect:=Rect2()
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true;focus_mode=Control.FOCUS_ALL
 ground=load("res://assets/maps/ground.png");upper=load("res://assets/maps/upper.png")
 resized.connect(queue_redraw)
func show_floor(value: int) -> void:
 floor_id=clampi(value,0,1);fit_map()
func _process(_delta: float) -> void:
 if is_visible_in_tree():queue_redraw()
func depth() -> float:return GROUND_DEPTH if floor_id==0 else DEPTH
func center() -> Vector2:return GROUND_CENTER if floor_id==0 else CENTER
func _base_size() -> Vector2:
 var width: float=minf(size.x,size.y*WIDTH/depth())
 return Vector2(width,width*depth()/WIDTH)
func _clamp_pan() -> void:
 var limit: Vector2=((_base_size()*view_zoom-size)/2).max(Vector2.ZERO)
 view_pan=view_pan.clamp(-limit,limit)
func fit_map() -> void:
 view_zoom=1;view_pan=Vector2.ZERO;dragging=false;queue_redraw();view_changed.emit()
func zoom_by(factor: float, anchor: Vector2=Vector2.INF) -> void:
 var old: float=view_zoom;view_zoom=clampf(view_zoom*factor,1,4)
 if anchor==Vector2.INF:anchor=size/2
 view_pan=anchor-size/2-(anchor-size/2-view_pan)*(view_zoom/old)
 _clamp_pan();queue_redraw();view_changed.emit()
func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   zoom_by(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8,event.position);accept_event()
  elif event.button_index==MOUSE_BUTTON_LEFT:
   dragging=event.pressed
   if dragging:grab_focus()
   accept_event()
 elif event is InputEventMouseMotion and dragging:
  view_pan+=event.relative;_clamp_pan();queue_redraw();accept_event()
 elif event is InputEventKey and event.pressed:
  if event.keycode in [KEY_PLUS,KEY_EQUAL,KEY_KP_ADD]:zoom_by(1.25);accept_event()
  elif event.keycode in [KEY_MINUS,KEY_KP_SUBTRACT]:zoom_by(.8);accept_event()
  elif event.keycode==KEY_0:fit_map();accept_event()
func point(at: Vector3) -> Vector2:
 var middle: Vector2=center()
 return image_rect.position+Vector2((at.x-(middle.x-WIDTH/2))/WIDTH,((middle.y+depth()/2)+at.z)/depth())*image_rect.size
func destination() -> Dictionary:
 var state: Dictionary=world.orchestrator.snapshot()
 match str(state.stage):
  "entrance":return {"point":world.entrance_keypad.global_position,"floor":0,"label":"ENTRANCE PANEL"}
  "elevator":return {"point":world.LIFT_GROUND,"floor":0,"label":"ELEVATOR GAME"}
  "check_in_pending":return {"point":world.check_in.computer.point,"floor":1,"label":"CHECK IN"}
  "classroom_pending","ending_pending":return {"point":world.approved_layout.anchor("classroom_door"),"floor":1,"label":"CLASSROOM"}
  _:
   var classroom: Vector3=world.approved_layout.anchor("classroom_spawn")
   var closest: Vector3=classroom;var distance: float=INF
   for device: Dictionary in world.computer_portal.computers:
    if device.id=="Reception_monitor":continue
    var candidate: float=device.point.distance_squared_to(classroom)
    if candidate<distance:distance=candidate;closest=device.point
   return {"point":closest,"floor":1,"label":"CLASSROOM COMPUTER"}
func _draw() -> void:
 var texture: Texture2D=ground if floor_id==0 else upper
 if texture==null:return
 _clamp_pan()
 var image_size: Vector2=_base_size()*view_zoom
 image_rect=Rect2((size-image_size)/2+view_pan,image_size)
 draw_texture_rect(texture,image_rect,false)
 var font:=ThemeDB.fallback_font
 var font_size: int=clampi(int(image_rect.size.x/60),14,20)
 labels=[{"text":"ENTRANCE","at":Vector3(0,0,5.6)},{"text":"STAIRS / RAMP","at":Vector3(3.4,0,-2.5)},{"text":"ELEVATORS","at":Vector3(-2,0,-12.5)},{"text":"STREET","at":Vector3(9,0,15)}] if floor_id==0 else [
  {"text":"QUIET ROOMS","at":Vector3(-21.5,5,-15.4)}, {"text":"COMMONS","at":Vector3(-16,5,-12.4)}, {"text":"KITCHEN","at":Vector3(-8.8,5,-13.7)},
  {"text":"HALLWAY 2","at":Vector3(-13,5,-6.2)}, {"text":"ROOM 1 / 2","at":Vector3(-3.9,5,-8)}, {"text":"RESTROOMS","at":Vector3(-4.3,5,-16.6)},
  {"text":"ELEVATORS","at":Vector3(-.2,5,-12)}, {"text":"RECEPTION","at":Vector3(3.8,5,-6.8)}, {"text":"CLASSROOM","at":Vector3(-7.5,5,1.5)},
  {"text":"ROBOT","at":Vector3(-16,5,1.8)}, {"text":"OTHER ROOMS","at":Vector3(16,5,-3)}]
 for item: Dictionary in labels:
  var at: Vector2=point(item.at)
  var extent: Vector2=font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
  draw_style_box(_label_style(),Rect2(at-Vector2(extent.x/2,extent.y/2),extent+Vector2(10,6)))
  draw_string(font,at+Vector2(-extent.x/2+5,extent.y/3),item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,UI.WHITE)
 if world==null:return
 var target: Dictionary=destination()
 if int(target.floor)==floor_id:
  var at: Vector2=point(target.point);draw_arc(at,12,0,TAU,32,UI.DESTINATION,3,true);draw_circle(at,4,UI.DESTINATION)
 var on_floor: bool=(world.player.global_position.y>3.0)==(floor_id==1)
 if on_floor and not world.computer_portal.inside:
  var at: Vector2=point(world.player.global_position)
  var visible: Rect2=image_rect.intersection(Rect2(Vector2.ZERO,size)).grow(-18)
  if visible.has_area():
   var off_view: bool=not visible.has_point(at)
   var original: Vector2=at
   at=at.clamp(visible.position,visible.end)
   var facing: Vector3=-world.player.camera.global_basis.z
   var heading: float=atan2(facing.z,facing.x)
   if off_view:
    heading=(original-at).angle()
    var label_at: Vector2=(at+Vector2(-45,-20)).clamp(Vector2(4,18),size-Vector2(96,8))
    draw_string(font,label_at,"YOU · OFF VIEW",HORIZONTAL_ALIGNMENT_LEFT,-1,11,UI.CYAN)
   var polygon:=PackedVector2Array([Vector2(13,0),Vector2(-8,-7),Vector2(-5,0),Vector2(-8,7)])
   for i in range(polygon.size()):polygon[i]=polygon[i].rotated(heading)+at
   draw_circle(at,15,UI.NAVY);draw_colored_polygon(polygon,UI.CYAN)
func _label_style() -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=UI.NAVY;style.set_corner_radius_all(3);return style
