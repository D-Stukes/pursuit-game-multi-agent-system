extends SceneTree
## Exercise real input, hint timing and responsive controls without a visible window.

var checks: Array[Dictionary] = []
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check": label, "pass": passed, "detail": str(detail)})
	print("PASS " if passed else "FAIL ", label, " ", detail)

func press_key(code: Key) -> void:
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
	world = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(5)
	player = world.player
	var hud: Control = world.hud
	check("headless verification is not frame-capped", Engine.max_fps == 0 and not world.frame_budget_enabled)
	var physics_rate: int = Engine.physics_ticks_per_second
	world.frame_budget_enabled = true
	world.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("background rendering capped at 15 FPS", Engine.max_fps == 15)
	world.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check("foreground rendering capped at 60 FPS", Engine.max_fps == 60)
	check("render cap preserves physics tick rate", Engine.physics_ticks_per_second == physics_rate)
	world.frame_budget_enabled = false
	Engine.max_fps = 0
	check("instructions visible on arrival", hud.hint_panel.visible)
	check("intro text fits visible hint", hud.hint_panel.get_global_rect().encloses(hud.hint_label.get_global_rect()) and hud.get_global_rect().encloses(hud.hint_panel.get_global_rect()), hud.hint_label.get_global_rect())
	await create_timer(4.4).timeout
	check("instructions remain before five seconds", hud.hint_panel.visible)
	await create_timer(0.8).timeout
	check("instructions disappear after five seconds", not hud.hint_panel.visible)
	check("floor title and settings remain", hud.floor_label.visible and hud.settings_button.visible)
	await press_key(KEY_ESCAPE)
	check("Escape opens settings and locks movement", hud.menu_open and player.controls_locked and not player.controls_active)
	var stopped: Vector3 = player.global_position
	Input.action_press("walk_forward")
	Input.action_press("run")
	player.set_controls_active(true)
	await frames(20)
	check("menu blocks held movement and run", player.global_position.distance_to(stopped) < 0.001 and not player.controls_active)
	Input.action_release("walk_forward")
	Input.action_release("run")
	var zoom: float = player.spring_arm.spring_length
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await frames(3)
	check("menu wheel does not zoom camera", is_equal_approx(zoom, player.spring_arm.spring_length))
	await press_key(KEY_3)
	check("menu blocks location shortcuts", player.global_position.distance_to(stopped) < 0.001)
	check("all instructions available in settings", hud.controls_label.text.contains("Shift") and hud.controls_label.text.contains("Elevator") and hud.controls_label.text.contains("double doors"))
	await press_key(KEY_F3)
	check("F3 opens developer view separately", hud.menu_open and hud.debug_mode and not hud.controls_label.visible)
	check("developer readout has coordinates and FPS", hud.developer_label.text.contains("FPS:") and hud.developer_label.text.contains("Position:"))
	await press_key(KEY_F3)
	check("F3 closes developer view and resumes", not hud.menu_open and not player.controls_locked)
	hud.settings_button.pressed.emit()
	check("Settings returns to player instructions", hud.menu_open and not hud.debug_mode and hud.controls_label.visible)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600)]:
		# The headless display does not resize native windows; resize the actual UI root.
		hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hud.size = Vector2(resolution)
		await frames(5)
		var viewport := Rect2(Vector2.ZERO, Vector2(resolution))
		check("UI root matches test size " + str(resolution), hud.size.is_equal_approx(Vector2(resolution)), hud.size)
		check("settings fits viewport " + str(resolution), viewport.encloses(hud.settings_button.get_global_rect()), hud.settings_button.get_global_rect())
		check("menu fits viewport " + str(resolution), viewport.encloses(hud.menu_panel.get_global_rect()), hud.menu_panel.get_global_rect())
		check("instructions fit menu " + str(resolution), hud.menu_panel.get_global_rect().encloses(hud.controls_label.get_global_rect()))
	await press_key(KEY_ESCAPE)
	check("Escape resumes movement", not hud.menu_open and not player.controls_locked and player.controls_active)
	hud.settings_button.pressed.emit()
	check("Settings button opens same menu", hud.menu_open and player.controls_locked)
	hud.resume_button.pressed.emit()
	check("Resume button closes menu", not hud.menu_open and player.controls_active)
	world.go_location(2)
	await frames(20)
	check("classroom spawn faces its retained long aisle", is_equal_approx(player.camera_pivot.rotation.y, -PI / 2.0))
	Input.action_press("walk_forward")
	await frames(25)
	var walk_speed: float = Vector2(player.get_real_velocity().x, player.get_real_velocity().z).length()
	check("normal walking speed", absf(walk_speed - player.SPEED) < 0.1, walk_speed)
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	await frames(25)
	var run_speed: float = Vector2(player.get_real_velocity().x, player.get_real_velocity().z).length()
	check("Shift increases movement speed", run_speed > walk_speed * 1.7 and absf(run_speed - player.RUN_SPEED) < 0.1, run_speed)
	check("running uses actual Run animation", player.current_animation == &"run" and player.animation_player.is_playing())
	shift = shift.duplicate()
	shift.pressed = false
	Input.parse_input_event(shift)
	await frames(12)
	check("releasing Shift returns to walking", player.current_animation == &"walk" and absf(Vector2(player.velocity.x, player.velocity.z).length() - player.SPEED) < 0.1)
	Input.action_release("walk_forward")
	await frames(20)
	Input.action_press("run")
	await frames(10)
	check("Shift alone stays idle", player.current_animation == &"idle")
	Input.action_release("run")
	check("floor indicator updates", hud.floor_label.text == "Second Floor")
	var failures: int = 0
	for result in checks:
		if not result["pass"]:
			failures += 1
	DirAccess.make_dir_recursive_absolute("res://.godot/playtest")
	var file := FileAccess.open("res://.godot/playtest/controls-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	file.close()
	print("CONTROLS_RESULT checks=", checks.size(), " failures=", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
