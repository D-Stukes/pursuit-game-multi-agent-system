extends SceneTree
## Entrance rules, real input, physical gate and responsive panel acceptance.

var world: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for _i in range(count):
		await physics_frame

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("PASS " if passed else "FAIL ", label)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/playtest/entrance-" + label + ".png")

func run() -> void:
	world = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var puzzle: Control = world.entrance_puzzle
	var player: CharacterBody3D = world.player
	check("world and locked entrance ready", world.ready_for_test and not puzzle.state.unlocked and world.entrance_gate.collision_layer == 4)
	await capture("locked")
	check("code hidden before valid order", puzzle.state.revealed_code().is_empty())
	check("guessed code cannot skip puzzle", not puzzle.state.enter_code("%d%d%d" % [puzzle.state.digits[0], puzzle.state.digits[1], puzzle.state.digits[2]]))
	check("partial/repeated/incorrect orders rejected", not puzzle.state.check_order([0, 1]) and not puzzle.state.check_order([0, 0, 0]) and not puzzle.state.check_order([2, 1, 0]))
	await key(KEY_3)
	check("normal teleport shortcut cannot bypass lock", player.global_position.y < 1)
	player.teleport_to(Vector3(0, 0, 5.7))
	await frames(15)
	player.set_controls_active(true)
	Input.action_press("walk_forward")
	await frames(45)
	Input.action_release("walk_forward")
	check("physical door blocks walking before unlock", player.global_position.z > 4.8)
	await key(KEY_E)
	check("E opens puzzle and locks player", puzzle.visible and player.controls_locked)
	var before: Vector3 = player.global_position
	Input.action_press("walk_forward")
	await frames(15)
	Input.action_release("walk_forward")
	check("puzzle blocks held movement", player.global_position.distance_to(before) < 0.01)
	var zoom: float = player.spring_arm.spring_length
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await frames()
	check("puzzle wheel does not zoom camera", is_equal_approx(zoom, player.spring_arm.spring_length))
	puzzle.choices[0].grab_focus()
	await key(KEY_ENTER) # Act first: wrong, through real keyboard UI input.
	puzzle.check_button.pressed.emit()
	check("wrong UI order leaves entrance locked", not puzzle.state.solved and world.entrance_gate.collision_layer == 4)
	puzzle.hint_button.pressed.emit()
	check("hint supplies finite recovery path", puzzle.feedback.text.contains("Sense → Decide → Act"))
	await key(KEY_ESCAPE)
	check("Escape closes without opening settings", not puzzle.visible and not world.hud.menu_open and not player.controls_locked)
	await key(KEY_E)
	check("reopen retains unfinished order", puzzle.visible and puzzle.order == [2])
	var focus: Control = root.gui_get_focus_owner()
	check("reopen focuses an enabled puzzle control", focus != null and puzzle.is_ancestor_of(focus) and not (focus is Button and focus.disabled))
	for _i in range(12):
		await key(KEY_TAB)
		focus = root.gui_get_focus_owner()
		check("Tab stays inside puzzle", focus != null and puzzle.is_ancestor_of(focus))
	puzzle.reset_button.pressed.emit()
	check("reset clears choices without granting success", puzzle.order.is_empty() and not puzzle.state.solved)
	# Check the UI at the game's minimum and normal window sizes.
	for resolution: Vector2 in [Vector2(800, 600), Vector2(1280, 720)]:
		if OS.get_cmdline_user_args().has("--capture"):
			# Exercise the panel at native pixels, not a letterboxed/scaled viewport.
			root.content_scale_size = Vector2i(resolution)
			root.size = Vector2i(resolution)
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		world.hud.size = resolution
		await frames(6)
		check("panel fits " + str(resolution), Rect2(Vector2.ZERO, resolution).encloses(puzzle.panel.get_global_rect()))
		check("panel can scroll all controls " + str(resolution), puzzle.scroll.get_global_rect().size.y > 0 and puzzle.column.size.x <= puzzle.scroll.size.x + 1)
		await capture(str(int(resolution.x)))
	for id: int in [0, 1, 2]:
		for choice: Button in puzzle.choices:
			if choice.get_meta("step_id") == id:
				choice.pressed.emit()
	puzzle.check_button.pressed.emit()
	await frames()
	check("correct order reveals code but keeps gate locked", puzzle.state.solved and puzzle.code_box.visible and puzzle.code_label.text.contains(puzzle.state.revealed_code()) and not puzzle.state.unlocked)
	await capture("solved")
	puzzle.code_input.text = "000"
	puzzle.unlock_button.pressed.emit()
	check("incorrect code does not unlock", not puzzle.state.unlocked)
	puzzle.code_input.text = puzzle.state.revealed_code()
	await key(KEY_ENTER)
	await frames()
	check("correct code unlocks physical gate", puzzle.state.unlocked and world.entrance_gate.collision_layer == 0 and not world.entrance_gate.visible)
	check("unlock has no duplicate action", puzzle.unlock_button.disabled and not puzzle.code_input.editable)
	puzzle.close_button.pressed.emit()
	check("close restores control", not puzzle.visible and not player.controls_locked)
	world.go_location(0)
	await frames(10)
	check("location reset preserves session unlock", puzzle.state.unlocked and world.entrance_gate.collision_layer == 0)
	player.teleport_to(Vector3(0, 0, 5.7))
	await frames(10)
	player.set_controls_active(true)
	Input.action_press("walk_forward")
	await frames(45)
	Input.action_release("walk_forward")
	check("player walks through unlocked doorway", player.global_position.z < 4.3)
	await capture("unlocked")
	# New session rules must not inherit a completed puzzle.
	var fresh: RefCounted = load("res://playtest/EntrancePuzzleState.gd").new()
	check("new session relocks puzzle", not fresh.solved and not fresh.unlocked and fresh.revealed_code().is_empty())
	print("ENTRANCE_RESULT checks=", checks, " failures=", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
