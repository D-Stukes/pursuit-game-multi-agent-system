extends "res://developer/tests/TestKit.gd"
## Step 7: question slots that change with progress and history. Step 8: overheard scenes.
const State = preload("res://game/NPCConversationState.gd")
const Pilot = preload("res://developer/tests/NPCTestPilot.gd")
var world: Node3D
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)

## Ask a slot the way a conversation does: the reply first, then it is remembered.
func ask(state: RefCounted, npc: String, slot: String) -> String:
	var reply: String = state.local_reply(npc,slot)
	state.remember(npc,slot,reply)
	return reply

func slot_checks() -> void:
	var state: RefCounted = State.new()
	state.progress = {}
	var host: Dictionary = state.topics_for("EntranceHost")
	check("the host keeps three question slots plus Go explore",host.size() == 4 and host.has("roam"))
	check("before the door, the host explains how to get in",host.entrance == "How do I get inside?" and host.controls == "How do I move and interact?")
	ask(state,"EntranceHost","controls")
	check("asking about controls unlocks a follow-up",state.topics_for("EntranceHost").controls == "Any tips before I start?")
	check("the follow-up has its own answer",ask(state,"EntranceHost","controls").contains("Hints on the keypad"))
	check("answered one-time questions fall back to the original",state.topics_for("EntranceHost").controls == "How do I move and interact?")
	state.progress = {"entrance":true}
	check("after the door, the host's question changes",state.topics_for("EntranceHost").entrance == "What's it like inside?")
	ask(state,"EntranceHost","entrance")
	check("and leads to asking about Rosa",state.topics_for("EntranceHost").entrance == "Who's Rosa?" and ask(state,"EntranceHost","entrance").contains("lobby"))
	check("asking again is remembered",state.topics_for("EntranceHost").entrance == "What's it like inside?" and ask(state,"EntranceHost","entrance").begins_with("We talked about that earlier."))
	state.progress = {"entrance":true,"elevator":true,"checked_in":true}
	check("after check-in the host points onward",state.topics_for("EntranceHost").route == "Where am I headed now?")
	check("reception asks change before and after check-in",State.new().topics_for("ReceptionA").directions == "Where is the classroom?")
	var reception: RefCounted = State.new()
	reception.progress = {"entrance":true,"elevator":true}
	check("reception offers check-in directions before check-in",reception.topics_for("ReceptionA").directions == "Where do I check in?" and ask(reception,"ReceptionA","directions").contains("reception computer"))
	reception.progress.checked_in = true
	check("and the classroom after it",reception.topics_for("ReceptionA").directions == "Where is the classroom?")
	var builder: Dictionary = State.new().topics_for("BuilderCompanion")
	check("the Builder's help choices are unchanged",builder.keys() == ["next","hint","steps"])

