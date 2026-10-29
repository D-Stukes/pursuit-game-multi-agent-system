extends SceneTree
## Normal menus, explicit developer bypass, and the disabled-tool configuration.
var world: Node3D
var output: String="res://.godot/playtest/developer-captures"
var receipt: Dictionary={"provider_calls":0,"developer_setup":true,"source_hashes":{}}

func _initialize() -> void:
	call_deferred("run")

func frames(count: int=5) -> void:
	for _i: int in range(count):await physics_frame

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)

func activate(button: Button) -> void:
	button.grab_focus();await process_frame;await key(KEY_ENTER)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
	print("DEVELOPER_CAPTURE ",name)

func resolution(size: Vector2i) -> void:
	root.content_scale_size=size;root.size=size;await frames(8)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	for path: String in ["project.godot","Main.tscn","game/Main.gd","game/GameHUD.gd","game/GameOrchestrator.gd","game/SessionState.gd","developer/DeveloperTools.gd","developer/tests/capture_developer_tools.gd"]:
		receipt.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.frame_budget_enabled=false;Engine.max_fps=60;await frames(12)
	assert(not world.building_review_mode and world.npc_conversations.client.provider=="local")
	await key(KEY_ESCAPE)
	assert(not world.hud.debug_mode and not world.hud.developer.controls.visible)
	await capture("game-settings")
	await activate(world.hud.developer.entry_button)
	assert(world.hud.debug_mode and not world.hud.controls_label.visible)
	await resolution(Vector2i(800,600));await capture("developer-tools-800")
	await activate(world.hud.developer.bypass_toggle)
	assert(world.building_review_mode and not world.orchestrator.gates_earned())
	await capture("developer-bypass-800")
	await activate(world.hud.resume_button)
	await resolution(Vector2i(1280,720));await capture("developer-review-game")
	# Explicit developer-position fixture; real movement must pass the closed gate.
	world.player.teleport_to(Vector3(0,0,5.7));await frames(10)
	Input.action_press("walk_forward");await frames(45);Input.action_release("walk_forward")
	receipt.bypass_door_walk=world.player.global_position.z<4.3
	assert(receipt.bypass_door_walk)
	world.player.teleport_to(world.LIFT_GROUND);await frames(12);await key(KEY_E)
	assert(world.lift_in_progress and not world.elevator_game.visible)
	await world.lift_finished;await frames(8)
	await capture("developer-upstairs")
	receipt.review_state=world.orchestrator.snapshot()
	assert(not receipt.review_state.gates.entrance and not receipt.review_state.gates.elevator)
	await key(KEY_ESCAPE);await activate(world.hud.developer.entry_button)
	var entrance: Button=world.hud.developer.controls.get_children().filter(func(node: Node):return node is Button and node.text.begins_with("Entrance"))[0]
	await activate(entrance)
	assert(not world.hud.menu_open and world.player.global_position.y<1)
	await key(KEY_ESCAPE);await activate(world.hud.developer.entry_button)
	await activate(world.hud.developer.bypass_toggle);await activate(world.hud.resume_button)
	assert(not world.building_review_mode and world.entrance_gate.collision_layer==4 and not world.orchestrator.gates_earned())
	await capture("normal-game-restored")
	receipt.normal_restored=world.orchestrator.snapshot()
	world.queue_free();await process_frame
	world=load("res://Main.tscn").instantiate();world.enable_developer_tools=false;root.add_child(world)
	world.frame_budget_enabled=false;await frames(12)
	assert(world.hud.developer==null)
	await resolution(Vector2i(800,600));await key(KEY_ESCAPE)
	await capture("player-only-settings-800")
	receipt.player_only_has_no_developer_component=world.hud.developer==null
	var file:=FileAccess.open(output+"/developer-capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt,"  "));file.close()
	print("DEVELOPER_CAPTURE PASS ",JSON.stringify(receipt))
	world.queue_free();await process_frame;quit()
