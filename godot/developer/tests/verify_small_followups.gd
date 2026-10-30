extends SceneTree
## Isolated preferences plus real map, chair, collision and explicit classroom skip flows.
const GatePilot=preload("res://developer/tests/verify_check_in.gd")
const Event=preload("res://game/SessionEvent.gd")
const ClassroomRules=preload("res://game/ClassroomState.gd")
var world: Node3D
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func frames(count: int=5) -> void:
 for i in range(count):await physics_frame
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func key(code: Key) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
 Input.parse_input_event(e);await frames(2);e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await frames(2)
func wait_sit(state: StringName) -> bool:
 var end: int=Time.get_ticks_msec()+6000
 while Time.get_ticks_msec()<end:
  if world.player.sit_state==state:return true
  await process_frame
 return false
func run() -> void:
 var prefs: Node=root.get_node("GamePreferences")
 var previous: Dictionary={"path":prefs.settings_path,"extra":prefs.extra_hints,"motion":prefs.reduced_motion,"voice":prefs.speak_choices,"seen":prefs.intro_seen}
 DirAccess.make_dir_recursive_absolute("res://.godot/playtest")
 prefs.settings_path="res://.godot/playtest/extra-hints-fixture.cfg"
 prefs.extra_hints=false
 world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
 world.hud.hint_timer.stop();world.hud.hint_panel.hide()
 var fresh: Node=load("res://game/GamePreferences.gd").new()
 check("extra hints default off in a fresh preference instance",not fresh.extra_hints);fresh.free()
 world.set_menu_open(true);world.hud._show_page("Display");await frames()
 check("Display exposes the saved extra-hints toggle",world.hud.extra_hint_toggle.is_visible_in_tree() and not world.hud.extra_hint_toggle.button_pressed)
 world.hud.extra_hint_toggle.button_pressed=true;world.set_menu_open(false);await frames()
 check("enabled hints explain the current objective during play",world.hud.hint_panel.visible and world.hud.hint_label.text.contains("first board") and world.hud.hint_label.text.contains("M: map"))
 var restored: Node=load("res://game/GamePreferences.gd").new();restored.settings_path=prefs.settings_path;root.add_child(restored)
 check("extra hints survive a preference reload without changing other choices",restored.extra_hints and restored.reduced_motion==previous.motion and restored.speak_choices==previous.voice and restored.intro_seen==previous.seen)
 restored.queue_free()
 world.open_guide("Map");await frames()
 check("guide hides extra hints and owns mouse input",not world.hud.hint_panel.visible and world.player.controls_locked)
 var map: Control=world.guide.map
 var bounds: Dictionary=world.approved_layout.manifest.street_review_limits
 var covered: bool=true
 for x: float in [float(bounds.min_x),float(bounds.max_x)]:
  for depth: float in [float(bounds.min_depth),float(bounds.max_depth)]:covered=covered and map.image_rect.has_point(map.point(Vector3(x,0,-depth)))
 check("ground map covers every corner of the actual walkable street",covered)
 world.player.teleport_to(Vector3(0,0,18));await frames()
 check("the former missing street marker is inside the floor map",map.image_rect.has_point(map.point(world.player.global_position)))
 var session: Dictionary=world.orchestrator.snapshot()
 world.guide.zoom_buttons[1].pressed.emit();await frames()
 check("zoom enlarges the map and updates its percentage",map.view_zoom>1 and world.guide.zoom_label.text=="125%")
 map.zoom_by(100);await frames()
 check("zoom is bounded",is_equal_approx(map.view_zoom,4))
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;map._gui_input(down)
 var drag:=InputEventMouseMotion.new();drag.relative=Vector2(20,30);map._gui_input(drag);await frames()
 check("drag pans a zoomed map",map.view_pan.length()>0)
 map.grab_focus();await key(KEY_MINUS)
 check("focused map supports keyboard zoom",map.view_zoom<4)
 world.guide.zoom_buttons[2].pressed.emit();await frames()
 check("Fit resets zoom and pan without moving or awarding progress",is_equal_approx(map.view_zoom,1) and map.view_pan==Vector2.ZERO and world.orchestrator.snapshot().gates==session.gates and world.orchestrator.snapshot().course==session.course)
 for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
  world.guide.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);world.guide.size=resolution
  for page: String in ["Map","Controls","Objective"]:
   world.guide.show_page(page);await frames(5);await process_frame
   var rect:=Rect2(Vector2.ZERO,resolution)
   check(page+" fits narrow/wide UI "+str(resolution),rect.encloses(world.guide.panel.get_global_rect()) and world.guide.panel.get_global_rect().encloses(world.guide.close_button.get_global_rect()))
   if page=="Map":check("zoom controls fit "+str(resolution),world.guide.panel.get_global_rect().encloses(world.guide.map_controls.get_global_rect()))
 world.set_menu_open(false);prefs.set_extra_hints(false);await frames()
 check("turning extra hints off restores the compact HUD",not world.hud.hint_panel.visible)
 world.player.teleport_to(Vector3(0,0,6.7));world.player.set_controls_active(true);await frames(30)
 await key(KEY_C)
 check("C cannot sit in the open street",world.player.sit_state==&"" and world.hud.hint_label.text.contains("free chair"))
 check("seat discovery uses actual imported chair surfaces",world.player.chairs.seats.size()>20)
 world.player.teleport_to(Vector3(-9.1,5.07,-.9354),PI/2);await frames(20)
 var stand_origin: Vector3=world.player.global_position
 var seat: Dictionary=world.player.chairs.nearest()
 check("a reachable same-floor chair can be selected",not seat.is_empty())
 await key(KEY_C)
 check("C anchors the student at that chair",world.player.sit_state==&"entering" and Vector2(world.player.global_position.x-seat.point.x,world.player.global_position.z-seat.point.z).length()<.01)
 check("sit animation reaches its seated loop",await wait_sit(&"sitting"))
 var seated: Vector3=world.player.global_position
 Input.action_press("walk_forward");await frames(20);Input.action_release("walk_forward")
 check("seated body does not get pushed out by chair collision",world.player.global_position.distance_to(seated)<.01)
 await key(KEY_C)
 check("standing returns to clear floor beside the chair",await wait_sit(&"") and world.player.global_position.distance_to(stand_origin)<.1)
 # Real blocked line of sight must prevent sitting through a partition.
 var blocker:=StaticBody3D.new();blocker.collision_layer=1;blocker.collision_mask=0
 var box:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.1,2,2);box.shape=shape;blocker.add_child(box);world.add_child(blocker)
 blocker.global_position=(stand_origin+Vector3(seat.point.x,stand_origin.y,seat.point.z))/2+Vector3.UP
 if absf(seat.point.z-stand_origin.z)>absf(seat.point.x-stand_origin.x):blocker.rotation.y=PI/2
 await frames()
 var reachable: Dictionary=world.player.chairs.nearest()
 check("a chair behind a partition cannot be selected",reachable.is_empty() or reachable.id!=seat.id)
 blocker.queue_free();await frames()
 await key(KEY_C);await wait_sit(&"sitting")
 var obstruction:=StaticBody3D.new();obstruction.collision_layer=1;obstruction.collision_mask=0
 var obstacle:=CollisionShape3D.new();var obstacle_shape:=BoxShape3D.new();obstacle_shape.size=Vector3(.5,1.8,.5);obstacle.shape=obstacle_shape;obstruction.add_child(obstacle);world.add_child(obstruction)
 obstruction.global_position=stand_origin+Vector3.UP*.9;await frames()
 await key(KEY_C)
 check("blocked standing spot uses another clear floor point",await wait_sit(&"") and world.player.global_position.distance_to(stand_origin)>.3)
 obstruction.queue_free();await frames()

 world.go_location(0);await frames()
 var sequence: Node=world.classroom_sequence
 check("Skip cannot bypass gates or classroom entry",not sequence.skip() and not sequence.state.skip_remaining())
 GatePilot.solve_gates(world);world.go_location(1);await frames()
 world.orchestrator.claim("check_in");world.check_in.state.start_photo("Skip Fixture");world.check_in.state.take_photo();world.check_in.state.confirm()
 world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.CHECK_IN_CONFIRMED));world.orchestrator.release("check_in")
 sequence.start();check("Skip cannot bypass the doorway walk",not sequence.skip() and not sequence.state.skipped)
 var deadline: int=Time.get_ticks_msec()+6000
 while sequence.active and sequence.phase!="stand_up" and Time.get_ticks_msec()<deadline:await physics_frame
 check("Skip appears after collision-checked classroom entry",sequence.active and sequence.phase=="stand_up" and sequence.skip_button.is_visible_in_tree())
 world.set_menu_open(true);check("paused presentation cannot be skipped",not sequence.skip());world.set_menu_open(false)
 var course: Dictionary=world.orchestrator.snapshot().course
 await key(KEY_SPACE)
 check("Space skips remaining presentation and restores camera/control",not sequence.active and world.player.camera.current and not world.player.controls_locked and world.orchestrator.snapshot().arrival.classroom_complete)
 check("skip evidence is explicit rather than fabricated watched beats",sequence.state.skipped and sequence.state.presented==["entered"] and world.orchestrator.snapshot().log.any(func(entry: Dictionary):return bool(entry.details.get("presentation_skipped",false))))
 check("Skip grants no course energy or score",world.orchestrator.snapshot().course==course)
 var revision: int=world.orchestrator.revision();sequence.skip()
 check("repeat Skip is inert",world.orchestrator.revision()==revision)
 prefs.settings_path=previous.path;prefs.extra_hints=previous.extra;prefs.reduced_motion=previous.motion;prefs.speak_choices=previous.voice;prefs.intro_seen=previous.seen
 print("SMALL_FOLLOWUPS_RESULT checks=",checks," failures=",failures)
 world.queue_free();await process_frame;quit(1 if failures else 0)
