extends "res://developer/tests/TestKit.gd"
## Rosa, the guided hand-offs along the route, reactions and gossip.
const Gates = preload("res://developer/tests/verify_check_in.gd")
const Pipes = preload("res://developer/tests/PipeTestPilot.gd")
const State = preload("res://game/NPCConversationState.gd")
var world: Node3D
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame

## Stand-in progress for the beats after check-in and the classroom stand-up.
class LaterProgress:
	func checked_in() -> bool: return true
	func snapshot() -> Dictionary: return {"arrival":{"classroom_complete":true}}

func said(text: String) -> bool:
	return world.npc_conversations.said.any(func(line: String): return line.contains(text))

func line(beat: String) -> String:
	return str(world.population.journey.lines[beat][1])

## Follow a leader along their own trail, about 1.2 m behind, until they arrive (or time runs out).
func follow(leader: CharacterBody3D, spot_id: String, limit: int = 2400) -> bool:
	var trail: Array[Vector3] = [leader.global_position]
	for i: int in range(limit):
		await physics_frame
		if leader.routine.phase == "act" and leader.routine.place.get("id","") == spot_id: return true
		if leader.visible and leader.global_position.distance_to(trail[-1]) > .1: trail.append(leader.global_position)
		if i % 10 == 0:
			var placed: bool = false
			for k: int in range(trail.size()-1, -1, -1):
				if trail[k].distance_to(leader.global_position) >= 1.2:
					world.player.teleport_to(trail[k]);placed = true;break
			# No trail yet (they are waiting): step up beside them.
			if not placed and world.player.global_position.distance_to(leader.global_position) > 2.5:
				var toward: Vector3 = world.player.global_position-leader.global_position;toward.y = 0
				world.player.teleport_to(leader.global_position+toward.normalized()*1.0)
	return false

