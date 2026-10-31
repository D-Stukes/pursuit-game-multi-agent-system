extends SceneTree
## Capture the actual computer, fade and room trip from the normal player camera.
var world: Node3D
var output: String = "res://.godot/playtest/portal-captures"

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(output+"/"+name+".png")
	assert(result==OK)
	print("PORTAL_CAPTURE ",name)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.frame_budget_enabled = false
	Engine.max_fps = 60
	world.set_building_review_mode(true)
	world.go_location(2)
	world.player.set_controls_active(false)
	for _i in range(15):await physics_frame
	await capture("computers-classroom")
	world.player.teleport_to(Vector3(-4.640003,5.075,-2.206048),-PI/2)
	for _i in range(15):await physics_frame
	world.computer_portal.update_prompts(1)
	await capture("computer-use-prompt")
	await key(KEY_E)
	await create_timer(.08).timeout
	await capture("fade-to-room")
	while world.hud.travel_overlay.color.a<.99 and world.computer_portal.transitioning:await process_frame
	await capture("opaque-teleport")
	if world.computer_portal.transitioning:await world.computer_portal.transition_finished
	assert(world.computer_portal.inside)
	for _i in range(12):await process_frame
	await capture("purple-room-player")
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	for _i in range(22):await physics_frame
	Input.action_release("walk_forward")
	for _i in range(8):await physics_frame
	await capture("purple-room-exploration")
	world.player.teleport_to(world.computer_portal.room.return_point.global_position+Vector3(0,0,.55),0)
	for _i in range(10):await physics_frame
	world.computer_portal.update_prompts(1)
	await capture("purple-room-return")
	await key(KEY_E)
	if world.computer_portal.transitioning:await world.computer_portal.transition_finished
	for _i in range(8):await physics_frame
	await capture("returned-to-computer")
	world.queue_free()
	await process_frame
	await preload("res://developer/tests/AudioTeardown.gd").release(self)
	quit()
