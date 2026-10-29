extends "res://developer/tests/CourseReviewPilot.gd"
## Fixed shared-state HUD proof; course content and earlier arrival are fixtures.
const SocialSetup = preload("res://developer/tests/NPCTestPilot.gd")
var fixture_hud: Control

func capture(label: String) -> void:
	await frames(6);await RenderingServer.frame_post_draw
	var hud: Control = fixture_hud if fixture_hud!=null else world.hud
	var display: Control = hud.progress_display
	var viewport: Rect2 = host.root.get_visible_rect()
	check(viewport.encloses(hud.title_panel.get_global_rect()) and viewport.encloses(hud.settings_button.get_global_rect()),"HUD header/settings clipped: "+label)
	check(hud.title_panel.get_global_rect().encloses(display.metrics.get_global_rect()) and hud.title_panel.get_global_rect().encloses(display.activity.get_global_rect()),"HUD values clipped: "+label)
	if hud.developer!=null and hud.developer.banner_panel.visible: check(viewport.encloses(hud.developer.banner_panel.get_global_rect()),"Bypass banner clipped")
	if hud.hint_panel.visible: check(hud.hint_panel.get_global_rect().position.y>hud.title_panel.get_global_rect().end.y,"Hint overlaps progress HUD")
	if fixture_hud==null and world.sample_course.is_open: check(viewport.encloses(world.sample_course.panel.get_global_rect()),"Sample overlay clipped")
	layouts.append({"capture":label,"viewport":str(viewport),"header":str(hud.title_panel.get_global_rect()),"metrics":display.metrics.text,"activities":display.activity.text,"meter_value":display.meter.value,"meter_max":display.meter.max_value})
	var path: String = prefix+label+".png"
	if check(host.root.get_texture().get_image().save_png(path)==OK,"Screenshot failed: "+label): captures.append(path)

func show_hud(label: String) -> void:
	if world.sample_course.is_open: await key(KEY_ESCAPE)
	await capture(label)

func run(tree: SceneTree) -> Dictionary:
	host=tree;world=host.world;prefix="res://.godot/playtest/progress-"+str(host.request_id)+"-"
	world.frame_budget_enabled=false;Engine.max_fps=60
	if not check(world.npc_conversations.client.provider=="local","HUD proof requires local-only review"): return finish()
	host.root.size=Vector2i(800,600);host.root.content_scale_size=Vector2i(800,600)
	await capture("baseline-800")
	# Explicit standalone projection fixture, never a write to game progress.
	var before: Dictionary = world.orchestrator.snapshot().course
	fixture_hud=load("res://game/GameHUD.gd").new();fixture_hud.developer_tools_allowed=false
	host.root.add_child(fixture_hud);world.hud.hide()
	fixture_hud.floor_label.text="HUD layout fixture"
	fixture_hud.set_objective("Verify long instructions remain readable, then return to the classroom for the assessment and advancement presentation")
	fixture_hud.set_progress({"course":{"energy":3,"maximum_energy":7,"score":1234567890123,"mode":"sample","required_questions":["a","b"],"required_challenges":["c","d"],"completed_questions":["a"],"completed_challenges":["c"],"complete":false}})
	await capture("held-out-layout-800")
	host.root.size=Vector2i(1280,720);host.root.content_scale_size=Vector2i(1280,720);await capture("held-out-layout-wide")
	fixture_hud.queue_free();fixture_hud=null;world.hud.show()
	check(world.orchestrator.snapshot().course==before,"Held-out projection fixture changed game progress")
	host.root.size=Vector2i(800,600);host.root.content_scale_size=Vector2i(800,600)
	if not check(SocialSetup.approach(world,"BuilderCompanion").is_finite(),"No Builder approach"): return finish()
	world.player.set_controls_active(true);await frames();await key(KEY_E)
	check(world.npc_conversations.dialogue.visible,"Conversation overlay did not open")
	await capture("conversation-overlay-800");await key(KEY_ESCAPE)
	Setup.prepare_arrival(world)
	if not check(Setup.approach_computer(world).is_finite(),"No clear computer approach"): return finish()
	world.player.set_controls_active(true);await frames(6);await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	await frames(6)
	if not check(world.computer_portal.inside,"E did not enter purple world") or not await open_sample(): return finish()
	await capture("sample-overlay-800")
	if not await answer("guess"): return finish()
	await show_hud("first-error-800")
	check(world.hud.progress_display.metrics.text=="Energy 9 / 10 · Score 0","Wrong-answer energy is not shared")
	if not await open_sample(): return finish()
	for _index: int in range(9):
		if not await answer("guess"): return finish()
	await show_hud("zero-energy-800")
	check(world.hud.progress_display.meter.value==0,"Zero-energy meter did not empty")
	if not await open_sample(): return finish()
	await activate(world.sample_course.recovery_button);await activate(world.sample_course.recovery_confirm)
	await show_hud("recovered-800")
	if not await open_sample() or not await answer("observe"): return finish()
	await show_hud("one-activity-800")
	host.root.size=Vector2i(1280,720);host.root.content_scale_size=Vector2i(1280,720)
	await capture("one-activity-wide")
	if not await open_sample() or not await answer("decide") or not await answer("verify"): return finish()
	await show_hud("checkpoint-wide")
	if not await open_sample() or not await answer("return"): return finish()
	await show_hud("complete-wide")
	host.root.size=Vector2i(800,600);host.root.content_scale_size=Vector2i(800,600)
	await capture("complete-800")
	world.set_building_review_mode(true);await capture("complete-bypass-800")
	world.set_building_review_mode(false)
	await key(KEY_ESCAPE);await capture("settings-800");await key(KEY_ESCAPE)
	await key(KEY_F3);await capture("developer-tools-800")
	check(world.hud.developer.stats_label.text.contains("FPS:") and world.hud.developer.stats_label.text.contains("Position:"),"Developer readout not ready after display update")
	await key(KEY_F3)
	check(world.npc_conversations.requests_started==0,"HUD proof called a provider")
	check(world.orchestrator.snapshot().course.score==60 and world.orchestrator.snapshot().stage=="ending_pending","HUD changed final progress")
	return finish()

func finish() -> Dictionary:
	if world.sample_course.is_open: world.sample_course.close()
	world.frame_budget_enabled=true;world._apply_frame_budget(host.root.has_focus())
	var proof: Dictionary = {"passed":failures.is_empty(),"failures":failures,"engine_pid":OS.get_process_id(),"provider_calls":world.npc_conversations.requests_started,
		"setup":"earlier gates/arrival are controller fixtures; current sample content is not Lady D's course; held-out-layout captures project an isolated labelled snapshot without changing shared state",
		"input":"normal E / F3 / focused Enter / Escape; common HUD shown with sample panel closed",
		"captures":captures,"layouts":layouts,"final":world.orchestrator.snapshot(),"source_hashes":{}}
	for path: String in ["game/Main.gd","game/GameHUD.gd","game/ProgressHUD.gd","game/GameOrchestrator.gd","game/SessionState.gd","game/CourseAdapter.gd","game/NPCDialoguePanel.gd","developer/course/SampleCourse.gd","developer/course/sample-course.json","developer/tests/NPCTestPilot.gd","developer/tests/CourseWorldPilot.gd","developer/tests/CourseReviewPilot.gd","developer/tests/ProgressHUDReviewPilot.gd","developer/tests/live_review.gd"]:
		proof.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open(prefix+"receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof,"  "));file.close()
	proof.receipt=prefix+"receipt.json"
	return proof
