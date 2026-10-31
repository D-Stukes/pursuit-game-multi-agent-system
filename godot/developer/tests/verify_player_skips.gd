extends SceneTree
## Player Skip buttons open each gate without a verified win, reserve pellet or practice replay.
const Coordinator=preload("res://game/GameOrchestrator.gd")
const Entrance=preload("res://game/EntrancePuzzleState.gd")
const Shooter=preload("res://game/ElevatorShooterState.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func frames(count: int=5) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var state: RefCounted=Coordinator.new(Entrance.new(),Shooter.new())
	check("skip needs the open challenge",not state.skip_challenge("entrance"))
	state.claim("entrance")
	check("skip rejects the wrong gate",not state.skip_challenge("elevator") and not state.skip_challenge("invented"))
	state.release("entrance");state.set_review(true);state.claim("entrance")
	check("review mode cannot record a skip",not state.skip_challenge("entrance"))
	var world: Node3D=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	var orchestrator: RefCounted=world.orchestrator
	orchestrator.claim("entrance");world.entrance_puzzle.open();await frames()
	world.entrance_puzzle._skip();await frames(10)
	var snap: Dictionary=orchestrator.snapshot()
	check("entrance Skip opens the door and advances to the shooter",snap.stage=="elevator" and world.entrance_gate.collision_layer==0 and world.entrance_doors.open)
	check("entrance Skip is recorded as skipped, not earned",snap.skipped.entrance and not snap.gates.entrance and snap.log.any(func(entry: Dictionary):return entry.kind=="gate_skipped" and entry.details.gate=="entrance"))
	check("entrance Skip grants no reserve pellet or solve",snap.reserve_pellets==0 and not world.entrance_puzzle.state.solved and not world.entrance_puzzle.state.unlocked)
	check("entrance Skip closes the puzzle and restores movement",not world.entrance_puzzle.visible and snap.interaction.is_empty() and not world.player.controls_locked)
	orchestrator.claim("shooter");world.elevator_game.open();await frames()
	world.elevator_game._skip();await frames(5)
	snap=orchestrator.snapshot()
	check("shooter Skip unlocks the ride upstairs",snap.stage=="check_in_pending" and orchestrator.ascent_allowed())
	check("shooter Skip is recorded as skipped, not earned",snap.skipped.elevator and not snap.gates.elevator and not orchestrator.gates_earned())
	check("skipped shooter offers no practice replay",not world.elevator_game.replay_button.visible)
	check("Skip button hides once the shooter is passed",not world.elevator_game.skip_button.visible)
	world.elevator_game.close();await frames()
	world.player.teleport_to(world.LIFT_GROUND);await frames(5)
	check("skipped gates offer no replay at the lift",world.replay_target()=="")
	world.queue_free();await process_frame
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	check("fresh run resets player skips",not world.orchestrator.snapshot().skipped.entrance and not world.orchestrator.snapshot().skipped.elevator)
	world.queue_free();await process_frame
	print("PLAYER_SKIPS_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
