extends SceneTree
## Exercise the same disabled-tool path used by nondebug builds, without an export.
var checks: int=0
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, success: bool) -> void:
	checks+=1
	if not success:failures+=1
	print("PASS " if success else "FAIL ",label)

func frames(count: int=5) -> void:
	for _i: int in range(count):await physics_frame

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)

func run() -> void:
	var world: Node3D=load("res://Main.tscn").instantiate()
	world.enable_developer_tools=false
	root.add_child(world);await frames(12)
	check("main scene is the configured game entry",ProjectSettings.get_setting("application/run/main_scene")=="res://Main.tscn")
	check("game title uses approved Journey name",ProjectSettings.get_setting("application/config/name")=="Pursuit: The Journey")
	check("player-only HUD instantiates no developer component",world.hud.developer==null and not world.hud.debug_mode)
	check("player-only HUD still displays shared progress",world.hud.progress_display.is_visible_in_tree() and world.hud.progress_display.metrics.text=="Energy 10 / 10" and world.hud.progress_display.activity.text=="Activities: not started")
	check("player-only game loads no sample course UI",world.sample_course==null and not ResourceLoader.has_cached("res://developer/course/SampleCourse.gd"))
	world.hud.set_debug_mode(true)
	check("player-only HUD cannot enter developer view",not world.hud.debug_mode)
	world.set_building_review_mode(true)
	check("world rejects bypass without developer capability",not world.building_review_mode and world.entrance_gate.collision_layer==4)
	world.orchestrator.set_review(true)
	check("coordinator also rejects disabled developer bypass",not world.orchestrator.entrance_allowed() and not world.orchestrator.ascent_allowed())
	await key(KEY_F3)
	check("F3 does not open disabled tools",not world.hud.menu_open and not world.hud.debug_mode)
	await key(KEY_ESCAPE)
	check("player Settings still opens",world.hud.menu_open and not world.hud.controls_label.visible)
	check("Settings contains no developer entry",world.hud.menu_panel.find_children("*","Button",true,false).filter(func(button: Button):return button.text.contains("Developer") or button.text.contains("Bypass")).is_empty())
	for viewport: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);world.hud.size=viewport;await frames()
		check("player-only Settings fits "+str(viewport),Rect2(Vector2.ZERO,viewport).encloses(world.hud.menu_panel.get_global_rect()))
	await key(KEY_ESCAPE)
	var before: Vector3=world.player.global_position
	await key(KEY_3)
	check("numbered developer travel is unavailable",world.player.global_position.distance_to(before)<.03)
	preload("res://developer/tests/KeypadTestPilot.gd").approach(world);await frames();await key(KEY_E)
	check("normal entrance game still works without tools",world.entrance_puzzle.visible and world.orchestrator.snapshot().interaction=="entrance")
	await key(KEY_ESCAPE)
	check("player-only run earns no fabricated progress",not world.orchestrator.gates_earned() and world.orchestrator.snapshot().stage=="entrance")
	print("DEVELOPER_DISABLED_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
