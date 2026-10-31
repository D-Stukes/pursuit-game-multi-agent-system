extends RefCounted
## Fixed input pilot inside the persistent review process. No arbitrary scripts.
const Setup = preload("res://developer/tests/CourseWorldPilot.gd")
var host: SceneTree
var world: Node3D
var failures: Array[String] = []
var captures: Array[String] = []
var layouts: Array[Dictionary] = []
var prefix: String

func frames(count: int = 4) -> void:
	for _index: int in range(count): await host.physics_frame
func key(code: Key) -> void:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await host.process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await host.process_frame;await frames(2)
func activate(button: Button) -> void:
	button.grab_focus();await host.process_frame;await key(KEY_ENTER)
func check(success: bool, message: String) -> bool:
	if not success: failures.append(message)
	return success
func answer(id: String) -> bool:
	var buttons: Array = world.sample_course.answers.filter(func(button: Button):return button.get_meta("answer_id")==id)
	if not check(buttons.size()==1,"Missing sample choice "+id): return false
	await activate(buttons[0]);return true
func capture(label: String) -> void:
	# Forced draw: a covered or background macOS window never posts a frame.
	await frames();RenderingServer.force_draw()
	if world.sample_course.is_open:
		var ui: Node = world.sample_course
		var viewport: Rect2 = host.root.get_visible_rect()
		layouts.append({"capture":label,"viewport":str(viewport),"panel":str(ui.panel.get_global_rect()),"close":str(ui.close_button.get_global_rect()),"status":str(ui.status.get_global_rect())})
		check(viewport.encloses(ui.panel.get_global_rect()),"Rendered panel outside viewport: "+label)
		check(viewport.encloses(ui.close_button.get_global_rect()) and viewport.encloses(ui.status.get_global_rect()),"Rendered status/close clipped: "+label)
		if ui.prompt.is_visible_in_tree(): check(ui.scroll.get_global_rect().encloses(ui.prompt.get_global_rect()),"Rendered prompt clipped: "+label)
		if ui.recovery_button.is_visible_in_tree(): check(ui.scroll.get_global_rect().encloses(ui.recovery_button.get_global_rect()),"Recovery action below visible scroll area: "+label)
		if ui.recovery_box.is_visible_in_tree(): check(ui.scroll.get_global_rect().encloses(ui.recovery_confirm.get_global_rect()) and ui.scroll.get_global_rect().encloses(ui.recovery_decline.get_global_rect()),"Recovery choices clipped: "+label)
	var path: String = prefix+label+".png"
	if check(host.root.get_texture().get_image().save_png(path)==OK,"Screenshot failed: "+label): captures.append(path)
func open_sample() -> bool:
	await key(KEY_F3);await activate(world.hud.developer.sample_course_button);await frames()
	return check(world.sample_course.is_open,"Sample did not open through the developer button")

func run(tree: SceneTree) -> Dictionary:
	host=tree;world=host.world
	prefix="res://.godot/playtest/course-"+str(host.request_id)+"-"
	world.frame_budget_enabled=false;Engine.max_fps=60
	if not check(world.npc_conversations.client.provider=="local","Course proof requires a local-only review session"): return finish()
	Setup.prepare_arrival(world)
	if not check(Setup.approach_computer(world).is_finite(),"No classroom laptop approach"): return finish()
	world.player.set_controls_active(true)
	await frames(6);await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	await frames(6)
	if not check(world.computer_portal.inside,"Computer E did not enter purple room"): return finish()
	host.root.size=Vector2i(800,600);host.root.content_scale_size=Vector2i(800,600);await frames(6)
	await key(KEY_F3);await capture("developer-menu-800")
	await activate(world.hud.developer.sample_course_button)
	if not check(world.sample_course.is_open,"Sample panel did not open"): return finish()
	await capture("question-800")
	host.root.size=Vector2i(1280,720);host.root.content_scale_size=Vector2i(1280,720);await frames(6)
	await capture("question-wide")
	if not await answer("guess"): return finish()
	check(world.orchestrator.snapshot().course.energy==9 and world.orchestrator.snapshot().course.attempts==1,"First error did not rephrase/cost one")
	await capture("first-error")
	if not await answer("guess"): return finish()
	check(world.sample_course.help_button.text=="Stronger sample help","Second error did not offer stronger help")
	await activate(world.sample_course.help_button);await capture("second-error-help")
	for _index: int in range(8):
		if not await answer("guess"): return finish()
	check(world.orchestrator.snapshot().course.energy==0 and world.sample_course.recovery_button.visible,"Zero did not offer recovery")
	await capture("zero-energy")
	await activate(world.sample_course.recovery_button);await capture("supportive-recovery")
	await activate(world.sample_course.recovery_decline)
	check(world.orchestrator.snapshot().course.energy==0 and world.orchestrator.snapshot().course.attempts==10,"Declined recovery changed energy/attempts")
	await capture("recovery-declined")
	await activate(world.sample_course.recovery_button);await key(KEY_ESCAPE)
	check(not world.sample_course.is_open and not world.player.controls_locked,"Escape did not cancel sample recovery")
	if not await open_sample(): return finish()
	await activate(world.sample_course.recovery_button);await activate(world.sample_course.recovery_confirm)
	check(world.orchestrator.snapshot().course.energy==10 and world.orchestrator.snapshot().course.attempts==10,"Recovery did not retain attempts/refill energy")
	await capture("recovered")
	if not await answer("observe"): return finish()
	check(world.orchestrator.snapshot().course.score==10 and world.orchestrator.snapshot().course.attempts==0,"Correct answer did not advance/reset attempts")
	await capture("question-advanced")
	if not await answer("decide"): return finish()
	await capture("challenge-placeholder")
	if not await answer("claim") or not await answer("verify"): return finish()
	check(world.orchestrator.snapshot().course.score==50 and not world.orchestrator.snapshot().course.complete,"Checkpoint prematurely finished remaining questions")
	await capture("returned-to-questions")
	if not await answer("return"): return finish()
	check(world.orchestrator.snapshot().stage=="ending_pending" and world.orchestrator.snapshot().course.score==60,"Required sample path did not verify")
	await capture("sample-complete")
	check(world.npc_conversations.requests_started==0,"Sample course used provider work")
	check(world.orchestrator.snapshot().course.robot_parts.is_empty(),"Sample changed the real robot parts")
	return finish()

func finish() -> Dictionary:
	if not failures.is_empty() and world.sample_course!=null: world.sample_course.close()
	world.frame_budget_enabled=true;world._apply_frame_budget(host.root.has_focus())
	var proof: Dictionary = {"passed":failures.is_empty(),"failures":failures,"engine_pid":OS.get_process_id(),
		"earlier_gates_and_arrival":"controller fixture setup, not a player-input playthrough",
		"course_input":"normal E / F3 / focused Enter / Escape","sample_only":true,"provider_calls":world.npc_conversations.requests_started,
		"captures":captures,"layouts":layouts,"final":world.orchestrator.snapshot(),"source_hashes":{}}
	for path: String in ["game/Main.gd","game/GameHUD.gd","game/CourseAdapter.gd","game/GameOrchestrator.gd","game/SessionState.gd","game/SessionEvent.gd","developer/DeveloperTools.gd","developer/course/SampleCourse.gd","developer/course/sample-course.json","developer/tests/CourseWorldPilot.gd","developer/tests/CourseReviewPilot.gd","developer/tests/live_review.gd"]:
		proof.source_hashes[path] = FileAccess.get_sha256("res://"+path)
	var file := FileAccess.open(prefix+"receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof,"  "));file.close()
	proof["receipt"] = prefix+"receipt.json"
	return proof
