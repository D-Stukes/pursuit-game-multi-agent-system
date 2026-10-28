extends SceneTree
## One rendered, input-only flight from the lower cab to earned upper-floor arrival.
## No enemies, shields, progress or completion flags are altered by the pilot.
var world: Node3D
var output: String = "res://.godot/playtest/shooter-playthrough"
var held: Dictionary = {}
var receipt: Dictionary = {"input_driven":true,"review_bypass":false,"waves":[]}

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
	print("SHOOTER_CAPTURE ",name)

func key(code: Key, pressed: bool) -> void:
	if held.get(code,false)==pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code,true)
	await process_frame
	key(code,false)
	await process_frame

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	world=load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	world.frame_budget_enabled=false
	Engine.max_fps=60
	# Spawn at the lower cab to isolate the requested encounter from the entry game.
	world.player.teleport_to(world.LIFT_GROUND)
	for _i: int in range(12): await physics_frame
	assert(not world.building_review_mode and not world.elevator_game.state.completed())
	await capture("lower-elevator")
	await tap(KEY_E)
	var game: Control=world.elevator_game
	assert(game.visible and world.player.controls_locked)
	await capture("flight-ready")
	# Fix only the hazard RNG for a reproducible playthrough; all gameplay inputs
	# below are ordinary keyboard events consumed by the shipping controller.
	game.state.rng.seed=42
	await tap(KEY_ENTER)
	key(KEY_SPACE,true)
	var start: int=Time.get_ticks_msec()
	var seen_wave: int=0
	var photographed: bool=false
	while game.state.phase not in ["won","lost"] and Time.get_ticks_msec()-start<90000:
		var state: RefCounted=game.state
		if state.wave!=seen_wave:
			seen_wave=state.wave
			receipt.waves.append({"wave":seen_wave,"cleared":state.cleared,"shields":state.shields,"time":state.clock})
			print("FLIGHT_WAVE ",seen_wave," shields=",state.shields," cleared=",state.cleared)
		var target: float=state.ship.x
		if not state.enemies.is_empty():
			var enemy: Dictionary=state.enemies[0]
			target=enemy.home.x+sin((state.clock+(state.ship.y-enemy.at.y)/state.SHOT_SPEED)*.95+enemy.offset)*105
		key(KEY_D,target-state.ship.x>6)
		key(KEY_A,target-state.ship.x< -6)
		if not photographed and state.clock>1.1:
			await capture("spaceship-shooter")
			photographed=true
		await process_frame
	for code: Key in [KEY_SPACE,KEY_D,KEY_A]: key(code,false)
	receipt.flight_seconds=game.state.clock
	receipt.drones_cleared=game.state.cleared
	receipt.shields_remaining=game.state.shields
	receipt.won=game.state.completed()
	await capture("flight-result")
	if game.state.completed():
		await tap(KEY_ENTER)
		if world.lift_in_progress: await world.lift_finished
		for _i: int in range(12): await physics_frame
		receipt.upper_arrival=world.player.is_on_floor() and world.player.global_position.distance_to(world.UPPER_LIFT_EXIT)<.1
		receipt.controls_restored=not world.player.controls_locked
		await capture("upper-elevator-arrival")
	else:
		receipt.upper_arrival=false
		receipt.controls_restored=false
	var file:=FileAccess.open(output+"/playthrough.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	var passed: bool=receipt.won and receipt.upper_arrival and receipt.controls_restored
	print("SHOOTER_PLAYTHROUGH ","PASS" if passed else "FAIL"," ",JSON.stringify(receipt))
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
