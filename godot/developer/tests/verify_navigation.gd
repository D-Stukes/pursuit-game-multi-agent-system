extends SceneTree
## Real keyboard modal entry, projection, physical sidelights and cinematic lifecycle.
const NPCPilot=preload("res://developer/tests/NPCTestPilot.gd")
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
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
 Input.parse_input_event(event);await frames(2);event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(2)
func ray_clear(x: float) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(x,1.4,4.3),Vector3(x,1.4,5.3),1)
 return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func run() -> void:
 world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
 var guide: Control=world.guide
 check("both former entrance slits have glass collision",not ray_clear(-1.38) and not ray_clear(1.38))
 world.entrance_doors.set_open(true);await frames(3)
 check("extended panes keep the open doorway clear",ray_clear(-.6) and ray_clear(.6) and not ray_clear(-1.38) and not ray_clear(1.38))
 world.entrance_doors.set_open(false)
 var before: Dictionary=world.orchestrator.snapshot();var origin: Vector3=world.player.global_position
 await key(KEY_B)
 check("B opens guide and locks movement",guide.visible and guide.page=="Objective" and world.player.controls_locked and world.hud.menu_open and not world.hud.menu_overlay.visible)
 check("guide uses the authoritative current objective",guide.copy.text.contains(world.orchestrator.objective()))
 await key(KEY_M);await process_frame
 check("M switches to current-floor map",guide.page=="Map" and guide.map.floor_id==0 and guide.map.visible)
 for i in range(10):
  await key(KEY_TAB)
  check("Tab remains inside guide",guide.is_ancestor_of(root.gui_get_focus_owner()))
 guide.map.show_floor(1);guide._sync_floor();await process_frame
 check("floor inspection does not move the player",world.player.global_position.distance_to(origin)<.01 and guide.legend.text.contains("other floor"))
 var center: Vector2=guide.map.point(Vector3(1,0,-6.325))
 check("world centre maps to texture centre",center.distance_to(guide.map.image_rect.get_center())<.01)
 check("map textures use the expected orthographic aspect",absf(guide.map.upper.get_width()/float(guide.map.upper.get_height())-52.0/31.2)<.001)
 var projection:=SubViewport.new();projection.size=Vector2i(1400,840);projection.world_3d=World3D.new();root.add_child(projection)
 var camera:=Camera3D.new();projection.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=52
 camera.look_at_from_position(Vector3(1,45,-6.325),Vector3(1,5.05,-6.325),Vector3.FORWARD);await frames(3)
 var aligned: bool=true
 for location: Vector3 in [world.ENTRANCE_POINT,world.LIFT_UPPER,world.approved_layout.anchor("classroom_spawn"),world.approved_layout.anchor("commons_spawn")]:
  var mapped: Vector2=(guide.map.point(location)-guide.map.image_rect.position)/guide.map.image_rect.size*Vector2(1400,840)
  aligned=aligned and mapped.distance_to(camera.unproject_position(location))<.1
 check("live markers match the rendering camera at actual building anchors",aligned)
 projection.queue_free()

 for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
  guide.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);guide.size=resolution
  for page: String in ["Map","Controls","Objective"]:
   guide.show_page(page);await frames(5);await process_frame
   var bounds:=Rect2(Vector2.ZERO,resolution)
   check(page+" fits "+str(resolution),bounds.encloses(guide.panel.get_global_rect()) and guide.panel.get_global_rect().encloses(guide.close_button.get_global_rect()))
 await key(KEY_ESCAPE)
 check("Esc resumes without changing gate or energy state",not guide.visible and not world.hud.menu_open and not world.player.controls_locked and world.orchestrator.snapshot().gates==before.gates and world.orchestrator.snapshot().course==before.course)
 world.go_location(1);await frames(4);await key(KEY_M)
 check("M upstairs opens second-floor map",guide.visible and guide.map.floor_id==1)
 world.set_menu_open(false);world.set_menu_open(true);world.hud.guide_menu_button.pressed.emit();await frames()
 check("pause menu opens the same guide",guide.visible and not world.hud.menu_overlay.visible)
 world.set_menu_open(false)
 NPCPilot.approach(world,"ReceptionA");world.npc_conversations.refresh_remaining=0;await frames(3)
 check("NPC uses one contextual prompt with no floating E label",not world.npc_conversations.selected.is_empty() and world.hud.prompt_label.text.contains("talk") and world.npc_conversations.actors.all(func(actor: Dictionary):return not actor.label.visible))
 check("computer and entrance floating labels are hidden",not world.entrance_keypad.prompt.visible and world.computer_portal.computers.all(func(device: Dictionary):return not device.label.visible))
 var prefs: Node=root.get_node("GamePreferences");var old_motion: bool=prefs.reduced_motion;prefs.reduced_motion=false
 origin=world.player.global_position;before=world.orchestrator.snapshot()
 check("intro replay claims one modal",world.intro.start() and world.player.controls_locked and world.orchestrator.snapshot().interaction=="intro")
 var initial: Vector3=world.intro.camera.global_position
 world.intro.elapsed=9;world.intro._update_scene()
 check("panoramic camera moves before text",world.intro.camera.global_position.distance_to(initial)>1 and not world.intro.window.visible)
 world.intro.elapsed=18;world.intro._update_scene()
 check("panorama ends at the entrance before text",world.intro.window.visible and world.intro.camera.global_position.distance_to(world.LOCATIONS[0]+Vector3(0,2.2,4.3))<.01)
 check("replay upstairs creates only a visual student without teleporting",is_instance_valid(world.intro.preview_student) and world.player.global_position.distance_to(origin)<.01)
 world.intro.finish(false)
 while world.intro.active:await process_frame
 check("skip restores original camera and controls without rewards",world.player.camera.current and not world.player.controls_locked and world.player.global_position.distance_to(origin)<.01 and world.orchestrator.snapshot().gates==before.gates and world.orchestrator.snapshot().reserve_pellets==before.reserve_pellets)
 prefs.reduced_motion=true;world.intro.start();await frames()
 var still: Transform3D=world.intro.camera.global_transform;await frames(15)
 check("reduced motion skips camera travel and uses static text",world.intro.static_text and world.intro.window.visible and world.intro.camera.global_transform.is_equal_approx(still))
 world.intro.finish(false)
 while world.intro.active:await process_frame
 world.set_menu_open(true,true);await frames()
 var preview: Button=world.hud.developer.intro_preview_button
 check("Developer Tools offers the intro panorama",preview.is_visible_in_tree() and not preview.disabled)
 preview.pressed.emit();await frames()
 check("developer preview closes tools and plays the panorama despite reduced motion",world.intro.active and not world.hud.menu_open and not world.intro.static_text and not world.intro.window.visible)
 world.intro.finish(false)
 while world.intro.active:await process_frame
 check("developer preview restores controls without rewards",world.player.camera.current and not world.player.controls_locked and world.orchestrator.snapshot().gates==before.gates and world.orchestrator.snapshot().reserve_pellets==before.reserve_pellets)
 prefs.reduced_motion=old_motion
 print("NAVIGATION_RESULT checks=",checks," failures=",failures)
 world.queue_free();await process_frame;quit(1 if failures else 0)
