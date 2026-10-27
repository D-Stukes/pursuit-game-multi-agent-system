extends SceneTree
## Render the actual exported model at reference-matched viewpoints.
var world: Node3D
var camera: Camera3D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	world=Node3D.new()
	root.add_child(world)
	var args:=OS.get_cmdline_user_args()
	var model_path: String="res://assets/generated/pursuit-photo-candidate.glb"
	for arg: String in args:
		if arg.begins_with("--model="):model_path=arg.trim_prefix("--model=")
	var packed: PackedScene=load(model_path)
	if not packed:
		quit(1);return
	world.add_child(packed.instantiate())
	var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR;e.background_color=Color(.53,.68,.79)
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.93,.94,1);e.ambient_light_energy=.65
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env:=WorldEnvironment.new();env.environment=e;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);sun.light_energy=1.4;sun.shadow_enabled=true;world.add_child(sun)
	camera=Camera3D.new();camera.current=true;camera.fov=72;camera.near=.05;camera.far=300;world.add_child(camera)
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var output: String="res://.godot/playtest/redesign"
	DirAccess.make_dir_recursive_absolute(output)
	# Positions are Blender-space [right,depth,height] and converted exactly once.
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/building-layout.json"))
	var views:Array=manifest.review_views
	for view: Dictionary in views:
		camera.look_at_from_position(point(view.position),point(view.target),Vector3.UP)
		for _i in range(4):await process_frame
		await RenderingServer.frame_post_draw
		var img:=root.get_texture().get_image()
		var error: Error=img.save_png(output+"/"+view.id+".png")
		if error!=OK:quit(1);return
		print("ENVIRONMENT_CAPTURE ",view.id," ",img.get_size())
	world.queue_free();await process_frame;quit(0)
func to_godot(v:Vector3)->Vector3:
	return Vector3(v.x,v.z,-v.y)

func point(p:Array)->Vector3:
	return Vector3(float(p[0]),float(p[2]),-float(p[1]))
