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
	var model_path: String="res://assets/generated/pursuit-building.glb"
	var custom_views:String=""
	var output:String="res://.godot/playtest/redesign"
	for arg: String in args:
		if arg.begins_with("--model="):model_path=arg.trim_prefix("--model=")
		if arg.begins_with("--views="):custom_views=arg.trim_prefix("--views=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var packed: PackedScene=load(model_path)
	if not packed:
		quit(1);return
	world.add_child(packed.instantiate())
	preload("res://game/EnvironmentLighting.gd").setup(world)
	camera=Camera3D.new();camera.current=true;camera.fov=72;camera.near=.05;camera.far=300;world.add_child(camera)
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	# Positions are Blender-space [right,depth,height] and converted exactly once.
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/building-layout.json"))
	var views:Array=manifest.review_views.duplicate(true)
	views.append_array(manifest.get("detail_review_views",[]))
	if not custom_views.is_empty():
		var supplied:Variant=JSON.parse_string(FileAccess.get_file_as_string(custom_views))
		if not supplied is Array:
			push_error("Review views must be an array");quit(1);return
		views=supplied
	for view: Dictionary in views:
		camera.fov=float(view.get("fov",72))
		camera.look_at_from_position(point(view.position),point(view.target),Vector3.UP)
		for _i in range(4):await process_frame
		await RenderingServer.frame_post_draw
		var img:=root.get_texture().get_image()
		var error: Error=img.save_png(output+"/"+view.id+".png")
		if error!=OK:quit(1);return
		print("ENVIRONMENT_CAPTURE ",view.id," ",img.get_size())
	world.queue_free();await process_frame;await preload("res://developer/tests/AudioTeardown.gd").release(self);quit(0)
func point(p:Array)->Vector3:
	return Vector3(float(p[0]),float(p[2]),-float(p[1]))
