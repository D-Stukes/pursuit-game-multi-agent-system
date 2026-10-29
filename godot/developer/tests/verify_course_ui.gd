extends SceneTree
const Pilot = preload("res://developer/tests/CourseWorldPilot.gd")
var checks: int = 0
var failures: int = 0
var world: Node3D

func _initialize() -> void: call_deferred("run")
func check(label: String, success: bool) -> void:
	checks += 1
	if not success: failures += 1
	print("PASS " if success else "FAIL ",label)
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame
func key(code: Key) -> void:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)
func activate(button: Button) -> void:
	button.grab_focus();await process_frame;await key(KEY_ENTER)
func answer(id: String) -> void:
	await activate(world.sample_course.answers.filter(func(button: Button):return button.get_meta("answer_id")==id)[0])
func open_sample() -> void:
	await key(KEY_F3)
	await activate(world.hud.developer.sample_course_button)
	await frames()

func run() -> void:
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	var ui: Node = world.sample_course
	check("sample is an explicit hidden developer fixture",ui!=null and not ui.is_open and not ui.overlay.visible and not ui.available())
	await key(KEY_F3)
	check("sample button cannot skip normal arrival",world.hud.developer.sample_course_button.disabled)
	await key(KEY_F3)
	world.set_building_review_mode(true)
	check("review grants no course access",not ui.available() and not ui.open())
	world.set_building_review_mode(false)
	Pilot.prepare_arrival(world)
	check("fixture arrival still grants no course results",world.orchestrator.snapshot().stage=="mr_p_pending" and world.orchestrator.snapshot().course.question_id.is_empty())
	check("physical classroom alone cannot open sample",not ui.open())
	check("classroom laptop has an actual clear approach",Pilot.approach_computer(world).is_finite())
	await frames(6);await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	await frames(6)
	check("E enters existing purple room without course awards",world.computer_portal.inside and ui.available() and world.orchestrator.snapshot().stage=="mr_p_pending")
	if not world.computer_portal.inside: quit(1);return
	# First-open narrow layout exposed a deferred container-minimum race in render.
	root.size=Vector2i(800,600);root.content_scale_size=Vector2i(800,600);await frames(6)
	await open_sample()
	check("developer button starts sample with exclusive controls",ui.is_open and world.player.controls_locked and world.orchestrator.snapshot().interaction=="course" and world.orchestrator.snapshot().course.mode=="sample")
	if not ui.is_open: quit(1);return
	check("first narrow open keeps whole panel in view",Rect2(Vector2.ZERO,Vector2(800,600)).encloses(ui.panel.get_global_rect()))
	check("first narrow open keeps header and close reachable",ui.panel.get_global_rect().encloses(ui.disclaimer.get_global_rect()) and ui.panel.get_global_rect().encloses(ui.close_button.get_global_rect()))
	check("initial keyboard focus leaves the whole prompt visible",ui.scroll.scroll_vertical==0 and ui.scroll.get_global_rect().encloses(ui.prompt.get_global_rect()))
	check("sample labels and authoritative stats are visible",ui.disclaimer.text.contains("Lady D") and ui.status.text.contains("Energy 10 / 10") and ui.answers.size()==3)
	var provider_requests: int = world.npc_conversations.requests_started
	await answer("guess")
	check("first wrong UI answer costs one and rephrases",world.orchestrator.snapshot().course.energy==9 and world.orchestrator.snapshot().course.attempts==1 and ui.prompt.text.begins_with("First try"))
	check("wrong feedback has text and red semantic token",ui.notice.text.begins_with("Try again") and ui.notice.modulate==world.hud.ERROR)
	await answer("guess")
	check("second wrong UI answer offers stronger optional help",world.orchestrator.snapshot().course.energy==8 and ui.help_button.text=="Stronger sample help")
	var before: Dictionary = world.orchestrator.snapshot().course
	await activate(ui.help_button)
	check("hint click cannot award energy or completion",world.orchestrator.snapshot().course==before and ui.notice.text.begins_with("Sample hint"))
	for _index: int in range(8): await answer("guess")
	check("zero disables answers and leaves recovery available",world.orchestrator.snapshot().course.energy==0 and world.orchestrator.snapshot().course.attempts==10 and ui.answers.all(func(button: Button):return button.disabled) and ui.recovery_button.visible)
	check("zero recovery action fits the visible question area",ui.scroll.get_global_rect().encloses(ui.recovery_button.get_global_rect()) and not ui.answer_box.visible)
	await activate(ui.recovery_button)
	check("supportive recovery and both actions fit the narrow view",ui.scroll.get_global_rect().encloses(ui.recovery_confirm.get_global_rect()) and ui.scroll.get_global_rect().encloses(ui.recovery_decline.get_global_rect()) and not ui.prompt.visible and not ui.notice.visible)
	await activate(ui.recovery_decline)
	await activate(ui.recovery_button);await activate(ui.recovery_decline)
	check("declining recovery retains zero and unanswered task",world.orchestrator.snapshot().course.energy==0 and world.orchestrator.snapshot().course.attempts==10 and ui.recovery_button.visible)
	await activate(ui.recovery_button)
	before=world.orchestrator.snapshot().course
	await key(KEY_ESCAPE)
	check("Escape cancels recovery and returns control to room",not ui.is_open and not world.player.controls_locked and world.orchestrator.snapshot().interaction=="portal" and world.orchestrator.snapshot().course==before)
	await open_sample();await activate(ui.recovery_button);await activate(ui.recovery_confirm)
	check("shown confirmed recovery refills without resetting attempts",world.orchestrator.snapshot().course.energy==10 and world.orchestrator.snapshot().course.attempts==10 and world.orchestrator.snapshot().course.score==0)
	await key(KEY_F3)
	check("Settings interrupts sample without losing progress",world.hud.menu_open and not ui.is_open and world.orchestrator.snapshot().interaction=="menu")
	await activate(world.hud.developer.sample_course_button)
	check("reopening resumes the exact sample step",ui.is_open and world.orchestrator.snapshot().course.attempts==10)
	await answer("observe")
	check("correct answer advances immediately with green feedback",world.orchestrator.snapshot().course.question_id=="sample-decide" and world.orchestrator.snapshot().course.attempts==0 and world.orchestrator.snapshot().course.score==10 and ui.notice.modulate==world.hud.SUCCESS)
	await answer("decide");await answer("claim");await answer("verify")
	check("sample checkpoint awards once and returns to questions",world.orchestrator.snapshot().course.score==50 and world.orchestrator.snapshot().course.energy==10 and world.orchestrator.snapshot().course.question_id=="sample-return" and not world.orchestrator.snapshot().course.complete)
	for size: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=size;root.content_scale_size=size;await frames(6)
		check("sample panel fits "+str(size),Rect2(Vector2.ZERO,Vector2(size)).encloses(ui.panel.get_global_rect()))
		check("close action stays reachable "+str(size),ui.panel.get_global_rect().encloses(ui.close_button.get_global_rect()))
	await answer("return")
	check("verified required set reaches ending boundary while panel stays open",world.orchestrator.snapshot().stage=="ending_pending" and world.orchestrator.snapshot().course.score==60 and ui.answers.is_empty() and ui.prompt.text.contains("Close this panel"))
	check("sample never calls a provider or assembles the real robot",world.npc_conversations.requests_started==provider_requests and world.orchestrator.snapshot().course.robot_parts.is_empty())
	before=world.orchestrator.snapshot().course
	# This suite checks course close/travel; verify_ending covers automatic handoff.
	world.auto_play_ending=false
	await key(KEY_ESCAPE);world.go_location(0);await frames()
	check("travel preserves completed sample and closes its UI",not ui.is_open and not world.computer_portal.inside and world.orchestrator.snapshot().course==before)
	print("COURSE_UI_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
