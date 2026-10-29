extends SceneTree
const State=preload("res://game/EndingState.gd")
const Event=preload("res://game/SessionEvent.gd")
const Adapter=preload("res://game/CourseAdapter.gd")
const Pure=preload("res://developer/tests/CourseTestPilot.gd")
const Setup=preload("res://developer/tests/CourseWorldPilot.gd")
const FAST={"fade_out":.05,"fade_in":.05,"results":.05,"assessment":.05,"celebration":.05}
var checks:int=0
var failures:int=0
var world:Node3D
func _initialize() -> void: call_deferred("run")
func frames(count:int=4) -> void:
	for _i:int in range(count): await physics_frame
func check(label:String,ok:bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func key(code:Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)
func wait_phase(phase:String) -> bool:
	for _i:int in range(400):
		if world.ending_sequence.active and world.ending_sequence.state.phase==phase: return true
		await process_frame;await frames(1)
	return false
func play_pure(state:RefCounted) -> void:
	for _i:int in range(60):
		state.step(.1)
		if state.phase=="placement": state.placed(true)
func finish_course(c:RefCounted,definition:Dictionary) -> void:
	c.claim("course")
	assert(c.begin_course(Adapter.new(definition)).accepted)
	for choice:String in ["observe","decide","verify","return"]: assert(c.submit(Pure.answer(c,choice)).accepted)
func unchanged(before:Dictionary,after:Dictionary) -> bool:
	for field:String in ["session_id","stage","gates","course","arrival","ending","review_mode","zone"]:
		if before[field]!=after[field]: return false
	return true
func run() -> void:
	var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://developer/course/sample-course.json"))
	check("invalid timing fails explicitly",not State.new({"assessment":-1}).error.is_empty() and not State.new({"unknown":1}).error.is_empty())
	var c:RefCounted=Pure.context(false).coordinator
	check("normal ending cannot start from greeting travel or a done claim",not c.begin_ending(State.new(),false) and not c.submit(c.new_event(Event.Kind.ENDING_PRESENTED,{"done":true})).accepted)
	check("player-only coordinator rejects preview",not Pure.context(false,false).coordinator.begin_ending(State.new(),true))
	var state:RefCounted=State.new(FAST)
	check("developer preview allowed before course",c.begin_ending(state,true))
	state.step(.1,true)
	check("paused presentation cannot advance",state.phase=="fade_out" and state.elapsed==0)
	check("early placement and result cannot certify presentation",not state.placed(true) and not c.submit(c.new_event(Event.Kind.ENDING_PRESENTED)).accepted)
	play_pure(state)
	check("completed preview still cannot certify presentation",state.phase=="complete" and not c.submit(c.new_event(Event.Kind.ENDING_PRESENTED)).accepted and not c.snapshot().ending.presented)
	c.end_presentation()
	check("preview releases interaction",c.snapshot().interaction=="")
	c=Pure.context().coordinator;finish_course(c,definition)
	check("ending waits for course interaction to close",c.ending_ready() and not c.begin_ending(State.new(),false))
	c.release("course");c.claim("portal")
	state=State.new(FAST);check("verified required set starts normal ending",c.begin_ending(state,false))
	var early:RefCounted=c.new_event(Event.Kind.ENDING_PRESENTED)
	check("early event has no completion receipt",not c.submit(early).accepted)
	play_pure(state)
	var wrong:RefCounted=c.new_event(Event.Kind.ENDING_PRESENTED);wrong.interaction_id="wrong"
	check("wrong presentation nonce rejected",not c.submit(wrong).accepted)
	var result:RefCounted=c.new_event(Event.Kind.ENDING_PRESENTED)
	check("ordered normal presentation is accepted once",c.submit(result).accepted and c.snapshot().ending.presented and c.submit(result).duplicate and not c.ending_ready())
	check("ending preserves course score energy and required results",c.snapshot().course.score==60 and c.snapshot().course.energy==10 and c.snapshot().course.complete)
	c.end_presentation()
	check("ending receipt objective matches snapshot",c.objective()==c.snapshot().objective)
	var other:RefCounted=Pure.context(false).coordinator
	check("previous-session ending is rejected",other.submit(result).reason=="stale_session")
	var held:Dictionary={"course":{"score":98765,"energy":4,"maximum_energy":7,"required_questions":["alternate"],"required_challenges":[],"completed_questions":["alternate"],"completed_challenges":[]}}
	state=State.new({"results":.2,"assessment":.1,"fade_in":.05,"fade_out":.05,"celebration":.15})
	state.start("held","token",held,false);held.course.score=0;play_pure(state)
	check("held-out timing and results work without code changes",state.completed("held","token") and state.results.course.score==98765 and state.results.course.maximum_energy==7)
	state.cancel();check("cancel invalidates earlier evidence",not state.completed("held","token"))
	root.size=Vector2i(800,600);root.content_scale_size=Vector2i(800,600)
	world=load("res://Main.tscn").instantiate();root.add_child(world);current_scene=world;await frames(12)
	var ending:Node=world.ending_sequence
	ending.timing={"fade_out":.08,"fade_in":.08,"results":.25,"assessment":.25,"celebration":.25}
	check("normal game cannot start ending without completion",not ending.start(false) and not ending.active)
	world.player.camera_pivot.rotation=Vector3(-.3,.8,0);world.player.spring_arm.spring_length=3.1
	var origin:Vector3=world.player.global_position
	var view:Vector3=world.player.camera_pivot.rotation
	var before:Dictionary=world.orchestrator.snapshot()
	world.set_menu_open(true,true);world.hud.developer.ending_preview_button.pressed.emit()
	check("developer menu opens preview without a completed course",ending.active and ending.preview and not world.hud.menu_open)
	check("classroom safe placement was found",ending.safe_classroom_position().is_finite())
	check("preview reaches results",await wait_phase("results"))
	await frames(6)
	check("first preview results fit at 800 before any resize",Rect2(Vector2.ZERO,Vector2(800,600)).encloses(ending.panel.get_global_rect()) and ending.panel.get_global_rect().encloses(ending.message.get_global_rect()))
	for resolution:Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		world.set_menu_open(true);root.size=resolution;root.content_scale_size=resolution;await frames(8)
		var phase:String=ending.state.phase;var elapsed:float=ending.state.elapsed
		await create_timer(.2).timeout
		check("Settings pauses ending "+str(resolution),ending.state.phase==phase and ending.state.elapsed==elapsed and not ending.overlay.visible)
		world.set_menu_open(false);await frames(2)
		check("ending panel fits "+str(resolution),Rect2(Vector2.ZERO,Vector2(resolution)).encloses(ending.panel.get_global_rect()))
	check("preview reaches end without a receipt",await wait_phase("complete") and not world.orchestrator.snapshot().ending.presented)
	ending.action.pressed.emit();await frames(2)
	check("preview returns original position view and zoom",not ending.active and world.player.global_position.distance_to(origin)<.01 and world.player.camera_pivot.rotation.is_equal_approx(view) and is_equal_approx(world.player.spring_arm.spring_length,3.1))
	check("preview preserves all player progress",unchanged(before,world.orchestrator.snapshot()))
	ending.start(true);await key(KEY_ESCAPE)
	check("Escape cancels a preview during fade",not ending.active and not world.hud.menu_open and unchanged(before,world.orchestrator.snapshot()))
	Setup.prepare_arrival(world);check("real classroom computer approach available",Setup.approach_computer(world).is_finite())
	await frames();world.computer_portal.try_use()
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	await frames()
	var return_point:Vector3=world.computer_portal.return_position
	origin=world.player.global_position;view=world.player.camera_pivot.rotation;before=world.orchestrator.snapshot()
	check("preview can start inside purple world",ending.start(true))
	await wait_phase("assessment");ending.close_preview();await frames()
	check("purple preview restores portal origin room and owner",world.computer_portal.inside and world.computer_portal.room.visible and world.computer_portal.return_position==return_point and world.orchestrator.snapshot().interaction=="portal" and world.player.global_position.distance_to(origin)<.01 and world.player.camera_pivot.rotation.is_equal_approx(view))
	check("purple preview preserves course progress",unchanged(before,world.orchestrator.snapshot()))
	world.orchestrator.release("portal");finish_course(world.orchestrator,definition)
	await frames();check("course owner still prevents auto ending",not ending.active)
	var classroom_anchor:Vector3=world.LOCATIONS[2]
	world.LOCATIONS[2]=Vector3(0,100,0)
	world.orchestrator.release("course");world.orchestrator.claim("portal")
	check("failed placement shows recoverable error without receipt",await wait_phase("error") and ending.retry.visible and not world.orchestrator.snapshot().ending.presented and world.orchestrator.snapshot().course.score==60)
	world.LOCATIONS[2]=classroom_anchor;ending.retry.pressed.emit()
	check("verified release starts normal ending",await wait_phase("results") and not ending.preview and not world.computer_portal.inside)
	check("normal ending returns to supported classroom space",world.player.global_position.distance_to(world.LOCATIONS[2])<1.6)
	check("normal ending reaches L3 receipt",await wait_phase("complete") and world.orchestrator.snapshot().ending.presented)
	check("normal presentation makes no provider requests",world.npc_conversations.requests_started==0)
	var session:String=world.orchestrator.snapshot().session_id;var pid:int=OS.get_process_id()
	ending.action.pressed.emit();await scene_changed;await frames(12);world=current_scene
	check("Play Again resets run in same process",OS.get_process_id()==pid and world.orchestrator.snapshot().session_id!=session and world.orchestrator.snapshot().stage=="entrance" and not world.orchestrator.snapshot().ending.presented and world.orchestrator.snapshot().course.score==0)
	print("ENDING_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
