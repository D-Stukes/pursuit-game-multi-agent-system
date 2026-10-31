extends Control
## Visual journey guide. The infographic landing is the front door; its icons are
## clickable and route into the live building map. Navigation stays read-only;
## Main owns modal input and movement locking.
signal close_requested
const UI=preload("res://game/GameHUD.gd")
const GUIDE_IMAGE:="res://assets/ui/journey_guide.png"
const IMAGE_SIZE:=Vector2(920,504)
# Clickable icon cells as fractions of the infographic (x,y,w,h in 0..1), plus the
# action each one performs. Tuned to the journey_guide.png layout.
const HOTSPOTS:={
 "start":{"rect":[0.195,0.20,0.165,0.26],"tip":"START — the building entrance"},
 "elevator":{"rect":[0.375,0.20,0.165,0.26],"tip":"ELEVATOR — play the shooter to go up"},
 "reception":{"rect":[0.565,0.20,0.185,0.26],"tip":"RECEPTION — the upstairs desk"},
 "checkin":{"rect":[0.775,0.20,0.205,0.26],"tip":"CHECK-IN — confirm your details"},
 "you":{"rect":[0.235,0.49,0.19,0.22],"tip":"YOU — your position on the map"},
 "destination":{"rect":[0.49,0.49,0.20,0.22],"tip":"DESTINATION — where to go next"},
 "zoom":{"rect":[0.77,0.49,0.215,0.22],"tip":"ZOOM & PAN — scroll to zoom, drag to pan"},
 "guide":{"rect":[0.16,0.76,0.18,0.22],"tip":"GUIDE [B] — you are reading it"},
 "map":{"rect":[0.37,0.76,0.17,0.22],"tip":"MAP [M] — open the building map"},
 "alt":{"rect":[0.565,0.76,0.18,0.22],"tip":"EXIT — close the guide"},
 "esc":{"rect":[0.775,0.76,0.195,0.22],"tip":"EXIT [Esc] — close the guide"},
}
var world: Node3D
var panel: PanelContainer
var column: VBoxContainer
var page: String="Objective"
var close_button: Button
var map_button: Button
var guide_view: Control
var image: TextureRect
var hotspots: Array[Button]=[]
var map_controls: HBoxContainer
var back_button: Button
var floor_buttons: Array[Button]=[]
var map: Control
var legend: Label
var zoom_buttons: Array[Button]=[]
var zoom_label: Label

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var dim:=ColorRect.new();dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.5);add_child(dim)
 panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",world.hud._panel_style());add_child(panel)
 column=VBoxContainer.new();column.add_theme_constant_override("separation",UI.GAP);panel.add_child(column)
 # Header: title + Map / Close.
 var header:=HBoxContainer.new();column.add_child(header)
 var title: Label=world.hud._label("JOURNEY GUIDE",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
 map_button=world.hud._button("Open map [M]",false);map_button.pressed.connect(func():show_page("Map"));header.add_child(map_button)
 close_button=world.hud._button("Close [Esc]",false);close_button.pressed.connect(func():close_requested.emit());header.add_child(close_button)
 # Landing: the infographic with clickable icon hotspots.
 guide_view=Control.new();guide_view.size_flags_vertical=Control.SIZE_EXPAND_FILL;guide_view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(guide_view)
 image=TextureRect.new();image.texture=load(GUIDE_IMAGE);image.stretch_mode=TextureRect.STRETCH_SCALE;guide_view.add_child(image)
 for id: String in HOTSPOTS:
  var spot: Button=Button.new();spot.flat=true;spot.focus_mode=Control.FOCUS_ALL
  spot.tooltip_text=str(HOTSPOTS[id].tip)
  spot.add_theme_stylebox_override("normal",_clear_style())
  spot.add_theme_stylebox_override("hover",_hover_style());spot.add_theme_stylebox_override("focus",_hover_style())
  spot.add_theme_stylebox_override("pressed",_hover_style())
  spot.pressed.connect(_activate.bind(id))
  image.add_child(spot);hotspots.append(spot)
 # Map view: floor + zoom controls, the live map, a legend, and a way back.
 map_controls=HBoxContainer.new();column.add_child(map_controls)
 back_button=world.hud._button("‹ Guide",false);back_button.pressed.connect(func():show_page("Objective"));map_controls.add_child(back_button)
 for id: int in [0,1]:
  var button: Button=world.hud._button("Ground floor" if id==0 else "Second floor",false);button.pressed.connect(func():map.show_floor(id);_sync_floor());map_controls.add_child(button);floor_buttons.append(button)
 var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_controls.add_child(spacer)
 for text: String in ["−","+","Fit map"]:
  var button: Button=world.hud._button(text,false);button.custom_minimum_size.x=36 if text!="Fit map" else 100
  button.tooltip_text="Zoom out" if text=="−" else "Zoom in" if text=="+" else "Fit the whole floor"
  button.pressed.connect(func():
   if text=="Fit map":map.fit_map()
   else:map.zoom_by(.8 if text=="−" else 1.25))
  map_controls.add_child(button);zoom_buttons.append(button)
 zoom_label=world.hud._label("100%",14);zoom_label.custom_minimum_size.x=48;map_controls.add_child(zoom_label)
 map=preload("res://game/BuildingMap.gd").new();map.world=world;map.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(map)
 map.view_changed.connect(func():zoom_label.text="%d%%"%roundi(map.view_zoom*100))
 legend=world.hud._label("",16);legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(legend)
 resized.connect(_fit);hide();_fit()

func _clear_style() -> StyleBoxEmpty:
 return StyleBoxEmpty.new()

func _hover_style() -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=Color(UI.CYAN,0.18);style.set_corner_radius_all(8)
 style.set_border_width_all(2);style.border_color=Color(UI.CYAN,0.9);return style

func _fit() -> void:
 if panel==null:return
 panel.position=Vector2(UI.EDGE,UI.EDGE);panel.size=size-Vector2(UI.EDGE*2,UI.EDGE*2)
 _layout_image()

## Size the infographic to a comfortable middle size and place the hotspots over it.
func _layout_image() -> void:
 if image==null or guide_view==null:return
 var avail: Vector2=guide_view.size
 if avail.x<=0:avail=panel.size
 var width: float=clampf(avail.x-8,560,1100)
 width=minf(width,(avail.y-8)*IMAGE_SIZE.x/IMAGE_SIZE.y)
 var display:=Vector2(width,width*IMAGE_SIZE.y/IMAGE_SIZE.x)
 image.size=display
 image.position=((avail-display)*0.5).max(Vector2.ZERO)
 for i in range(hotspots.size()):
  var id: String=HOTSPOTS.keys()[i]
  var r: Array=HOTSPOTS[id].rect
  hotspots[i].position=Vector2(r[0],r[1])*display
  hotspots[i].size=Vector2(r[2],r[3])*display

func open(selected: String="Objective") -> void:
 map.show_floor(1 if world.computer_portal.inside or world.player.global_position.y>3 else 0)
 show();show_page(selected)
 if selected=="Map":back_button.grab_focus()
 else:close_button.grab_focus()

func show_page(selected: String) -> void:
 page=selected
 var is_map: bool=page=="Map"
 guide_view.visible=not is_map
 map.visible=is_map;map_controls.visible=is_map;legend.visible=is_map
 map_button.disabled=is_map
 if is_map:
  _sync_floor();map.grab_focus()
 else:
  _layout_image()
 call_deferred("_fit")

## Handle a click on one of the infographic icons.
func _activate(id: String) -> void:
 match id:
  "guide":return   # already on the guide
  "alt","esc":close_requested.emit();return
  "map","zoom":
   map.show_floor(1 if world.player.global_position.y>3 or world.computer_portal.inside else 0)
   _show_map("ZOOM & PAN — scroll to zoom, drag to pan, Fit map resets the view." if id=="zoom" else "")
  "you":
   map.show_floor(1 if world.player.global_position.y>3 or world.computer_portal.inside else 0)
   _show_map("YOU — the cyan arrow is your position and the way your camera faces.")
  "destination":
   var target: Dictionary=map.destination()
   map.show_floor(int(target.floor))
   _show_map("DESTINATION — the gold ring marks where to go next: "+str(target.label)+".")
  "start":
   map.show_floor(0);_show_map("START — you begin at the building entrance on the ground floor.")
  "elevator":
   map.show_floor(0);_show_map("ELEVATOR — reach the elevators on the ground floor and press E to play the shooter.")
  "reception":
   map.show_floor(1);_show_map("RECEPTION — upstairs, turn toward the reception desk.")
  "checkin":
   map.show_floor(1);_show_map("CHECK-IN — use the Check-In Console upstairs to confirm your details.")

func _show_map(caption: String) -> void:
 show_page("Map")
 if caption!="":legend.text=caption

func _sync_floor() -> void:
 for i in range(floor_buttons.size()):floor_buttons[i].disabled=map.floor_id==i
 if not is_instance_valid(world.computer_portal):return
 var here: int=1 if world.player.global_position.y>3 else 0
 var target: Dictionary=map.destination()
 legend.text="Cyan: you · Gold: destination · Top: rear of building\nScroll: zoom · Drag: pan · Fit map: reset"
 if world.computer_portal.inside:legend.text+="\nYou are in the purple room, outside this building map. Return through the computer pad."
 elif here!=map.floor_id:legend.text+="\nYou are on the other floor."
 if int(target.floor)!=map.floor_id:legend.text+="\nCurrent destination: "+str(target.label)+" on the "+("ground floor" if int(target.floor)==0 else "second floor")+"."