func run() -> void:
	var state: RefCounted = State.new()
	var builder_lines: Dictionary = state.data.profiles.BuilderCompanion.gossip
	check("someone you just met doesn't bring up earlier milestones",not state.greeting("BuilderCompanion",{"entrance":true}).contains(builder_lines.entrance))
	state.met_npcs["BuilderCompanion"] = true
	check("someone you met remembers a new milestone",state.greeting("BuilderCompanion",{"entrance":true,"elevator":true}).contains(builder_lines.elevator))
	check("they mention it once",not state.greeting("BuilderCompanion",{"entrance":true,"elevator":true}).contains(builder_lines.elevator))
	var rosa_lines: Dictionary = state.data.profiles.LobbyGreeter.gossip
	state.met_npcs["LobbyGreeter"] = true
	var all_done: Dictionary = {"entrance":true,"elevator":true,"checked_in":true,"classroom":true,"name":"Nia"}
	var latest: String = state.greeting("LobbyGreeter",all_done)
	check("after several milestones, only the newest is mentioned",latest.contains(rosa_lines.classroom) and not state.greeting("LobbyGreeter",all_done).contains(rosa_lines.elevator))
	state.data.profiles.ReceptionB.gossip.erase("classroom");state.met_npcs["ReceptionB"] = true
	check("with nothing to say about the newest milestone, nothing stale is said",not state.greeting("ReceptionB",all_done).contains("Nia"))
	state.met_npcs["ReceptionA"] = true
	check("the check-in memory uses the player's name",state.greeting("ReceptionA",{"checked_in":true,"name":"Nia"}).contains("Nia"))
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	var population: Node3D = world.population
	var journey: Node = population.journey
	var social: Node3D = world.npc_conversations
	social.cooldown = 999
	if world.intro != null and world.intro.active: world.intro.finish()
	var rosa: CharacterBody3D = population.get_node("LobbyGreeter")
	var start: Dictionary = world.orchestrator.snapshot()
	check("Rosa lives in the lobby as an everyday person",rosa != null and population.life_actor(rosa) and rosa.routine.profile.areas == ["ground"] and absf(rosa.global_position.y) < .2)
	check("Rosa has her own scripted conversation",social.actors.any(func(record: Dictionary): return record.id == "LobbyGreeter") and social.state.data.profiles.LobbyGreeter.label == "Rosa")
	# Street: the host speaks first.
	var host: CharacterBody3D = population.get_node("StreetWestB")
	world.player.teleport_to(host.global_position+Vector3(2.0,0,.8));await frames(20)
	check("the host speaks first as the player approaches",said(line("host_intro")) and journey.done.has("host_intro"))
	# A real door unlock: the street cheers, then Rosa walks the player to the elevator.
	Pipes.solve_all(world.entrance_puzzle.state)
	world.entrance_puzzle.state.enter_code(world.entrance_puzzle.state.revealed_code())
	world._on_entrance_unlocked();await frames(10)
	check("the host cheers a real door unlock",said(line("door_open")) and (host.current_clip == "Wave" or host.routine.wave_remaining > 0))
	world.player.teleport_to(rosa.global_position+Vector3(0,0,1.6));await frames(20)
	check("Rosa welcomes the player inside and starts leading",said(line("lobby_welcome")) and rosa.routine.leading)
	world.player.teleport_to(Vector3(0,0,6.5));await frames(10)
	var parked: float = rosa.distance_walked;await frames(90)
	check("Rosa waits when the player falls behind",rosa.distance_walked-parked < .05 and rosa.routine.leading)
	var arrived: bool = await follow(rosa,"journey_ground_escort")
	check("Rosa leads the player to the elevator",arrived and said(line("lobby_arrived")),[rosa.routine.phase,rosa.routine.reason,rosa.global_position,rosa.routine.stuck,rosa.blocked,journey.lobby,world.player.global_position,rosa.routine.player_at,rosa.routine.index,rosa.routine.path.size()])
	await frames(30)
	check("Rosa settles onto the floor after the stairs",absf(rosa.global_position.y-rosa.floor_height(rosa.global_position))<.01,rosa.global_position)
	check("Rosa stops beside the elevator, not in the cab",rosa.global_position.distance_to(world.LIFT_GROUND) > 1.5 and rosa.global_position.distance_to(world.LOWER_LIFT_EXIT) < 2.2)
	# The elevator game is won: the guide meets the player upstairs and leads them to check-in.
	world.elevator_game.state.start()
	while not world.elevator_game.state.completed():
		if world.elevator_game.state.phase == "between": world.elevator_game.state.between_waves = 0
		for enemy: Dictionary in world.elevator_game.state.enemies: world.elevator_game.state.shots.append(enemy.at)
		world.elevator_game.state.step(.001, Vector2.ZERO, false)
	world._on_shooter_won()
	var guide: CharacterBody3D = population.get_node("ReceptionA")
	# The guide may be mid-ride when the gate passes; the assignment starts once it steps out.
	for _i: int in range(900):
		await physics_frame
		if journey.upstairs == "meeting": break
	await frames(4)
	check("the guide heads to the upstairs elevator doors",journey.upstairs == "meeting" and guide.routine.holding)
	world.player.teleport_to(world.UPPER_LIFT_EXIT+Vector3(.3,0,.4));await frames(3)
	var in_view: Array = ["ReceptionA","ReceptionB"].filter(func(id: String): return population.get_node(id).visible and population.get_node(id).global_position.distance_to(world.player.global_position) < 12.0)
	check("reception looks up when the player arrives upstairs",journey.done.has("arrival_alert") and not in_view.is_empty() and in_view.all(func(id: String): return population.get_node(id).alert_remaining > 0),in_view)
	for _i: int in range(2400):
		if said(line("upstairs_welcome")): break
		await physics_frame
	check("the guide cheers and welcomes the player upstairs",said(line("upstairs_welcome")) and journey.upstairs == "leading")
	check("the guide leads the player to the check-in computer",await follow(guide,"journey_checkin_side") and said(line("checkin_here")))
	check("the guide stands beside, not in front of, the console",guide.global_position.distance_to(Vector3(3.1,5.05,-5.22)) > .8)
	# After check-in and the stand-up (stand-in progress; the real flows are covered by their own suites).
	world.player.teleport_to(guide.global_position+Vector3(0,0,1.2));await frames(2)
	journey._after_check_in(world.player.global_position,LaterProgress.new());await frames(4)
	check("reception points the way to the classroom",said(line("classroom_point")) and ["ReceptionA","ReceptionB"].any(func(id: String): return str(population.get_node(id).routine.reason).contains("classroom")))
	journey._after_classroom(LaterProgress.new())
	check("after meeting Mr. P, people head for their laptops",["ReceptionA","ReceptionB"].all(func(id: String): return population.get_node(id).routine.boosts.has("laptop")))
	# A conversation after a real win carries the gossip; a skip never earns praise.
	var finish: Dictionary = world.orchestrator.snapshot()
	check("hand-offs and reactions never change course progress",finish.course == start.course and finish.reserve_pellets <= 1)
	check("hand-offs make no provider requests",social.requests_started == 0)
	world.queue_free();await process_frame
	# A skipped door earns no cheer and no praise.
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	if world.intro != null and world.intro.active: world.intro.finish()
	var host_again: CharacterBody3D = world.population.get_node("StreetWestB")
	world.player.teleport_to(host_again.global_position+Vector3(2.0,0,.8));await frames(6)
	world.orchestrator.skip_gate("entrance");await frames(10)
	check("a skipped door still gets a cheer",world.population.journey.done.has("door_cheer") and said(line("door_open")))
	check("people remember a skipped door too",world.orchestrator.gate_passed("entrance") and world.npc_conversations._progress_facts().entrance)
	world.queue_free();await process_frame
	print("NPC_JOURNEY_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
