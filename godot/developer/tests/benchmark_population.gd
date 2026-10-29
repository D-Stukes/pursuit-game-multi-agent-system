extends SceneTree
## Rendered A/B frame-time sample with the same cast/building, toggling ambient NPCs.
const SAMPLES: int = 180
const VIEWS: Array[Dictionary] = [
	{"id":"street", "eye":Vector3(0,2.3,14), "target":Vector3(0,1.2,5.5), "floor":0.0},
	{"id":"ground_hall", "eye":Vector3(1.2,2.4,-5.7), "target":Vector3(2.65,1.6,-8.7), "floor":.85},
	{"id":"reception", "eye":Vector3(.9,7.1,-10.3), "target":Vector3(5.3,6.1,-5.8), "floor":5.05},
	{"id":"classroom", "eye":Vector3(3.5,7.4,-2.7), "target":Vector3(-5,6.3,2), "floor":5.05},
	{"id":"commons", "eye":Vector3(-9,7.1,-10), "target":Vector3(-16,6,-12), "floor":5.05}
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Frame-time proof requires a rendered run")
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Array[Dictionary] = []
	for populated: bool in [false,true]:
		var world: Node3D = load("res://Main.tscn").instantiate()
		world.include_population = populated
		root.add_child(world)
		world.frame_budget_enabled = false
		Engine.max_fps = 0
		world.player.hide()
		world.hud.hide()
		world.player.set_controls_active(false)
		var camera := Camera3D.new()
		camera.fov = 75
		camera.current = true
		world.add_child(camera)
		for _i in range(10): await physics_frame
		for view: Dictionary in VIEWS:
			camera.look_at_from_position(view.eye,view.target)
			world.player.teleport_to(Vector3(view.eye.x,view.floor,view.eye.z))
			if populated: world.population.update_budget()
			for _i in range(60): await process_frame
			var times: Array[float] = []
			var draws: int = 0
			var primitives: int = 0
			var previous: int = Time.get_ticks_usec()
			var peak_idle: int = 0
			for _i in range(SAMPLES):
				await RenderingServer.frame_post_draw
				var now: int = Time.get_ticks_usec()
				times.append((now-previous)/1000.0)
				previous = now
				draws = maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
				primitives = maxi(primitives,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
				if populated: peak_idle = maxi(peak_idle,world.population.active_count)
			times.sort()
			var result := {"view":view.id,"population":populated,"samples":SAMPLES,"median_ms":times[SAMPLES/2],"p95_ms":times[int(SAMPLES*.95)],"max_draw_calls":draws,"max_primitives":primitives,"peak_idle_actors":peak_idle}
			results.append(result)
			print("POPULATION_BENCHMARK ",JSON.stringify(result))
		world.queue_free()
		for _i in range(4): await process_frame
	var output: String = "res://.godot/playtest/population-benchmark.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var receipt := {"gpu":RenderingServer.get_video_adapter_name(),"driver":OS.get_video_adapter_driver_info(),"viewport":[1280,720],"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method","gl_compatibility"),"vsync":"disabled","frame_cap":0,"warmup_frames":60,"evidence":"Rendered local fixed-camera frame times, retained imported assets; not GPU-only time or all-hardware certification","results":results}
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(receipt,"  "))
	quit(0)
