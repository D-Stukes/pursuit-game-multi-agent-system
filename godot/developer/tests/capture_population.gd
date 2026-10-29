extends SceneTree
## Capture the actual integrated world, with no desktop automation or art substitutes.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for _i in range(8): await physics_frame
	assert(world.ready_for_test)
	world.player.set_controls_active(false)
	world.player.hide()
	world.hud.hide()
	root.size = Vector2i(1280,720)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 65
	camera.near = .05
	world.add_child(camera)
	var output: String = "res://.godot/playtest/population"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var views: Array[Dictionary] = [
		{"id":"mr-p-purple-room", "eye":world.computer_portal.room.to_global(Vector3(1.4,2.0,2.7)), "target":world.computer_portal.room.to_global(Vector3(-1.7,1.7,-.3)), "purple_room":true},
		{"id":"robot-repair", "eye":Vector3(-11.4,7.4,3.6), "target":Vector3(-14.05,6.05,1.8)},
		{"id":"robot-overhead", "eye":Vector3(-14.05,8.3,1.8), "target":Vector3(-14.05,5.858,1.8), "up":Vector3.FORWARD, "fov":70},
		{"id":"classroom-cast", "eye":Vector3(3.5,7.4,-2.7), "target":Vector3(-5,6.3,2), "fov":75},
		{"id":"street-population", "eye":Vector3(0,2.3,14), "target":Vector3(0,1.2,5.5), "fov":85},
		{"id":"ground-population", "eye":Vector3(-.7,1.9,5.7), "target":Vector3(-1.8,1.2,1.8)},
		{"id":"hall-population", "eye":Vector3(1.2,2.4,-5.7), "target":Vector3(2.65,1.6,-8.7)},
		{"id":"reception-population", "eye":Vector3(.9,7.1,-10.3), "target":Vector3(5.3,6.1,-5.8)},
		{"id":"commons-population", "eye":Vector3(-9.0,7.1,-10), "target":Vector3(-16,6,-12)},
		{"id":"small-room-population", "eye":Vector3(-4.0,6.7,-6.3), "target":Vector3(-5.6,6,-8.5)},
		{"id":"player-classroom-east", "default_camera":true, "feet":Vector3(-.4,5.07,1.4), "heading":-PI},
		{"id":"player-classroom-repair", "default_camera":true, "feet":Vector3(-13.5,5.07,-.05), "heading":-PI},
		{"id":"player-reception", "default_camera":true, "feet":Vector3(1.1,5.07,-9.1), "heading":-PI/2}
	]
	for view: Dictionary in views:
		var purple: bool = view.get("purple_room",false)
		world.computer_portal.room.set_active(purple)
		camera.environment = world.computer_portal.room.room_environment if purple else null
		var normal: bool = view.get("default_camera",false)
		world.player.visible = normal
		world.hud.visible = normal
		if normal:
			world.player.teleport_to(view.feet,view.heading)
			world.player.camera.current = true
		else:
			camera.current = true
			camera.fov = float(view.get("fov",65))
			camera.look_at_from_position(view.eye,view.target,view.get("up",Vector3.UP))
		for _i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output+"/"+view.id+".png") == OK)
		print("POPULATION_CAPTURE ",view.id)
	world.queue_free()
	await process_frame
	quit(0)
