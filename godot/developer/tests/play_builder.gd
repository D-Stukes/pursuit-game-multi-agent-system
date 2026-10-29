extends SceneTree
## Rendered normal-keyboard conversation, optionally using the explicit mock fixture.
var world: Node3D
var social: Node3D
var output: String="res://.godot/playtest/builder-captures"
var receipt: Dictionary={"input_driven":true,"provider_network_calls":0,"fixture":false}

func _initialize() -> void: call_deferred("run")
func frames(count: int=3) -> void:
	for _i: int in range(count):await physics_frame
func key(code: Key) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	Input.parse_input_event(e);await process_frame;await frames(2)
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame;await frames(2)
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK)
	print("BUILDER_CAPTURE ",name)
func choose(index: int) -> void:
	social.dialogue.choices[index].grab_focus();await process_frame;await key(KEY_ENTER)
	var deadline: int=Time.get_ticks_msec()+10000
	while not social.pending.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	await frames();assert(social.pending.is_empty() and not social.dialogue.waiting)

func run() -> void:
	var url: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--fixture-url="):url=arg.trim_prefix("--fixture-url=")
	DirAccess.make_dir_recursive_absolute(output)
	receipt.source_hashes={}
	for path: String in ["project.godot","Main.tscn","game/Main.gd","game/GameHUD.gd","game/GameOrchestrator.gd","game/PipePuzzleState.gd","game/NPCConversations.gd","game/NPCConversationState.gd","game/NPCDialoguePanel.gd","game/NPCServiceClient.gd","assets/characters/npc-dialogue.json","assets/characters/population.json","developer/tests/play_builder.gd"]:
		receipt.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.frame_budget_enabled=false;Engine.max_fps=60;await frames(12)
	social=world.npc_conversations
	if not url.is_empty():
		social.client.provider="claude";social.client.base_url=url;receipt.fixture=true
	assert(social.requests_started==0 and not world.building_review_mode)
	# Walk from the normal street spawn; no teleport or earned-progress fixture.
	var destination:=Vector3(-1.65,0,6.7)
	# Script launches disable movement capture; normal game launches enable it.
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool=false
	for _i: int in range(180):
		var delta: Vector3=destination-world.player.global_position;delta.y=0
		if delta.length()<.12:arrived=true;break
		world.player.camera_pivot.rotation.y=atan2(-delta.x,-delta.z);await physics_frame
	Input.action_release("walk_forward");await frames(6)
	assert(arrived,"Builder approach failed: feet=%s controls=%s"%[world.player.global_position,world.player.controls_active])
	assert(social.reachable_npc().id=="BuilderCompanion")
	await capture("builder-approach");await key(KEY_E)
	assert(social.dialogue.visible and social.dialogue.status.text=="Scripted greeting" and social.requests_started==0)
	await capture("builder-greeting")
	await choose(1);assert(social.dialogue.text_label.text.contains("Board 1"))
	await capture("builder-hint")
	await choose(2);assert(social.dialogue.text_label.text.begins_with("1. "))
	root.content_scale_size=Vector2i(800,600);root.size=Vector2i(800,600);await frames(8)
	await capture("builder-steps-800")
	await choose(0)
	assert(social.state.memory("BuilderCompanion").lines.size()==2 and social.state.memory("BuilderCompanion").facts.style=="steps")
	await key(KEY_ESCAPE)
	var calls_before: int=social.requests_started
	await create_timer(.5).timeout
	assert(social.requests_started==calls_before and not world.player.controls_locked)
	await capture("builder-back-to-game")
	receipt.memory=social.state.memory("BuilderCompanion")
	receipt.requests_started=social.requests_started;receipt.last_usage=social.last_usage
	receipt.final=world.orchestrator.snapshot()
	assert(not receipt.final.gates.entrance and not receipt.final.gates.elevator and receipt.final.course.energy==10 and receipt.final.course.score==0)
	var file:=FileAccess.open(output+"/playthrough.json",FileAccess.WRITE)
	assert(file!=null);file.store_string(JSON.stringify(receipt,"  "));file.close()
	print("BUILDER_PLAYTHROUGH PASS requests=",social.requests_started," fixture=",receipt.fixture)
	world.queue_free();await process_frame;quit(0)
