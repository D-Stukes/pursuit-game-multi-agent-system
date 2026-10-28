extends SceneTree
## Export actual Godot viewport frames; no desktop/screen automation.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed: PackedScene = load("res://BuildingPlaytest.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	root.size = Vector2i(1280, 720)
	await process_frame
	if not world.ready_for_test:
		quit(1)
		return
	world.player.set_controls_active(false)
	DirAccess.make_dir_recursive_absolute("res://.godot/playtest")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/playtest/hud-introduction.png")
	world.set_menu_open(true)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(840, 600)]:
		root.size = resolution
		for _i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/playtest/settings-" + str(resolution.x) + ".png")
	root.size = Vector2i(1280, 720)
	world.hud.set_debug_mode(true)
	for _i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/playtest/developer-tools.png")
	world.hud.set_debug_mode(false)
	world.set_menu_open(false)
	world.player.set_controls_active(false)
	var captures: Array[Dictionary] = [
		{"name": "entrance", "feet": Vector3(0, 0, 6.7), "yaw": 0.0},
		{"name": "ramp", "feet": Vector3(2.35, 0.85, -4.8), "yaw": 0.0},
		{"name": "reception", "feet": world.LOCATIONS[1], "yaw": -PI / 2.0},
		{"name": "reception-depth", "feet": world.LOCATIONS[1], "yaw": PI},
		{"name": "hallway2", "feet": Vector3(-2, 5.05, -5.3), "yaw": PI / 2.0},
		{"name": "additional-room-door", "feet": Vector3(5.65, 5.05, -6.3), "yaw": PI},
		{"name": "classroom", "feet": world.LOCATIONS[2], "yaw": -PI / 2.0},
		{"name": "commons", "feet": world.approved_layout.anchor("commons_spawn"), "yaw": PI / 2.0},
		{"name": "upper-arrival", "feet": world.UPPER_LIFT_EXIT, "yaw": world.LIFT_HEADING},
		{"name": "upper-right-turn", "feet": world.UPPER_LIFT_EXIT, "yaw": world.LIFT_HEADING-PI/2},
		{"name": "lower-lift", "feet": world.LOWER_LIFT_EXIT, "yaw": PI/2},
		{"name": "avatar-front", "feet": Vector3(0, 0, 6.7), "yaw": PI},
		{"name": "exterior-street", "feet": Vector3(0, 0, 6.7), "yaw": PI, "pitch": 0.03},
		{"name": "exterior-left", "feet": Vector3(-10.5, 0, 6.7), "yaw": PI / 2.0},
		{"name": "exterior-right", "feet": Vector3(10.5, 0, 6.7), "yaw": -PI / 2.0},
		{"name": "exterior-up", "feet": Vector3(0, 0, 6.7), "yaw": PI, "pitch": 0.38, "zoom": 5.5},
		{"name": "exterior-down", "feet": Vector3(0, 0, 6.7), "yaw": PI, "pitch": -0.96, "zoom": 5.5}
	]
	for capture in captures:
		world.player.teleport_to(capture["feet"], capture["yaw"])
		world.player.visual.rotation.y = 0.0
		world.player.camera_pivot.rotation.x = capture.get("pitch", -0.20)
		world.player.spring_arm.spring_length = capture.get("zoom", 3.0)
		for _i in range(40):
			await physics_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = "res://.godot/playtest/" + capture["name"] + ".png"
		var error: Error = image.save_png(path)
		if error != OK:
			push_error("Capture failed: " + path)
			quit(1)
			return
		print("CAPTURE ", capture["name"], " ", image.get_size())
	# Capture real input-driven movement and its animated pose inside the building.
	world.player.spring_arm.spring_length = 3.0
	world.go_location(0)
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	for _i in range(36):
		await physics_frame
	await RenderingServer.frame_post_draw
	var walking_error: Error = root.get_texture().get_image().save_png("res://.godot/playtest/walking.png")
	Input.action_release("walk_forward")
	world.player.set_controls_active(false)
	if walking_error != OK:
		push_error("Walking capture failed")
		quit(1)
		return
	print("CAPTURE walking ", world.player.current_animation)
	root.size = Vector2i(800, 600)
	world.go_location(1)
	for _i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/playtest/narrow.png")
	if OS.get_cmdline_user_args().has("--stay-open"):
		root.size = Vector2i(1280, 720)
		world.go_location(0)
		world.player.set_controls_active(true)
		print("REVIEW_READY staying open for user")
		return
	world.queue_free()
	await process_frame
	quit(0)
