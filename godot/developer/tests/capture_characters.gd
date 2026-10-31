extends SceneTree
## Capture the imported asset with its actual skin/animations in Godot.
func _initialize()->void:call_deferred("run")
func run()->void:
	var view:Node3D=load("res://developer/CharacterReview.tscn").instantiate();root.add_child(view)
	root.size=Vector2i(900,1000);root.content_scale_size=root.size
	for i in range(10):await process_frame
	if not view.ready_for_test:quit(1);return
	var folder:String="res://.godot/playtest/characters"
	if OS.get_cmdline_user_args().has("--unshadowed"):
		folder+="-unshadowed"
		for light:DirectionalLight3D in view.find_children("*","DirectionalLight3D",true,false):light.shadow_enabled=false
	DirAccess.make_dir_recursive_absolute(folder)
	for item:Array in [["front",0.0,"Idle",0.0],["profile",PI/2,"Idle",0.0],["back",PI,"Idle",0.0],["three-quarter",.6,"Idle",0.0],["welcome",.35,"Welcome",1.5],["guide",.35,"Guide",1.5],["blink",0.0,"Idle",46.0/24],["blink-three-quarter",.6,"Idle",46.0/24]]:
		view.yaw=item[1];view.update_camera();view.play_clip(item[2]);view.animation.pause();view.animation.seek(item[3],true);view.animation.advance(0)
		for i in range(6):await process_frame
		# Forced draw: a covered or background macOS window never posts a frame.
		await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_png(folder+"/mr-p-"+item[0]+".png")
		print("CHARACTER_CAPTURE ",item[0])
	view.load_asset("robot")
	for i in range(8):await process_frame
	for item:Array in [["front",0.0,"Idle",0.0],["profile",PI/2,"Idle",0.0],["back",PI,"Idle",0.0],["three-quarter",.6,"Idle",0.0],["power-on",.4,"PowerOn",1.5],["assembling",.4,"Assemble",.5],["assembled",.4,"Assemble",3.95]]:
		view.yaw=item[1];view.update_camera();view.play_clip(item[2]);view.animation.pause();view.animation.seek(item[3],true);view.animation.advance(0)
		for i in range(6):await process_frame
		await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_png(folder+"/robot-"+item[0]+".png")
		print("ROBOT_CAPTURE ",item[0])
	view.show_2d_button.button_pressed=true
	for i in range(6):await process_frame
	await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(folder+"/robot-2d-complete.png")
	view.parts_buttons.get_child(5).button_pressed=false
	view.parts_buttons.get_child(3).button_pressed=false
	for i in range(6):await process_frame
	await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(folder+"/robot-2d-partial.png")
	print("ROBOT_2D_CAPTURE complete and partial")
	view.queue_free();await process_frame;await preload("res://developer/tests/AudioTeardown.gd").release(self);quit()
