extends SceneTree
## Rendered normal-keyboard conversation with explicit local, mock or live mode.
var world: Node3D
var social: Node3D
var output: String="res://.godot/playtest/builder-captures"
var receipt: Dictionary={"input_driven":true,"provider_network_calls":0,"fixture":false}
var live_api: bool=false
var live_topics: PackedStringArray=["hint","steps","next"]

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
func save_receipt() -> void:
	var file:=FileAccess.open(output+"/playthrough.json",FileAccess.WRITE)
	assert(file!=null);file.store_string(JSON.stringify(receipt,"  "));file.close()
func choose(index: int) -> bool:
	var started: int=Time.get_ticks_msec()
	social.dialogue.choices[index].grab_focus();await process_frame;await key(KEY_ENTER)
	var deadline: int=Time.get_ticks_msec()+10000
	while not social.pending.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	await frames()
	var accepted: bool=social.pending.is_empty() and not social.dialogue.waiting
	if live_api: accepted=accepted and social.last_reply.get("provider")=="claude" and not social.last_reply.get("fallback",true)
	receipt.turns.append({"topic":str(social.dialogue.choices[index].get_meta("topic")),
		"text":social.dialogue.text_label.text,"status":social.dialogue.status.text,
		"reply_source":social.last_reply.duplicate(true),
		"elapsed_ms":Time.get_ticks_msec()-started,
		"usage":social.last_usage.duplicate(true) if social.last_reply.get("provider")=="claude" else {}})
	if not accepted:
		receipt.failure="live_reply_not_accepted" if live_api else "reply_not_completed"
		save_receipt();print("BUILDER_PLAYTHROUGH FAIL ",receipt.failure);quit(1)
	return accepted

func run() -> void:
	var url: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--fixture-url="):url=arg.trim_prefix("--fixture-url=")
		elif arg=="--live-api":live_api=true
		elif arg.begins_with("--live-topics="):live_topics=arg.trim_prefix("--live-topics=").split(",")
	DirAccess.make_dir_recursive_absolute(output)
	assert(not live_api or url.is_empty(),"Live and mock modes cannot be combined")
	receipt.mode="live" if live_api else ("mock" if not url.is_empty() else "local")
	receipt.turns=[]
	if live_api:
		assert(live_topics.size()>0 and live_topics.size()<=3)
		for topic: String in live_topics: assert(topic in ["hint","steps","next"])
	if live_api: receipt.provider_network_calls=null # The Python audit counts actual API requests.
	receipt.source_hashes={}
	for path: String in ["project.godot","Main.tscn","game/Main.gd","game/GameHUD.gd","game/GameOrchestrator.gd","game/PipePuzzleState.gd","game/NPCConversations.gd","game/NPCConversationState.gd","game/NPCDialoguePanel.gd","game/NPCServiceClient.gd","assets/characters/npc-dialogue.json","assets/characters/population.json","developer/tests/play_builder.gd"]:
		receipt.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.frame_budget_enabled=false;Engine.max_fps=60;await frames(12)
	social=world.npc_conversations
	if live_api: assert(social.client.provider=="claude" and social.client.valid_url())
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
	assert(social.dialogue.visible and not social.dialogue.status.visible and social.last_reply.is_empty() and social.requests_started==0)
	receipt.greeting_provider_requests=social.requests_started
	await capture("builder-greeting")
	if live_api:
		for topic: String in live_topics:
			if not await choose(["next","hint","steps"].find(topic)):return
			if topic=="steps":
				root.content_scale_size=Vector2i(800,600);root.size=Vector2i(800,600);await frames(8)
			await capture("builder-live-"+topic)
		assert(social.state.memory("BuilderCompanion").lines.size()==mini(live_topics.size(),2))
		if "steps" in live_topics: assert(social.state.memory("BuilderCompanion").facts.style=="steps")
	else:
		if not await choose(1):return
		assert(social.dialogue.text_label.text.contains("Board 1"));await capture("builder-hint")
		if not await choose(2):return
		assert(social.dialogue.text_label.text.begins_with("1. "))
		root.content_scale_size=Vector2i(800,600);root.size=Vector2i(800,600);await frames(8)
		await capture("builder-steps-800")
		if not await choose(0):return
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
	save_receipt()
	print("BUILDER_PLAYTHROUGH PASS requests=",social.requests_started," fixture=",receipt.fixture)
	world.queue_free();await process_frame;quit(0)
