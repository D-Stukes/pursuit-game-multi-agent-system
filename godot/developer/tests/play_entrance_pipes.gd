extends SceneTree
## Rendered four-level playthrough using normal UI events and a shape-only pilot.
const Pilot = preload("res://developer/tests/PipeTestPilot.gd")
var output: String = "res://.godot/playtest/entrance-pipes"
var receipt: Dictionary = {"input_driven":true,"review_bypass":false,"levels":[]}

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for _i: int in range(count): await physics_frame

func key(code: Key, unicode: int = 0) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.unicode=unicode
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await frames(2)

func activate(button: Button) -> void:
	button.grab_focus()
	await key(KEY_ENTER)

func click(button: Button) -> void:
	var at: Vector2=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=at
	Input.parse_input_event(motion)
	await frames(2)
	var event:=InputEventMouseButton.new()
	event.position=at
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await frames(2)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
	print("PIPE_CAPTURE ",name)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	receipt.source_hashes = {}
	for path: String in ["game/EntrancePuzzle.gd","game/EntrancePuzzleState.gd","game/PipePuzzleState.gd","game/PipeTile.gd","game/Main.gd","developer/tests/play_entrance_pipes.gd","developer/tests/PipeTestPilot.gd"]:
		receipt.source_hashes[path] = FileAccess.get_sha256("res://"+path)
	var world: Node3D=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.frame_budget_enabled=false
	Engine.max_fps=60
	world.hud.hint_panel.hide()
	world.hud.hint_timer.stop()
	world.player.teleport_to(Vector3(0,0,5.7))
	await frames(12)
	assert(not world.building_review_mode and not world.entrance_puzzle.state.unlocked)
	await key(KEY_E)
	var puzzle: Control=world.entrance_puzzle
	assert(puzzle.visible and world.player.controls_locked)
	await capture("entrance-pipe-puzzle")
	for level: int in range(4):
		await capture("level-%d-ready" % (level+1))
		if level==0:
			await activate(puzzle.check_button)
			assert(not puzzle.state.level_cleared)
			await activate(puzzle.hint_button)
			await capture("circuit-hint")
		var rotations: Dictionary=Pilot.route(puzzle.state)
		assert(not rotations.is_empty())
		for index: int in rotations:
			for turn: int in range(rotations[index]):
				if level==0:
					var before: int=puzzle.state.masks[index]
					await click(puzzle.tiles[index])
					assert(puzzle.state.masks[index]!=before,"Mouse tile activation did not register")
				else: await activate(puzzle.tiles[index])
		assert(puzzle.state.connected() and puzzle.state.rewards.size()==level)
		await activate(puzzle.check_button)
		assert(puzzle.state.level_cleared)
		receipt.levels.append({"level":level+1,"width":puzzle.state.width,"turns":puzzle.state.moves,"phrase":puzzle.reward_label.text})
		await capture("level-%d-reward" % (level+1))
		if level<3: await activate(puzzle.next_button)
	assert(puzzle.state.solved and puzzle.reward_label.text=="Welcome to Pursuit")
	# Inspect final layout at the native minimum resolution, without letterboxing.
	root.content_scale_size=Vector2i(800,600)
	root.size=Vector2i(800,600)
	await frames(8)
	await capture("final-800")
	root.content_scale_size=Vector2i(1280,720)
	root.size=Vector2i(1280,720)
	await frames(8)
	await capture("welcome-to-pursuit")
	puzzle.code_input.grab_focus()
	var code: String=puzzle.state.revealed_code()
	for character: String in code: await key(character.unicode_at(0),character.unicode_at(0))
	await key(KEY_ENTER)
	assert(puzzle.state.unlocked and world.entrance_gate.collision_layer==0)
	await activate(puzzle.close_button)
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	await frames(45)
	Input.action_release("walk_forward")
	receipt.final_sentence="Welcome to Pursuit"
	receipt.door_unlocked=world.entrance_gate.collision_layer==0
	receipt.walked_through=world.player.global_position.z<4.3
	receipt.controls_restored=not world.player.controls_locked
	await capture("entered-building")
	var file:=FileAccess.open(output+"/playthrough.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "));file.close()
	var passed: bool=receipt.door_unlocked and receipt.walked_through and receipt.controls_restored
	print("PIPE_PLAYTHROUGH ","PASS" if passed else "FAIL"," ",JSON.stringify(receipt))
	world.queue_free();await process_frame
	quit(0 if passed else 1)
