extends SceneTree
## Actual classroom controller, ordered evidence, interruption and inspection.
const GatePilot = preload("res://developer/tests/verify_check_in.gd")
const Rules = preload("res://game/ClassroomState.gd")
const Event = preload("res://game/SessionEvent.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func frames(count: int = 5) -> void:
	for _i: int in range(count): await physics_frame

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ",label)

func wait_phase(sequence: Node, target: String) -> bool:
	var deadline: int = Time.get_ticks_msec()+15000
	while sequence.active and sequence.phase != target and Time.get_ticks_msec()<deadline: await physics_frame
	return sequence.active and sequence.phase == target

func run() -> void:
	var rules: RefCounted = Rules.new()
	check("cannot invent final beat", not rules.record("get_to_work") and not rules.completed())
	check("entry alone is not a complete introduction", rules.record("entered") and not rules.completed())
	check("cancel clears partial presentation", rules.record("stand_up"))
	rules.cancel()
	check("a cancelled sequence must replay from entry", rules.presented.is_empty() and not rules.record("crowd"))
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world); await frames(12)
	var sequence: Node = world.classroom_sequence
	var coordinator: RefCounted = world.orchestrator
	var initial_course: Dictionary = coordinator.snapshot().course
	var manager_transform: Transform3D = sequence.manager.transform
	world.go_location(2); await frames()
	check("inspection before check-in cannot start stand-up", not sequence.active and not sequence.start() and coordinator.snapshot().stage == "entrance")
	world.npc_conversations.classroom_presented(true)
	check("unverified presentation flag cannot activate Manager",not sequence.manager.routine.started and not world.npc_conversations.state.met_npcs.has("ProgramManager"))
	GatePilot.solve_gates(world)
	world.go_location(1); await frames()
	coordinator.claim("check_in")
	world.check_in.state.start_photo("Sam Fixture"); world.check_in.state.take_photo(); world.check_in.state.confirm()
	coordinator.submit(coordinator.new_event(Event.Kind.CHECK_IN_CONFIRMED)); coordinator.release("check_in")
	check("typed classroom event cannot substitute for a presentation", not coordinator.submit(coordinator.new_event(Event.Kind.CLASSROOM_INTRODUCED)).accepted)
	world.set_building_review_mode(true)
	check("developer bypass starts no story sequence", not sequence.start() and not coordinator.snapshot().arrival.classroom_complete)
	world.set_building_review_mode(false)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1; blocker.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(1.4,2.8,.2)
	collision.shape = box; blocker.add_child(collision)
	world.add_child(blocker)
	blocker.global_position = world.approved_layout.anchor("classroom_door")+Vector3.UP*1.3
	await frames(2); sequence.start()
	var blocked_deadline: int = Time.get_ticks_msec()+3000
	while sequence.active and Time.get_ticks_msec()<blocked_deadline: await physics_frame
	check("blocked doorway cancels without clipping or progress", not sequence.active and sequence.state.presented.is_empty() and not coordinator.snapshot().arrival.classroom_complete and not world.player.controls_locked)
	blocker.queue_free(); await frames(3)
	check("confirmed check-in can start classroom handoff", sequence.start() and world.player.controls_locked and coordinator.snapshot().interaction == "classroom")
	check("repeat start and overlapping use are rejected", not sequence.start() and not world.try_lift() and not world.computer_portal.try_use() and not world.npc_conversations.try_talk())
	world.go_location(0); await frames()
	check("developer travel cancels a fade without ghost progress", not sequence.active and not world.hud.travel_overlay.visible and sequence.state.presented.is_empty() and coordinator.snapshot().interaction.is_empty() and not coordinator.snapshot().arrival.classroom_complete)
	world.go_location(1); await frames()
	world.player.teleport_to(Vector3(.38,5.075,-2.8)); await frames()
	check("walking into the classroom can resume after closing check-in", sequence.active and sequence.phase == "stand_up")
	world.go_location(0); await frames()
	world.go_location(1); await frames(); sequence.start()
	check("short collision-checked entrance reaches stand-up", await wait_phase(sequence,"stand_up"))
	check("entry lands inside the actual classroom", sequence.in_classroom() and sequence.state.presented == ["entered"] and not world.hud.travel_overlay.visible)
	check("presentation shot shows the Program Manager", sequence.presentation_camera.current and sequence.presentation_camera.is_position_in_frustum(sequence.manager.global_position+Vector3.UP))
	var focus: Vector3 = sequence.manager.global_position+Vector3.UP
	var sight: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sequence.presentation_camera.global_position,focus,1))
	check("presenter camera has clear sight past the door", sight.is_empty())
	world.computer_portal.update_prompts(1)
	check("computer prompts are hidden during the presentation", world.computer_portal.computers.all(func(device: Dictionary): return not device.label.visible))
	var elapsed: float = sequence.elapsed
	world.set_menu_open(true); await create_timer(.3).timeout
	check("Settings pauses story time and owns input", is_equal_approx(sequence.elapsed,elapsed) and coordinator.snapshot().interaction == "menu" and world.player.controls_locked)
	world.set_menu_open(false); await frames(2)
	check("resume restores classroom ownership and keeps movement locked", coordinator.snapshot().interaction == "classroom" and world.player.controls_locked and sequence.elapsed>elapsed)
	check("stand-up leads to audible simulated crowd", await wait_phase(sequence,"crowd") and sequence.crowd.playing and sequence.crowd.stream is AudioStreamWAV)
	world.set_menu_open(true); await frames(2)
	check("Settings also pauses crowd playback", sequence.crowd.stream_paused)
	world.set_menu_open(false)
	check("crowd leads to get-to-work instruction", await wait_phase(sequence,"get_to_work") and sequence.line.text.contains("get to work"))
	check("last caption alone still cannot complete early", not coordinator.submit(coordinator.new_event(Event.Kind.CLASSROOM_INTRODUCED)).accepted)
	for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); world.hud.size=resolution; await frames(2)
		check("classroom caption fits viewport", Rect2(Vector2.ZERO,resolution).encloses(sequence.caption.get_global_rect()))
	var deadline: int = Time.get_ticks_msec()+10000
	while sequence.active and Time.get_ticks_msec()<deadline: await physics_frame
	await frames(2)
	check("all timed beats publish verified classroom completion", not sequence.active and sequence.state.completed() and coordinator.snapshot().arrival.classroom_complete and coordinator.snapshot().stage == "mr_p_pending")
	check("handoff restores controls and releases sequence", not world.player.controls_locked and coordinator.snapshot().interaction.is_empty() and not sequence.caption.visible and not sequence.crowd.playing)
	check("handoff restores the player camera", world.player.camera.current and not sequence.presentation_camera.current)
	check("Program Manager starts its routine after verified presentation", sequence.manager.position.distance_to(manager_transform.origin)<.12 and sequence.manager.routine.started and world.npc_conversations.state.met_npcs.has("ProgramManager"))
	world.npc_conversations.classroom_presented(true)
	check("repeated presentation contact cannot restart routine",sequence.manager.routine.conversations==1)
	check("completion points to the computer and preserves course values", world.hud.objective_label.text == "Next: Use a classroom computer" and coordinator.snapshot().course == initial_course)
	check("Mr P and robot still have no course completion", coordinator.snapshot().course.question_id.is_empty() and coordinator.snapshot().course.robot_parts.is_empty() and world.computer_portal.room.mrp != null)
	var revision: int = coordinator.snapshot().revision
	check("repeat signal cannot duplicate the presentation", not sequence.start() and not coordinator.submit(coordinator.new_event(Event.Kind.CLASSROOM_INTRODUCED)).accepted and coordinator.snapshot().revision == revision)
	check("new story work makes no provider request", world.npc_conversations.requests_started == 0 and world.population.actors.size() == 5)
	world.queue_free(); await process_frame
	print("CLASSROOM_RESULT checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
