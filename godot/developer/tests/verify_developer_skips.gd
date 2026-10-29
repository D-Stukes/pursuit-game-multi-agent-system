extends SceneTree
const Coordinator=preload("res://game/GameOrchestrator.gd")
const Entrance=preload("res://game/EntrancePuzzleState.gd")
const Shooter=preload("res://game/ElevatorShooterState.gd")
const Event=preload("res://game/SessionEvent.gd")
const Pipes=preload("res://developer/tests/PipeTestPilot.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func frames(count: int=5) -> void:
	for i in range(count): await physics_frame
func win(shooter: RefCounted) -> void:
	shooter.start()
	while not shooter.completed():
		if shooter.phase=="between": shooter.between_waves=0
		for enemy: Dictionary in shooter.enemies: shooter.shots.append(enemy.at)
		shooter.step(.001,Vector2.ZERO,false)
func run() -> void:
	var entrance: RefCounted=Entrance.new()
	var shooter: RefCounted=Shooter.new()
	var state: RefCounted=Coordinator.new(entrance,shooter)
	check("entrance skip advances to playable shooter",state.skip_gate("entrance") and state.snapshot().stage=="elevator" and state.entrance_allowed() and not state.ascent_allowed())
	check("skip never fabricates a win or puzzle solution",not state.snapshot().gates.entrance and not entrance.completed() and not state.gates_earned())
	state.set_review(true);state.set_review(false)
	check("turning temporary bypass off preserves individual skip",state.entrance_allowed() and not state.ascent_allowed())
	check("shooter can claim after entrance skip",state.claim("shooter"))
	check("skip does not accept unfinished shooter victory",not state.submit(state.new_event(Event.Kind.SHOOTER_WON)).accepted)
	win(shooter)
	check("actual shooter victory works after skipped entrance",state.submit(state.new_event(Event.Kind.SHOOTER_WON)).accepted and state.ascent_allowed() and state.snapshot().gates.elevator)
	state.release("shooter");state.observe_zone("upstairs")
	check("upstairs check-in available on test route",state.check_in_allowed())
	check("test route grants no course rewards",state.snapshot().course.energy==10 and state.snapshot().course.score==0)
	entrance=Entrance.new();state=Coordinator.new(entrance,Shooter.new())
	check("skip shooter alone keeps entrance playable",state.skip_gate("elevator") and state.snapshot().stage=="entrance" and not state.entrance_allowed() and not state.ascent_allowed())
	Pipes.solve_all(entrance);entrance.enter_code(entrance.revealed_code())
	check("real entrance completion respects skipped shooter",state.submit(state.new_event(Event.Kind.ENTRANCE_UNLOCKED)).accepted and state.ascent_allowed() and state.snapshot().stage=="check_in_pending" and not state.snapshot().gates.elevator)
	state=Coordinator.new(Entrance.new(),Shooter.new(),false)
	check("player-only mode rejects developer skips",not state.skip_gate("entrance") and not state.skip_gate("elevator"))
	check("unknown skip rejected",not state.skip_gate("invented"))
	var world: Node3D=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	world.set_menu_open(true,true)
	world.hud.developer.skip_requested.emit("entrance")
	await frames(10)
	check("developer button opens actual shooter with bypass off",world.elevator_game.visible and not world.building_review_mode and world.orchestrator.snapshot().interaction=="shooter")
	check("entrance collider stays open for test run",world.entrance_gate.collision_layer==0)
	world.elevator_game.close();world.set_building_review_mode(true);world.set_building_review_mode(false)
	check("menu round trip does not erase test access",world.orchestrator.snapshot().stage=="elevator" and world.entrance_gate.collision_layer==0)
	world.queue_free();await process_frame
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	check("fresh run resets developer skips",not world.orchestrator.gate_passed("entrance") and not world.orchestrator.gate_passed("elevator"))
	world.queue_free();await process_frame
	print("DEVELOPER_SKIPS_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
