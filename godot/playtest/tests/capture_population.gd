extends SceneTree
## Capture the actual integrated world, with no desktop automation or art substitutes.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://BuildingPlaytest.tscn").instantiate()
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
		{"id":"mr-p-classroom", "eye":Vector3(-.2,6.9,.7), "target":Vector3(1.8,6.65,3.4)},
		{"id":"robot-repair", "eye":Vector3(-11.4,7.4,3.6), "target":Vector3(-14.05,6.05,1.8)},
		{"id":"robot-overhead", "eye":Vector3(-14.05,8.3,1.8), "target":Vector3(-14.05,5.858,1.8), "up":Vector3.FORWARD, "fov":70},
		{"id":"classroom-cast", "eye":Vector3(.3,7.0,-2.7), "target":Vector3(-6,6.1,1.4)}
	]
	for view: Dictionary in views:
		camera.fov = float(view.get("fov",65))
		camera.look_at_from_position(view.eye,view.target,view.get("up",Vector3.UP))
		for _i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output+"/"+view.id+".png") == OK)
		print("POPULATION_CAPTURE ",view.id)
	world.queue_free()
	await process_frame
	quit(0)
