extends SceneTree
const Setup=preload("res://developer/tests/CourseWorldPilot.gd")
const Event=preload("res://game/SessionEvent.gd")
var checks:int=0
var failures:int=0
func _initialize() -> void: call_deferred("run")
func frames(count:int=5) -> void:
	for _i:int in range(count): await physics_frame
func check(label:String,ok:bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func key(code:Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)
func run() -> void:
	var world:Node3D=load("res://Main.tscn").instantiate()
	world.include_classroom_cast=false
	root.add_child(world);current_scene=world;await frames(12)
	Setup.prepare_arrival(world)
	world.orchestrator.observe_zone("purple_room");world.orchestrator.claim("course")
	var adapter:RefCounted=load("res://game/CourseAdapter.gd").new(JSON.parse_string(FileAccess.get_file_as_string("res://developer/course/sample-course.json")))
	world.orchestrator.begin_course(adapter)
	world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.COURSE_ANSWER_SUBMITTED,{"question_id":"sample-observe","answer_id":"observe","expected_revision":0}))
	world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.COURSE_ANSWER_SUBMITTED,{"question_id":"sample-decide","answer_id":"act","expected_revision":1}))
	check("restart fixture has earned score and spent energy",world.orchestrator.snapshot().course.score==10 and world.orchestrator.snapshot().course.energy==9)
	world.orchestrator.release("course")
	world.npc_conversations.state.remember("ReceptionA","welcome","A test conversation")
	world.npc_conversations.state.public_memories["ReceptionA"]={"turn_count":1}
	var stale:RefCounted=world.orchestrator.new_event(Event.Kind.ENTRANCE_UNLOCKED)
	var session:String=world.orchestrator.snapshot().session_id
	await key(KEY_R)
	check("R resets location without resetting session",world.orchestrator.snapshot().session_id==session and world.orchestrator.gates_earned())
	world.set_menu_open(true)
	for resolution:Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=resolution;root.content_scale_size=resolution;await frames(8)
		world.hud.restart_button.pressed.emit();await frames()
		check("confirmation fits viewport "+str(resolution),Rect2(Vector2.ZERO,Vector2(resolution)).encloses(world.hud.restart_panel.get_global_rect()))
		check("confirmation defaults to cancel",world.hud.get_viewport().gui_get_focus_owner()==world.hud.restart_cancel)
		await key(KEY_ESCAPE)
		check("Escape cancels only restart confirmation",world.hud.menu_open and not world.hud.restart_dialog_open and world.player.controls_locked and world.orchestrator.snapshot().session_id==session)
	world.hud.restart_button.pressed.emit();world.hud.restart_cancel.pressed.emit()
	check("Cancel preserves earned progress and memories",world.orchestrator.gates_earned() and not world.npc_conversations.state.memories.is_empty())
	world.set_building_review_mode(true)
	var pid:int=OS.get_process_id()
	world.hud.restart_button.pressed.emit();world.hud.restart_accept.pressed.emit()
	await scene_changed;await frames(15)
	world=current_scene
	var fresh:Dictionary=world.orchestrator.snapshot()
	check("restart replaces session without closing engine",OS.get_process_id()==pid and fresh.session_id!=session and world.ready_for_test)
	check("restart relocks both games and clears arrival",fresh.stage=="entrance" and not fresh.gates.entrance and not fresh.gates.elevator and not fresh.arrival.checked_in and not fresh.arrival.classroom_complete and world.entrance_gate.collision_layer==4 and not world.entrance_puzzle.state.unlocked)
	check("restart clears course and restores baseline",fresh.course.energy==10 and fresh.course.score==0 and not fresh.course.has("complete"))
	check("fresh run preserves sitting capability in standing state",world.player.sit_state==&"" and world.player.animation_player.has_animation("sit_enter") and world.player.animation_player.has_animation("sit_exit"))
	check("restart clears NPC private and public memories",world.npc_conversations.state.memories.is_empty() and world.npc_conversations.state.public_memories.is_empty() and world.npc_conversations.state.met_npcs.is_empty())
	check("restart disables bypass but retains run configuration",not world.building_review_mode and world.hud.developer!=null and world.include_population and not world.include_classroom_cast)
	check("old event cannot change new run",world.orchestrator.submit(stale).reason=="stale_session" and not world.orchestrator.gates_earned())
	world.enable_developer_tools=false
	world.request_restart();await scene_changed;await frames(15);world=current_scene
	check("player-only restart retains disabled developer tools",world.hud.developer==null and world.sample_course==null and not world.enable_developer_tools)
	world.set_menu_open(true);world.hud.restart_button.pressed.emit()
	check("restart confirmation available in player-only Settings",world.hud.restart_dialog_open)
	print("RESTART_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
