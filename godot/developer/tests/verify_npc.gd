extends SceneTree
var checks: int = 0
var failures: int = 0
var world: Node3D
var player: CharacterBody3D
var social: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ",label)

func frames(count: int = 4) -> void:
	for _i: int in range(count): await physics_frame

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)

func activate(button: Button) -> void:
	button.grab_focus()
	await process_frame
	await key(KEY_ENTER)
	# Physics catch-up ticks are not an idle/deferred-delivery barrier.
	await process_frame
	var deadline: int=Time.get_ticks_msec()+1000
	while not social.pending.is_empty() and Time.get_ticks_msec()<deadline: await process_frame

func approach(id: String) -> Vector3:
	return preload("res://developer/tests/NPCTestPilot.gd").approach(world,id)

func run() -> void:
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	await frames(10)
	player=world.player;social=world.npc_conversations
	check("two reception actors and one reused street Builder registered",social.actors.size()==3)
	check("social memory starts empty",social.state.memories.is_empty() and social.state.public_memories.is_empty())
	check("street has no remote talk target",not social.try_talk() and social.context_prompt().is_empty())
	world.go_location(1);await frames(4)
	check("uncontacted reception entry triggers no chatter or provider",not social.ambient_active and social.requests_started==0)
	for id: String in ["ReceptionA","ReceptionB"]:
		var feet: Vector3=approach(id)
		check("collision-free visible talk approach "+id,feet!=Vector3.INF)
		if feet==Vector3.INF: continue
		await frames(4)
		await key(KEY_E)
		check("E opens correct NPC greeting "+id,social.dialogue.visible and social.active_npc==id and social.dialogue.status.text=="Scripted greeting")
		check("greeting makes no agent turn "+id,social.state.memory(id).turn_count==0 and social.pending.is_empty())
		check("dialogue locks world and portal "+id,player.controls_locked and not world.computer_portal.try_use() and not world.try_lift())
		var before: Vector3=player.global_position
		Input.action_press("walk_forward");await frames(8);Input.action_release("walk_forward")
		await key(KEY_R);await key(KEY_3)
		check("dialogue blocks movement reset and shortcuts "+id,player.global_position.distance_to(before)<.01)
		await activate(social.dialogue.choices[0])
		check("choice produces scripted reply "+id,social.dialogue.status.text=="Scripted reply" and social.dialogue.text_label.text.contains("double doors"))
		check("reply records only selected NPC "+id,social.state.memory(id).turn_count==1 and social.state.memory(id).topics==["directions"])
		var count: int=social.state.memory(id).turn_count
		check("stale unsolicited reply is rejected "+id,not social.accept_reply({"schema":1,"request_id":"old","npc_id":id,"topic":"day","mode":"claude","text":"wrong"}) and social.state.memory(id).turn_count==count)
		for _i: int in range(8):
			await key(KEY_TAB)
			check("Tab stays in NPC modal",social.dialogue.is_ancestor_of(root.gui_get_focus_owner()))
		for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
			world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);world.hud.size=resolution
			await frames(4)
			check("dialogue fits "+id+str(resolution),Rect2(Vector2.ZERO,resolution).encloses(social.dialogue.panel.get_global_rect()) and social.dialogue.panel.get_global_rect().encloses(social.dialogue.close_button.get_global_rect()))
		await key(KEY_ESCAPE)
		check("Escape closes dialogue and restores controls "+id,not social.dialogue.visible and not player.controls_locked and not world.hud.menu_open)
		await key(KEY_E)
		check("reopening remembers own conversation "+id,social.dialogue.text_label.text==social.state.data.profiles[id].return_greeting)
		await activate(social.dialogue.choices[0])
		check("repeated topic recalls own earlier choice "+id,social.dialogue.text_label.text.begins_with("We talked about that earlier."))
		await key(KEY_ESCAPE)
	check("both actors retain distinct private histories",social.state.memory("ReceptionA").turn_count==2 and social.state.memory("ReceptionB").turn_count==2)
	world.go_location(0);await frames(2);social.cooldown=0;world.go_location(1);await frames(4)
	check("contacted room entry starts authored exchange",social.ambient_active)
	for _i: int in range(4):
		social.ambient_remaining=0;social.update(.02);await process_frame;await frames(2)
	check("authored exchange emits four lines without provider",social.ambient_lines_shown==4 and social.requests_started==0 and social.caption_speaker.text.contains("Scripted"))
	check("public exchange preserves private histories",social.state.public_memories.size()==2 and social.state.memory("ReceptionA").turn_count==2)
	social.ambient_remaining=0;social.update(.02)
	check("ambient loop stops after four lines",not social.ambient_active and not social.caption.visible)
	world.go_location(0);await frames(2);world.go_location(1);await frames(2)
	check("reentry cooldown prevents repeated chatter",not social.ambient_active and social.ambient_lines_shown==4)
	var memory: Dictionary=social.state.memory("ReceptionA")
	memory.lines.append("external mutation")
	check("memory reads cannot mutate authoritative record",social.state.memory("ReceptionA").lines.size()==2)
	# A deferred response must not update state after its conversation is closed.
	approach("ReceptionA");await frames(2);social.try_talk()
	social._on_topic("work")
	check("choice schedules one pending turn",not social.pending.is_empty() and social.dialogue.waiting)
	social.dialogue.close();await frames(3)
	check("close discards deferred result without phantom memory",social.state.memory("ReceptionA").turn_count==2 and social.pending.is_empty())
	social.try_talk();await key(KEY_F3)
	check("Settings interrupts conversation safely",world.hud.menu_open and not social.dialogue.visible and player.controls_locked)
	world.set_menu_open(false)
	# Regression: the same reception position can target either NPC or monitor.
	# Facing the actor and facing the display must agree with HUD and E action.
	var monitor: Dictionary=world.computer_portal.computers.filter(func(c: Dictionary):return c.id=="Reception_monitor")[0]
	player.teleport_to(Vector3(3.1,5.075,-5.221121))
	var toward: Vector3=world.population.get_node("ReceptionA").global_position-player.global_position
	player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)
	await frames(12)
	check("shared E position can focus NPC",world.prefers_npc(social.reachable_npc(),world.computer_portal.reachable_computer()) and world.hud.prompt_label.text.begins_with("E: talk"))
	await key(KEY_E)
	check("focused NPC receives shared E action",social.dialogue.visible)
	await key(KEY_ESCAPE)
	toward=monitor.point-player.global_position
	player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)
	await frames(12)
	check("turning toward monitor selects computer",not world.prefers_npc(social.reachable_npc(),world.computer_portal.reachable_computer()) and world.hud.prompt_label.text=="E: use computer")
	await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	check("focused monitor remains usable beside NPC",world.computer_portal.inside and not social.dialogue.visible)
	world.go_location(0);await frames(3)
	check("leaving room hides captions and talk prompts",not social.ambient_active and social.selected.is_empty() and not social.caption.visible)
	check("conversation grants no game completion",not world.entrance_puzzle.state.unlocked and not world.elevator_game.state.completed())
	check("population and building remain unchanged",world.population.actors.size()==16 and world.mesh_count==10804 and world.collision_triangles==274854)
	var fresh: RefCounted=load("res://game/NPCConversationState.gd").new()
	check("fresh game starts with empty memories",fresh.memories.is_empty() and fresh.public_memories.is_empty())
	print("NPC_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