func scene_checks() -> void:
	var population: Node3D = world.population
	var scenes: Node = population.scenes
	var a: CharacterBody3D = population.get_node("ReceptionA")
	var b: CharacterBody3D = population.get_node("ReceptionB")
	world.player.teleport_to(Vector3(-13,5.05,-12));await frames(4)
	# Send both to the dining table spots and wait until they are standing there.
	var east: Dictionary = population.life_places.filter(func(p: Dictionary): return p.id == "dining_east")[0]
	var west: Dictionary = population.life_places.filter(func(p: Dictionary): return p.id == "dining_west")[0]
	scenes.cooldown = 999
	east.seconds = [40,40];west.seconds = [40,40]
	a.routine.assign(east);b.routine.assign(west)
	for _i: int in range(1800):
		if a.routine.phase == "act" and b.routine.phase == "act" and a.routine.place.get("id","") == "dining_east" and b.routine.place.get("id","") == "dining_west": break
		await physics_frame
	check("two people stand at neighbouring spots",a.routine.phase == "act" and b.routine.phase == "act" and a.global_position.distance_to(b.global_position) < 2.8,[a.routine.phase,b.routine.phase,a.global_position,b.global_position,a.routine.reason,b.routine.reason,a.routine.stuck,b.routine.stuck])
	world.player.teleport_to(Vector3(-9.2,5.05,-20.5));await frames(2)
	scenes.cooldown = 0;await frames(10)
	check("no scene plays out of earshot",scenes.active.is_empty())
	world.player.teleport_to(Vector3(-13,5.05,-12));await frames(10)
	check("a scene starts when the player is near",not scenes.active.is_empty() and a.routine.in_scene() and b.routine.in_scene())
	var scene: Dictionary = scenes.active.get("scene",{})
	await frames(30)
	var facing: Vector3 = a.global_basis.z;var toward: Vector3 = b.global_position-a.global_position;toward.y = 0
	check("they turn to face each other",a.routine.scene_face.distance_to(b.global_position+Vector3.UP*1.55) < .1 and b.routine.scene_face.distance_to(a.global_position+Vector3.UP*1.55) < .1 and facing.dot(toward.normalized()) > .8)
	var first: String = str(scene.get("lines",[[0,""]])[0][1])
	check("their lines appear as captions",world.npc_conversations.said.any(func(text: String): return text.ends_with(first)))
	var lines: int = scene.get("lines",[]).size()
	for _i: int in range(int((lines+1)*float(scenes.settings.line_seconds)*60)+60):
		if scenes.active.is_empty(): break
		await physics_frame
	var last: String = str(scene.get("lines",[[0,""]])[-1][1])
	check("the whole scene plays, then they carry on",scenes.active.is_empty() and world.npc_conversations.said.any(func(text: String): return text.ends_with(last)) and not a.routine.in_scene() and not b.routine.in_scene())
	check("a scene plays once and then rests",scene.get("id","") in scenes.played and scenes.cooldown > 0)
	check("milestone scenes wait for their milestone",not scenes._fits(scenes.scenes.filter(func(s: Dictionary): return s.id == "reception_new_builder")[0]))
	# A conversation interrupts a scene.
	east.seconds = [40,40];west.seconds = [40,40]
	a.routine.assign(east);b.routine.assign(west)
	for _i: int in range(900):
		if a.routine.phase == "act" and b.routine.phase == "act": break
		await physics_frame
	scenes.cooldown = 0;await frames(10)
	var started: bool = not scenes.active.is_empty()
	a.routine.begin_conversation();await frames(4)
	a.routine.end_conversation()
	check("talking to one of them ends the scene",started and scenes.active.is_empty() and not b.routine.in_scene())
	# A hand-off assignment also ends a scene.
	a.routine.assign(east);b.routine.assign(west)
	for _i: int in range(900):
		if a.routine.phase == "act" and b.routine.phase == "act": break
		await physics_frame
	scenes.played.clear();scenes.cooldown = 0;await frames(10)
	started = not scenes.active.is_empty()
	a.routine.assign({"id":"journey_test","area":"upper","action":"look","position":a.global_position+Vector3(1,0,0),"face":Vector3(0,6,0),"seconds":[3,3]})
	await frames(4)
	check("a hand-off ends the scene",started and scenes.active.is_empty() and not a.routine.in_scene())
	# Street people speak through their own profiles.
	world.player.teleport_to(Vector3(-4.4,0,9.2));await frames(4)
	var host: CharacterBody3D = population.get_node("StreetWestB")
	var builder: CharacterBody3D = population.get_node("StreetWestA")
	var curb: Dictionary = population.life_places.filter(func(p: Dictionary): return p.id == "street_curb")[0]
	var post: Dictionary = population.life_places.filter(func(p: Dictionary): return p.id == "street_host")[0]
	curb.seconds = [40,40];post.seconds = [40,40]
	builder.routine.assign(curb);host.routine.assign(post)
	for _i: int in range(1200):
		if host.routine.phase == "act" and builder.routine.phase == "act": break
		await physics_frame
	scenes.cooldown = 0
	var street_line: String = str(scenes.scenes.filter(func(s: Dictionary): return s.id == "street_door")[0].lines[0][1])
	for _i: int in range(300):
		if world.npc_conversations.said.any(func(text: String): return text.ends_with(street_line)): break
		await physics_frame
	check("street scenes speak through the host's and Builder's own profiles",world.npc_conversations.said.any(func(text: String): return text.ends_with(street_line)),[host.routine.phase,builder.routine.phase,host.global_position.distance_to(builder.global_position)])

func run() -> void:
	slot_checks()
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	if world.intro != null and world.intro.active: world.intro.finish()
	var social: Node3D = world.npc_conversations
	social.cooldown = 999
	var start: Dictionary = world.orchestrator.snapshot()
	# In the game: Rosa's follow-up appears right after her answer.
	world.player.teleport_to(Vector3(1.2,0,3.4));await frames(4)
	check("found a clear approach to Rosa",Pilot.approach(world,"LobbyGreeter").is_finite())
	await frames();await key(KEY_E)
	check("talking to Rosa shows her questions",social.dialogue.visible and social.active_npc == "LobbyGreeter" and social.dialogue.choices.any(func(button: Button): return button.text == "What's in this building?"))
	social._on_topic("building")
	for _i: int in range(240):
		if not social.dialogue.waiting and social.pending.is_empty() and social.speaking_topic.is_empty(): break
		await physics_frame
	await frames(4)
	check("her follow-up question appears after the answer",social.dialogue.choices.any(func(button: Button): return button.text == "What's the commons like?"))
	social.dialogue.close();await frames(4)
	await scene_checks()
	var finish: Dictionary = world.orchestrator.snapshot()
	check("choices and scenes never change progress",finish.gates == start.gates and finish.course == start.course and finish.arrival == start.arrival)
	check("no provider requests",social.requests_started == 0)
	world.queue_free();await process_frame
	print("NPC_DIALOGUE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
