extends SceneTree
## Real world input/locks, reversible review bypass, verified win and safe transfer.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ", label)

func frames(count: int = 5) -> void:
	for _i: int in range(count): await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	var geometry: Array[int]=[world.mesh_count,world.collision_triangles]
	var player: CharacterBody3D = world.player
	var game: Control = world.elevator_game
	check("normal launch has no elevator credit", not world.building_review_mode and not game.state.completed())
	check("lift cannot be activated from street", not world.try_lift())
	# Isolate the elevator gate after an earned entrance result.
	preload("res://developer/tests/PipeTestPilot.gd").solve_all(world.entrance_puzzle.state)
	world.entrance_puzzle.state.enter_code(world.entrance_puzzle.state.revealed_code())
	world._on_entrance_unlocked()
	await key(KEY_3)
	check("normal shortcut cannot skip undefeated elevator", player.global_position.y < 1)
	player.teleport_to(world.LIFT_GROUND)
	await frames(12)
	check("cab prompt describes the game", world.hud.prompt_label.text == "Press E to play the elevator game. Win to access the second floor.")
	await key(KEY_E)
	check("real E opens lower-cab encounter", game.visible and game.state.phase == "ready")
	check("opening locks player and does not start travel", player.controls_locked and not world.lift_in_progress)
	check("repeat activation cannot start another encounter", not world.try_lift())
	game.ride_requested.emit()
	check("UI signal without completion cannot grant travel", not world.lift_in_progress and game.visible)
	check("computer portal rejects concurrent game", not world.computer_portal.try_use())
	var stopped: Vector3 = player.global_position
	var yaw: float = player.camera_pivot.rotation.y
	var zoom: float = player.spring_arm.spring_length
	Input.action_press("walk_forward")
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(300,100)
	Input.parse_input_event(motion)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await frames(10)
	Input.action_release("walk_forward")
	check("arcade isolates world movement and camera", player.global_position.distance_to(stopped)<.001 and player.camera_pivot.rotation.y==yaw and player.spring_arm.spring_length==zoom)
	await key(KEY_R);await key(KEY_3)
	check("reset and shortcut cannot escape modal", game.visible and player.global_position.distance_to(stopped)<.001)
	await key(KEY_ENTER)
	check("keyboard launches real encounter", game.state.phase == "playing")
	await key(KEY_ESCAPE)
	var clock: float = game.state.clock
	await frames(10)
	check("Escape returns to world with frozen encounter", not game.visible and not world.hud.menu_open and not player.controls_locked and game.state.clock==clock)
	await key(KEY_E)
	check("E reopens the same run", game.visible and game.state.phase=="playing" and game.state.clock>=clock)
	await key(KEY_F3)
	check("developer menu pauses arcade without unlocking controls", not game.visible and game.state.paused and world.hud.menu_open and player.controls_locked)
	world.hud.set_debug_mode(true)
	world.hud.developer.bypass_toggle.button_pressed=true
	world.hud.resume_button.pressed.emit()
	check("Review building bypass is explicit and grants no win", world.building_review_mode and not game.state.completed() and world.hud.developer.banner_label.text.contains("Puzzle gates"))
	check("review starts elevator without game", world.try_lift() and world.lift_in_progress and not game.visible)
	await world.lift_finished
	check("review arrives upstairs", player.global_position.distance_to(world.UPPER_LIFT_EXIT)<.1)
	check("descent does not require winning", world.try_lift() and world.lift_in_progress)
	await world.lift_finished
	check("review access alone offers no shooter replay", world.orchestrator.ascent_allowed() and world.replay_target()=="" and not world.try_replay())
	world.set_building_review_mode(false)
	await key(KEY_E)
	check("leaving review restores undefeated gate", game.visible and not world.lift_in_progress)
	# Clear through movement/fire and actual collisions, never a forced win flag.
	game.state.rng.seed = 42
	for _i: int in range(18000):
		if game.state.phase in ["won","lost"]: break
		var direction: Vector2=preload("res://developer/tests/ShooterTestPilot.gd").direction(game.state)
		game.state.step(1.0/60, direction,true)
	game._sync()
	print("ELEVATOR_PILOT phase=",game.state.phase," wave=",game.state.wave," shields=",game.state.shields," time=",game.state.clock)
	check("real collisions earn the verified final result", game.state.completed())
	check("win exposes Ride upstairs without auto teleport", game.primary_button.text=="Ride upstairs" and not world.lift_in_progress and player.global_position.y<1)
	check("Shift+Tab walks the result buttons backwards", game.primary_button.get_node(game.primary_button.focus_previous)==game.close_button and game.replay_button.get_node(game.replay_button.focus_previous)==game.primary_button)
	await key(KEY_SPACE)
	check("held fire cannot confirm the result screen", game.visible and not world.lift_in_progress and game.state.completed())
	game.replay_button.pressed.emit();await frames()
	check("Play again starts a fresh practice flight and keeps the earned unlock", game.replaying and game.state.phase=="playing" and game.earned_state.completed() and world.orchestrator.ascent_allowed())
	await key(KEY_ESCAPE)
	check("closing practice restores the earned result", not game.visible and not game.replaying and game.state.completed() and not player.controls_locked)
	await frames(3)
	check("lower cab offers both ride and replay", world.hud.prompt_label.text.contains("F: Play the elevator game again"))
	await key(KEY_F)
	check("F replays the elevator game at the lower cab", game.visible and game.replaying and game.state.phase=="playing")
	await key(KEY_ESCAPE)
	game.open();await frames()
	await key(KEY_ENTER)
	check("earned Ride button starts travel and hides arcade", world.lift_in_progress and not game.visible and player.controls_locked)
	check("repeated E during transfer is ignored", not world.try_lift())
	if world.lift_in_progress: await world.lift_finished
	await frames(8)
	check("earned travel safely reaches upper floor", player.is_on_floor() and player.global_position.distance_to(world.UPPER_LIFT_EXIT)<.1 and not player.controls_locked)
	check("earned state survives location reset", game.state.completed())
	check("unlocked elevator offers travel instead of another game",world.hud.prompt_label.text=="Press E to use the elevator")
	check("earned return uses existing lift", world.try_lift() and world.lift_in_progress)
	await world.lift_finished
	check("later ascent needs no replay", world.try_lift() and world.lift_in_progress and not game.visible)
	await world.lift_finished
	world.set_building_review_mode(true)
	world.set_building_review_mode(false)
	check("review toggles preserve earned completion", game.state.completed())
	check("world building geometry is unchanged", [world.mesh_count,world.collision_triangles]==geometry)
	world.queue_free()
	await process_frame
	print("ELEVATOR_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
