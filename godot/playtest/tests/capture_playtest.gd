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
	var captures: Array[Dictionary] = [
		{"name": "entrance", "feet": Vector3(0, 0, 6.7), "yaw": 0.0},
		{"name": "ramp", "feet": Vector3(2.35, 0.85, -4.8), "yaw": 0.0},
		{"name": "reception", "feet": Vector3(8.3, 5.05, -12.8), "yaw": -PI / 2.0},
		{"name": "classroom", "feet": Vector3(18.56, 5.05, -2), "yaw": 0.0},
		{"name": "avatar-front", "feet": Vector3(0, 0, 6.7), "yaw": PI}
	]
	for capture in captures:
		world.player.teleport_to(capture["feet"], capture["yaw"])
		world.player.visual.rotation.y = 0.0
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
	root.size = Vector2i(800, 600)
	world.go_location(1)
	for _i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/playtest/narrow.png")
	world.queue_free()
	await process_frame
	quit(0)
