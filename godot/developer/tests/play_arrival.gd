extends SceneTree
## Rendered, input-driven arrival. Earlier puzzle wins are explicit fixtures.
const GatePilot = preload("res://developer/tests/verify_check_in.gd")
var world: Node3D
var output: String
var captures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func frames(count: int = 5) -> void:
	for _i: int in range(count): await physics_frame

func key(code: int, letter: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.unicode = letter; event.pressed = true
	Input.parse_input_event(event); await process_frame; await frames(2)
	event = event.duplicate(); event.pressed = false
	Input.parse_input_event(event); await process_frame; await frames(2)

func walk_to(target: Vector3) -> void:
	var timeout: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < timeout:
		var difference: Vector3 = target - world.player.global_position
		difference.y = 0
		if difference.length() < .12: break
		world.player.camera_pivot.rotation.y = atan2(-difference.x, -difference.z)
		Input.action_press("walk_forward")
		await physics_frame
	Input.action_release("walk_forward"); await frames()
	assert(Vector2(target.x-world.player.global_position.x,target.z-world.player.global_position.z).length() < .2, "Arrival path blocked")

func capture(label: String) -> void:
	# Forced draw: a covered or background macOS window never posts a frame.
	await frames(5); RenderingServer.force_draw()
	var path: String = output.path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	captures.append(path)
	print("ARRIVAL_CAPTURE ", label)

func run() -> void:
	output = ProjectSettings.globalize_path("res://.godot/playtest/arrival-capture")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://Main.tscn").instantiate(); root.add_child(world)
	await frames(12)
	world.frame_budget_enabled = false; Engine.max_fps = 60
	# Solving gates is setup, not evidence of player input for those earlier games.
	GatePilot.solve_gates(world)
	world.player.teleport_to(world.UPPER_LIFT_EXIT)
	world.player.set_controls_active(true)
	await frames()
	await walk_to(Vector3(1.05,5.05,-7.6))
	await walk_to(Vector3(1.05,5.05,-5.22))
	await walk_to(Vector3(3.1,5.05,-5.22))
	var toward: Vector3 = world.check_in.computer.point - world.player.global_position
	world.player.camera_pivot.rotation.y = atan2(-toward.x,-toward.z)
	await capture("arrival-reception")
	await key(KEY_E)
	assert(world.check_in.is_open)
	await capture("check-in-name")
	for character: String in "Robin": await key(character.to_upper().unicode_at(0), character.unicode_at(0))
	assert(world.check_in.name_input.text == "Robin")
	await key(KEY_ENTER)
	await create_timer(.6).timeout
	assert(world.check_in.state.phase == world.check_in.Rules.Phase.PHOTO)
	await capture("check-in-photo")
	root.size = Vector2i(800,600); root.content_scale_size = Vector2i(800,600)
	await capture("check-in-photo-800")
	await key(KEY_ENTER)
	if not world.orchestrator.checked_in():
		print("ARRIVAL_PLAYTHROUGH FAIL confirmation_not_received")
		quit(1); return
	await capture("check-in-confirmed-800")
	await key(KEY_ENTER)
	var sequence: Node = world.classroom_sequence
	var deadline: int = Time.get_ticks_msec()+20000
	for beat: String in ["walk","stand_up","crowd","get_to_work"]:
		while sequence.active and sequence.phase != beat and Time.get_ticks_msec()<deadline: await physics_frame
		assert(sequence.active and sequence.phase == beat,"Missing classroom beat: "+beat)
		await capture("classroom-"+beat+"-800")
	while sequence.active and Time.get_ticks_msec()<deadline: await physics_frame
	assert(not sequence.active and not world.player.controls_locked and world.orchestrator.snapshot().stage == "mr_p_pending")
	await capture("classroom-ready-800")
	var receipt := {"mode":"fixture","earlier_gate_wins":"fixture setup", "arrival_input":"held walking / E / typed name / Enter / Esc",
		"captures":captures,"stage":world.orchestrator.snapshot().stage,"course":world.orchestrator.snapshot().course,
		"provider_requests":world.npc_conversations.requests_started,
		"classroom_beats":sequence.state.presented,"synthetic_crowd":sequence.crowd.stream != null}
	receipt.source_hashes = {}
	for name: String in ["Main", "SessionState", "SessionEvent", "GameOrchestrator", "CheckInState", "CheckInConsole", "ClassroomState", "ClassroomSequence", "ComputerPortal", "NPCConversations", "NPCConversationState"]:
		var path: String = "res://game/"+name+".gd"
		receipt.source_hashes[path] = FileAccess.get_sha256(path)
	receipt.source_hashes["res://developer/tests/play_arrival.gd"] = FileAccess.get_sha256("res://developer/tests/play_arrival.gd")
	receipt.source_hashes["res://assets/characters/population.json"] = FileAccess.get_sha256("res://assets/characters/population.json")
	var file := FileAccess.open(output.path_join("playthrough.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  ")); file.close()
	print("ARRIVAL_PLAYTHROUGH PASS")
	world.queue_free(); await process_frame; await preload("res://developer/tests/AudioTeardown.gd").release(self);quit(0)
