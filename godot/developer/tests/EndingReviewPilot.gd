extends "res://developer/tests/CourseReviewPilot.gd"
## Real UI input in one persistent process; earlier arrival remains explicit setup.
var checks:int=0
var provider_calls:int=0
func verify(ok:bool,label:String) -> void:
	checks+=1;check(ok,label)
func phase(target:String) -> bool:
	for _i:int in range(900):
		if world.ending_sequence.active and world.ending_sequence.state.phase==target: return true
		await host.process_frame
	return check(false,"Ending never reached "+target)
func capture(label:String) -> void:
	# Forced draw: a covered or background macOS window never posts a frame.
	await frames(4);RenderingServer.force_draw()
	var viewport:Rect2=host.root.get_visible_rect()
	var ending:Node=world.ending_sequence
	layouts.append({"capture":label,"viewport":str(viewport),"ending_panel":str(ending.panel.get_global_rect()),"panel_minimum":str(ending.panel.get_combined_minimum_size())})
	if ending.active and not world.hud.menu_open and ending.panel.visible:
		verify(viewport.encloses(ending.panel.get_global_rect()),"Ending panel clipped "+label)
		for control:Control in [ending.heading,ending.message,ending.metrics,ending.action]:
			if control.is_visible_in_tree(): verify(ending.panel.get_global_rect().encloses(control.get_global_rect()),"Ending content clipped "+label)
	if world.hud.menu_open:
		verify(viewport.encloses(world.hud.restart_panel.get_global_rect() if world.hud.restart_dialog_open else world.hud.menu_panel.get_global_rect()),"Settings clipped "+label)
	var path:String=prefix+label+".png"
	if check(host.root.get_texture().get_image().save_png(path)==OK,"Capture failed "+label): captures.append(path)
func wait_restart(old_session:String) -> void:
	for _i:int in range(240):
		if is_instance_valid(host.world) and host.world.ready_for_test and host.world.orchestrator.snapshot().session_id!=old_session:
			world=host.world;world.frame_budget_enabled=false;Engine.max_fps=60;await frames(8);return
		await host.process_frame
	check(false,"Restart did not complete in existing host")
