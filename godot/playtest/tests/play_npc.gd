extends SceneTree
## Actual in-engine local-preview conversation and room exchange, without API key.
const Pilot = preload("res://playtest/tests/NPCTestPilot.gd")
var output: String="res://.godot/playtest/npc-captures"

func _initialize() -> void:
	call_deferred("run")

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	for _i: int in range(3): await process_frame

func activate(button: Button) -> void:
	button.grab_focus();await key(KEY_ENTER)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
	print("NPC_CAPTURE ",name)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var world: Node3D=load("res://BuildingPlaytest.tscn").instantiate();root.add_child(world)
	world.frame_budget_enabled=false;Engine.max_fps=60
	for _i: int in range(10): await physics_frame
	var social: Node3D=world.npc_conversations
	assert(Pilot.approach(world,"ReceptionA")!=Vector3.INF)
	world.player.set_controls_active(false)
	for _i: int in range(10): await physics_frame
	await capture("reception-talk-prompt")
	var deadline: int=Time.get_ticks_msec()+22000
	var first: bool=false
	while social.ambient_lines_shown<4 and Time.get_ticks_msec()<deadline:
		if social.ambient_lines_shown>0 and not first:
			await capture("ambient-exchange");first=true
		await process_frame
	assert(social.ambient_lines_shown==4)
	await key(KEY_E)
	assert(social.dialogue.visible and social.active_npc=="ReceptionA")
	await capture("scripted-greeting")
	await activate(social.dialogue.choices[0])
	assert(social.state.memory("ReceptionA").turn_count==1)
	await capture("local-npc-conversation")
	await key(KEY_ESCAPE);await key(KEY_E)
	assert(social.dialogue.text_label.text==social.state.data.profiles.ReceptionA.return_greeting)
	await capture("remembered-greeting")
	await activate(social.dialogue.choices[0])
	assert(social.dialogue.text_label.text.begins_with("We talked about that earlier."))
	await capture("remembered-topic")
	await key(KEY_ESCAPE)
	assert(Pilot.approach(world,"ReceptionB")!=Vector3.INF)
	for _i: int in range(8): await physics_frame
	await key(KEY_E)
	await activate(social.dialogue.choices[1])
	assert(social.state.memory("ReceptionB").turn_count==1)
	await capture("second-npc")
	root.content_scale_size=Vector2i(800,600);root.size=Vector2i(800,600)
	for _i: int in range(8): await physics_frame
	await capture("conversation-800")
	await key(KEY_ESCAPE)
	var receipt: Dictionary={"mode":"local","paid_calls":0,"ambient_lines":social.ambient_lines_shown,
		"npc_a_turns":social.state.memory("ReceptionA").turn_count,"npc_b_turns":social.state.memory("ReceptionB").turn_count,
		"controls_restored":not world.player.controls_locked,"no_game_rewards":not world.entrance_puzzle.state.unlocked and not world.elevator_game.state.completed(),"source_hashes":{}}
	for path: String in ["playtest/BuildingPlaytest.gd","playtest/NPCConversations.gd","playtest/NPCConversationState.gd","playtest/NPCDialoguePanel.gd","playtest/NPCServiceClient.gd","assets/characters/npc-dialogue.json","playtest/tests/play_npc.gd"]:
		receipt.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open(output+"/playthrough.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt,"  "));file.close()
	assert(receipt.controls_restored and receipt.no_game_rewards)
	print("NPC_PLAYTHROUGH PASS ",JSON.stringify(receipt))
	world.queue_free();await process_frame;quit()
