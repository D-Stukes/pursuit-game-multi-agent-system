extends Control
## Navigation is read-only. Main owns modal input and movement locking.
signal close_requested
const UI=preload("res://game/GameHUD.gd")
var world: Node3D
var panel: PanelContainer
var column: VBoxContainer
var page: String="Objective"
var tabs: Array[Button]=[]
var close_button: Button
var copy: Label
var scroll: ScrollContainer
var map_controls: HBoxContainer
var floor_buttons: Array[Button]=[]
var map: Control
var legend: Label
var zoom_buttons: Array[Button]=[]
var zoom_label: Label
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var dim:=ColorRect.new();dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.5);add_child(dim)
 panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",world.hud._panel_style());add_child(panel)
 panel.minimum_size_changed.connect(func():call_deferred("_fit"))
 column=VBoxContainer.new();column.add_theme_constant_override("separation",UI.GAP);panel.add_child(column)
 var header:=HBoxContainer.new();column.add_child(header)
 var title: Label=world.hud._label("JOURNEY GUIDE",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
 close_button=world.hud._button("Close [Esc]",false);close_button.pressed.connect(func():close_requested.emit());header.add_child(close_button)
 var nav:=HBoxContainer.new();column.add_child(nav)
 for id: String in ["Objective","Controls","Map"]:
  var tab: Button=world.hud._button(id,false);tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.pressed.connect(func():show_page(id));nav.add_child(tab);tabs.append(tab)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
 copy=world.hud._label("",18);copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(copy)
 map_controls=HBoxContainer.new();column.add_child(map_controls)
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
 var focus: Array[Control]=[close_button]
 focus.append_array(tabs);focus.append_array(floor_buttons);focus.append_array(zoom_buttons);focus.append(map)
 for i in range(focus.size()):
  focus[i].focus_next=focus[i].get_path_to(focus[(i+1)%focus.size()]);focus[i].focus_previous=focus[i].get_path_to(focus[(i-1+focus.size())%focus.size()])
 resized.connect(_fit);hide();_fit()
func _fit() -> void:
 if panel==null:return
 panel.position=Vector2(UI.EDGE,UI.EDGE);panel.size=size-Vector2(UI.EDGE*2,UI.EDGE*2)
func open(selected: String="Objective") -> void:
 map.show_floor(1 if world.computer_portal.inside or world.player.global_position.y>3 else 0);show();show_page(selected);close_button.grab_focus()
func show_page(selected: String) -> void:
 page=selected
 for tab: Button in tabs:tab.disabled=tab.text==selected
 var is_map: bool=page=="Map"
 scroll.visible=not is_map;map.visible=is_map;map_controls.visible=is_map;legend.visible=is_map
 if page=="Controls":copy.text=UI.CONTROLS+"\n\nWASD and arrow keys move your student. The cyan arrow on the map shows your position and camera direction. The gold ring marks your current destination.\n\nWalk forward to climb the stairs, or follow the ramp on the right. Approach the entrance panel to start its puzzle automatically. At the elevator, press E to play the required shooter.\n\nFor people and computers, approach and use the single prompt at the bottom of the screen. Press E to interact. Press C near a chair to sit; touching a chair does not make you sit."
 else:copy.text="CURRENT OBJECTIVE\n"+world.orchestrator.objective()+"\n\n"+_objective_help()+"\n\nMap legend\nCyan arrow: you and your camera direction.\nGold ring: current destination.\nFloor buttons: inspect either floor without moving your student.\nScroll or use + / − to zoom. Drag to pan. Fit map resets the view.\n\nB opens this guide. M opens the current-floor map. Esc closes the guide. Developer Tools remain in Pause."
 scroll.scroll_vertical=0
 _sync_floor();call_deferred("_fit")
func _objective_help() -> String:
 match str(world.orchestrator.snapshot().stage):
  "entrance":return "Approach the panel left of the closed entrance. Connect IN to OUT, test the circuit and enter the four-digit code. The remaining boards are optional."
  "elevator":return "Walk up the stairs or right ramp, then follow the hallway to the elevators. Press E at the lower cab to play the shooter. Win to unlock the second floor."
  "check_in_pending":return "Take the elevator upstairs, turn toward Reception and use the Check-In Console. Confirm your details to continue."
  "classroom_pending":return "The Classroom entrance is beside Reception. Follow the introduction into the classroom."
  "course_active":return "Complete the current activities in the purple room. Use its marked return pad to go back to your classroom computer. The purple room is outside the building map."
  _:return "Use a classroom computer to visit the purple room. The map does not complete activities or unlock doors."
func _sync_floor() -> void:
 for i in range(floor_buttons.size()):floor_buttons[i].disabled=map.floor_id==i
 if not is_instance_valid(world.computer_portal):return
 var here: int=1 if world.player.global_position.y>3 else 0
 var target: Dictionary=map.destination()
 legend.text="Cyan: you · Gold: destination · Top: rear of building\nScroll: zoom · Drag: pan · Fit map: reset"
 if world.computer_portal.inside:legend.text+="\nYou are in the purple room, outside this building map. Return through the computer pad."
 elif here!=map.floor_id:legend.text+="\nYou are on the other floor."
 if int(target.floor)!=map.floor_id:legend.text+="\nCurrent destination: "+str(target.label)+" on the "+("ground floor" if int(target.floor)==0 else "second floor")+"."