func run(tree:SceneTree) -> Dictionary:
	host=tree;world=host.world;prefix="res://.godot/playtest/ending-"+str(host.request_id)+"-"
	world.frame_budget_enabled=false;Engine.max_fps=60
	if not check(world.npc_conversations.client.provider=="local","Ending proof requires local-only mode"): return finish_ending()
	var pid:int=OS.get_process_id()
	host.root.size=Vector2i(800,600);host.root.content_scale_size=Vector2i(800,600);await frames(8)
	var before:Dictionary=world.orchestrator.snapshot()
	var origin:Vector3=world.player.global_position
	var view:Vector3=world.player.camera_pivot.rotation
	await key(KEY_F3);await capture("preview-menu-800")
	await activate(world.hud.developer.ending_preview_button)
	if not await phase("results"): return finish_ending()
	await capture("preview-results-800")
	host.root.size=Vector2i(1280,720);host.root.content_scale_size=Vector2i(1280,720)
	await capture("preview-results-wide")
	await activate(world.hud.settings_button)
	var elapsed:float=world.ending_sequence.state.elapsed
	await capture("preview-settings-paused")
	verify(is_equal_approx(elapsed,world.ending_sequence.state.elapsed),"Settings advanced preview")
	await activate(world.hud.resume_button)
	if not await phase("assessment"): return finish_ending()
	await capture("preview-assessment")
	if not await phase("celebration"): return finish_ending()
	await capture("preview-l3")
	if not await phase("complete"): return finish_ending()
	await capture("preview-end")
	verify(not world.orchestrator.snapshot().ending.presented,"Preview awarded an ending receipt")
	await activate(world.ending_sequence.action)
	verify(not world.ending_sequence.active and world.player.global_position.distance_to(origin)<.01 and world.player.camera_pivot.rotation.is_equal_approx(view) and world.orchestrator.snapshot().course==before.course and world.orchestrator.snapshot().gates==before.gates,"Preview did not restore street run")
	Setup.prepare_arrival(world)
	if not check(Setup.approach_computer(world).is_finite(),"No classroom computer approach"): return finish_ending()
	await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	await frames(6)
	var return_origin:Vector3=world.computer_portal.return_position
	origin=world.player.global_position
	await key(KEY_F3);await activate(world.hud.developer.ending_preview_button)
	if not await phase("assessment"): return finish_ending()
	await key(KEY_ESCAPE)
	verify(world.computer_portal.inside and world.computer_portal.return_position==return_origin and world.player.global_position.distance_to(origin)<.01 and not world.ending_sequence.active,"Purple preview did not restore portal origin")
	await capture("purple-preview-return")
	if not await open_sample(): return finish_ending()
	for id:String in ["observe","decide","verify","return"]:
		if not await answer(id): return finish_ending()
	verify(world.orchestrator.snapshot().stage=="ending_pending" and not world.ending_sequence.active,"Ending began before sample closed")
	await capture("verified-sample-before-ending")
	await key(KEY_ESCAPE)
	if not await phase("results"): return finish_ending()
	verify(not world.ending_sequence.preview and not world.computer_portal.inside,"Verified handoff did not return to classroom")
	await capture("normal-results-wide")
	await key(KEY_ESCAPE)
	elapsed=world.ending_sequence.state.elapsed
	await activate(world.hud.restart_button);await capture("normal-restart-confirmation")
	verify(is_equal_approx(elapsed,world.ending_sequence.state.elapsed),"Restart confirmation advanced ending")
	await key(KEY_ESCAPE);await activate(world.hud.resume_button)
	if not await phase("assessment"): return finish_ending()
	await capture("normal-assessment")
	if not await phase("celebration"): return finish_ending()
	await capture("normal-l3-wide")
	host.root.size=Vector2i(800,600);host.root.content_scale_size=Vector2i(800,600);await capture("normal-l3-800")
	if not await phase("complete"): return finish_ending()
	await capture("normal-end-800")
	verify(world.orchestrator.snapshot().ending.presented and world.orchestrator.snapshot().course.score==60,"Normal ordered ending receipt or results missing")
	provider_calls+=world.npc_conversations.requests_started
	var session:String=world.orchestrator.snapshot().session_id
	await activate(world.ending_sequence.action);await wait_restart(session)
	verify(OS.get_process_id()==pid and world.orchestrator.snapshot().session_id!=session and not world.orchestrator.snapshot().gates.entrance and world.orchestrator.snapshot().course.score==0,"Play Again failed to create fresh run in same process")
	await capture("play-again-fresh-run")
	await key(KEY_F3);await activate(world.hud.developer.bypass_toggle);await key(KEY_ESCAPE)
	session=world.orchestrator.snapshot().session_id
	await key(KEY_ESCAPE);await activate(world.hud.restart_button);await capture("restart-confirmation-800")
	await key(KEY_ESCAPE)
	verify(world.orchestrator.snapshot().session_id==session and world.hud.menu_open,"Cancel restarted run")
	await activate(world.hud.restart_button);await activate(world.hud.restart_accept);await wait_restart(session)
	verify(OS.get_process_id()==pid and world.orchestrator.snapshot().session_id!=session and not world.building_review_mode and world.entrance_gate.collision_layer==4,"Settings restart retained old session or bypass")
	await capture("restart-fresh-run")
	verify(provider_calls==0 and world.npc_conversations.requests_started==0,"Ending review used a provider")
	return finish_ending()
func finish_ending() -> Dictionary:
	world=host.world
	if world.ending_sequence.active and world.ending_sequence.preview: world.ending_sequence.close_preview()
	world.set_menu_open(false);world.player.set_controls_active(true)
	world.frame_budget_enabled=true;world._apply_frame_budget(host.root.has_focus())
	var proof:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"engine_pid":OS.get_process_id(),"captures":captures,"layouts":layouts,"provider_calls":provider_calls+world.npc_conversations.requests_started,"earlier_gates_and_arrival":"controller fixtures; not a full player route","course":"explicit sample content through real E/F3/Enter/Escape input","final":world.orchestrator.snapshot(),"source_hashes":{}}
	for path:String in ["game/Main.gd","game/GameHUD.gd","game/EndingState.gd","game/EndingSequence.gd","game/GameOrchestrator.gd","game/SessionState.gd","game/SessionEvent.gd","developer/DeveloperTools.gd","developer/course/SampleCourse.gd","developer/course/sample-course.json","developer/tests/CourseWorldPilot.gd","developer/tests/CourseReviewPilot.gd","developer/tests/EndingReviewPilot.gd","developer/tests/live_review.gd"]:
		proof.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open(prefix+"receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof,"  "));file.close()
	proof.receipt=prefix+"receipt.json"
	return proof
