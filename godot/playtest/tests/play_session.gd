extends SceneTree
## One rendered normal-input journey through both gates and shared progress.
const Pipes = preload("res://playtest/tests/PipeTestPilot.gd")
var world: Node3D
var output: String="res://.godot/playtest/session-captures"
var held: Dictionary={}
var receipt: Dictionary={"input_driven":true,"review_bypass":false,"provider_calls":0,"levels":[],"waves":[]}

func _initialize() -> void:
	call_deferred("run")

func frames(count: int=3) -> void:
	for _i: int in range(count): await physics_frame

func key(code: Key, down: bool, unicode: int=0) -> void:
	if held.get(code,false)==down: return
	held[code]=down
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=down;event.unicode=unicode
	Input.parse_input_event(event)

func tap(code: Key, unicode: int=0) -> void:
	key(code,true,unicode);await process_frame;await frames(2)
	key(code,false);await process_frame;await frames(2)

func activate(button: Button) -> void:
	button.grab_focus();await process_frame;await tap(KEY_ENTER)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
	print("SESSION_CAPTURE ",name)

func walk_to(target: Vector3) -> bool:
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool=false
	for _i: int in range(450):
		var toward: Vector3=target-world.player.global_position;toward.y=0
		if toward.length()<.16: arrived=true;break
		world.player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)
		await physics_frame
	Input.action_release("walk_forward");await frames(5)
	return arrived and absf(world.player.global_position.y-target.y)<.22

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	receipt.source_hashes={}
	for path: String in ["playtest/SessionState.gd","playtest/SessionEvent.gd","playtest/GameOrchestrator.gd","playtest/BuildingPlaytest.gd","playtest/PlaytestHUD.gd","playtest/EntrancePuzzle.gd","playtest/EntrancePuzzleState.gd","playtest/PipePuzzleState.gd","playtest/PipeTile.gd","playtest/ElevatorShooter.gd","playtest/ElevatorShooterState.gd","playtest/ComputerPortal.gd","playtest/NPCConversations.gd","playtest/tests/PipeTestPilot.gd","playtest/tests/play_session.gd"]:
		receipt.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	world=load("res://BuildingPlaytest.tscn").instantiate();root.add_child(world)
	world.frame_budget_enabled=false;Engine.max_fps=60
	await frames(12)
	assert(not world.building_review_mode and world.npc_conversations.client.provider=="local")
	receipt.initial=world.orchestrator.snapshot()
	await capture("session-start")
	assert(await walk_to(world.ENTRANCE_POINT+Vector3(0,0,1.4)))
	await tap(KEY_E)
	var puzzle: Control=world.entrance_puzzle
	assert(puzzle.visible and world.orchestrator.snapshot().interaction=="entrance")
	for level: int in range(4):
		var turns: Dictionary=Pipes.route(puzzle.state)
		assert(not turns.is_empty())
		for index: int in turns:
			for _i: int in range(turns[index]): await activate(puzzle.tiles[index])
		await activate(puzzle.check_button)
		assert(puzzle.state.level_cleared and not world.orchestrator.entrance_allowed())
		receipt.levels.append({"level":level+1,"phrase":puzzle.reward_label.text,"turns":puzzle.state.moves})
		if level<3: await activate(puzzle.next_button)
	await capture("circuits-cleared-code-required")
	puzzle.code_input.grab_focus()
	for digit: String in puzzle.state.revealed_code(): await tap(digit.unicode_at(0),digit.unicode_at(0))
	await tap(KEY_ENTER)
	assert(world.orchestrator.snapshot().stage=="elevator" and world.entrance_gate.collision_layer==0)
	await capture("entrance-earned")
	await activate(puzzle.close_button)
	for point: Vector3 in [Vector3(0,0,3),Vector3(2.35,0,3),Vector3(2.35,.85,-4.8),Vector3(2.35,.85,-6.6),Vector3(2.35,.85,-9.4),Vector3(1.05,.85,-12.1),world.LIFT_GROUND]:
		assert(await walk_to(point),"Could not walk approved route to elevator: "+str(point))
	await capture("elevator-objective")
	await tap(KEY_E)
	var game: Control=world.elevator_game
	assert(game.visible and world.orchestrator.snapshot().interaction=="shooter")
	game.state.rng.seed=42
	await activate(game.primary_button)
	key(KEY_SPACE,true)
	var started: int=Time.get_ticks_msec()
	var photographed: bool=false
	var wave: int=0
	while game.state.phase not in ["won","lost"] and Time.get_ticks_msec()-started<90000:
		var state: RefCounted=game.state
		if state.wave!=wave:
			wave=state.wave;receipt.waves.append({"wave":wave,"cleared":state.cleared,"shields":state.shields})
		var target: float=state.ship.x
		if not state.enemies.is_empty():
			var enemy: Dictionary=state.enemies[0]
			target=enemy.home.x+sin((state.clock+(state.ship.y-enemy.at.y)/state.SHOT_SPEED)*.95+enemy.offset)*105
		key(KEY_D,target-state.ship.x>6);key(KEY_A,target-state.ship.x< -6)
		if not photographed and state.clock>1.2:
			await capture("shooter-running");photographed=true
		await process_frame
	for code: Key in [KEY_SPACE,KEY_A,KEY_D]:key(code,false)
	await frames()
	assert(game.state.completed() and world.orchestrator.gates_earned(),"Input pilot did not win the shooter")
	receipt.flight_seconds=game.state.clock
	receipt.drones_cleared=game.state.cleared
	await capture("shooter-earned")
	await activate(game.primary_button)
	var ride_deadline: int=Time.get_ticks_msec()+1500
	while not world.lift_in_progress and Time.get_ticks_msec()<ride_deadline: await process_frame
	if not world.lift_in_progress:
		print("SESSION_RIDE_NOT_STARTED ",JSON.stringify(world.orchestrator.snapshot()))
		await capture("ride-not-started");world.queue_free();await process_frame;quit(1);return
	await world.lift_finished
	await frames(12)
	if world.player.global_position.distance_to(world.UPPER_LIFT_EXIT)>=.1:
		await capture("ride-arrival-failed")
		print("SESSION_ARRIVAL_FAILED ",str(world.player.global_position))
		world.queue_free();await process_frame;quit(1);return
	await capture("upstairs-check-in-pending")
	root.content_scale_size=Vector2i(800,600);root.size=Vector2i(800,600);await frames(8)
	await capture("objective-800")
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await frames(8)
	receipt.upper_arrival=world.orchestrator.snapshot().zone=="upstairs"
	receipt.controls_restored=not world.player.controls_locked
	receipt.final=world.orchestrator.snapshot()
	assert(receipt.final.stage=="check_in_pending" and receipt.final.course==receipt.initial.course and not receipt.final.review_mode)
	assert(receipt.final.log.filter(func(row: Dictionary):return row.kind=="gate_verified").size()==2)
	await tap(KEY_R)
	receipt.reset_preserves_gates=world.orchestrator.gates_earned() and world.orchestrator.snapshot().session_id==receipt.initial.session_id
	assert(receipt.reset_preserves_gates)
	var file:=FileAccess.open(output+"/playthrough.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt,"  "));file.close()
	print("SESSION_PLAYTHROUGH PASS ",JSON.stringify(receipt))
	world.queue_free();await process_frame;quit()
