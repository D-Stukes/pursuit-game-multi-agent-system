extends SceneTree
## Exercise the shipping HTTP client with the explicit local SDK test fixture.
const Pilot = preload("res://playtest/tests/NPCTestPilot.gd")
var checks: int=0
var failures: int=0
var world: Node3D
var social: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks+=1
	if not passed: failures+=1
	print("PASS " if passed else "FAIL ",label)

func frames(count: int=4) -> void:
	for _i: int in range(count): await physics_frame

func wait_reply() -> void:
	var until: int=Time.get_ticks_msec()+5000
	while not social.pending.is_empty() and Time.get_ticks_msec()<until: await process_frame
	await frames(3)

func run() -> void:
	var url: String=""
	var redirect_url: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture-url="):url=arg.trim_prefix("--fixture-url=")
		elif arg.begins_with("--redirect-url="):redirect_url=arg.trim_prefix("--redirect-url=")
	assert(not url.is_empty(),"Run through tools/verify_npc_service.py")
	world=load("res://BuildingPlaytest.tscn").instantiate();root.add_child(world)
	await frames(10)
	social=world.npc_conversations
	social.client.provider="claude";social.client.base_url=url
	check("fixture URL is explicitly loopback",social.client.valid_url())
	Pilot.approach(world,"ReceptionA");await frames(3)
	check("scripted greeting opens without service turn",social.try_talk() and social.pending.is_empty())
	social._on_topic("directions");await wait_reply()
	check("real HTTP and SDK tool loop deliver correlated reply",social.dialogue.status.text=="Claude reply" and social.dialogue.text_label.text.contains("SDK fixture reply for Reception guide"))
	check("successful HTTP reply commits memory once",social.state.memory("ReceptionA").turn_count==1)
	check("duplicate delivered response is ignored",not social.accept_reply({"schema":1,"request_id":"npc-1","npc_id":"ReceptionA","topic":"directions","text":"duplicate","mode":"claude"}) and social.state.memory("ReceptionA").turn_count==1)
	social._on_topic("day");await wait_reply()
	check("wrong response identity uses labelled local fallback",social.dialogue.status.text.contains("Claude unavailable") and not social.dialogue.text_label.text.contains("SDK fixture"))
	check("fallback records one accepted local turn",social.state.memory("ReceptionA").turn_count==2)
	social._on_topic("work");await frames(4)
	check("slow request is pending before interruption",not social.pending.is_empty() and not social.client.active_id.is_empty())
	social.dialogue.close()
	Pilot.approach(world,"ReceptionB");await frames(3);social.try_talk()
	social._on_topic("directions");await wait_reply()
	await create_timer(.8).timeout
	check("late cancelled A reply cannot replace B reply",social.active_npc=="ReceptionB" and social.dialogue.text_label.text.contains("SDK fixture reply for Builder at reception") and social.state.memory("ReceptionA").turn_count==2 and social.state.memory("ReceptionB").turn_count==1)
	social.client.timeout_seconds=.15
	social._on_topic("work");await wait_reply()
	check("HTTP timeout gives finite local fallback",social.pending.is_empty() and not social.dialogue.waiting and social.dialogue.status.text.contains("Claude unavailable"))
	social.client.timeout_seconds=8
	social.client.base_url="http://remote.invalid:8765"
	social._on_topic("directions");await wait_reply()
	check("nonlocal URL is rejected without network",not social.client.valid_url() and social.dialogue.status.text.contains("Claude unavailable"))
	social.client.base_url=redirect_url
	social._on_topic("directions");await wait_reply()
	check("HTTP redirect is rejected with local fallback",social.dialogue.status.text.contains("Claude unavailable") and social.pending.is_empty())
	social.client.base_url=url
	social._on_topic("work");await frames(3)
	world.set_menu_open(true);await create_timer(.8).timeout
	check("Settings cancels wire reply and restores modal ownership",world.hud.menu_open and not social.dialogue.visible and social.pending.is_empty() and social.client.active_id.is_empty() and world.player.controls_locked)
	world.set_menu_open(false)
	world.go_location(0);await frames(3)
	social.cooldown=0
	world.go_location(1);await frames(3)
	for _i: int in range(4):
		social.ambient_remaining=0;social.update(.02);await wait_reply()
	check("four ambient lines also use validated SDK transport",social.ambient_lines_shown==4 and social.caption_speaker.text.contains("Claude"))
	check("ambient transport keeps private memory isolated",social.state.public_memories.size()==2 and social.state.memory("ReceptionA").turn_count==2)
	check("wire integration grants no game rewards",not world.entrance_puzzle.state.unlocked and not world.elevator_game.state.completed())
	print("NPC_SERVICE_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
