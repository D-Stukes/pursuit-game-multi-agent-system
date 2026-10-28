extends SceneTree
## Actual scene adapters; rule-solving fixtures are separate from rendered input.
const Pipes = preload("res://playtest/tests/PipeTestPilot.gd")
const NPCPilot = preload("res://playtest/tests/NPCTestPilot.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, value: bool) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ",label)

func frames(count: int = 5) -> void:
	for _i: int in range(count): await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)

func gate_events(coordinator: RefCounted) -> int:
	return coordinator.snapshot().log.filter(func(row: Dictionary):return row.kind=="gate_verified").size()

func run() -> void:
	var world: Node3D = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world);await frames(10)
	var coordinator: RefCounted = world.orchestrator
	var session_id: String = coordinator.snapshot().session_id
	var initial_course: Dictionary = coordinator.snapshot().course
	check("world starts with shared entrance objective",coordinator.snapshot().stage=="entrance" and world.hud.objective_label.text=="Next: Unlock the entrance")
	world.entrance_puzzle.entrance_unlocked.emit();world.elevator_game.victory.emit();world.elevator_game.ride_requested.emit()
	check("forged UI signals grant no gate or travel",not coordinator.entrance_allowed() and not coordinator.ascent_allowed() and not world.lift_in_progress and gate_events(coordinator)==0)
	world.entrance_puzzle.state.unlocked=true;world._refresh_entrance_gate()
	check("physical entrance reads shared verification rather than raw flag",world.entrance_gate.collision_layer==4)
	world.entrance_puzzle.state.unlocked=false
	world.go_location(1);await frames()
	check("developer location does not complete gameplay",coordinator.snapshot().zone=="upstairs" and coordinator.snapshot().stage=="entrance")
	check("NPC facts read earned gates from shared state",not coordinator.npc_world_snapshot().entrance_unlocked and not coordinator.npc_world_snapshot().elevator_unlocked)
	check("reachable social conversation still opens",NPCPilot.approach(world,"ReceptionA")!=Vector3.INF and world.npc_conversations.try_talk())
	check("NPC claims shared interaction ownership",coordinator.snapshot().interaction=="npc")
	check("other owner cannot claim through a conversation",not coordinator.claim("portal"))
	await key(KEY_ESCAPE)
	check("conversation close releases ownership",coordinator.snapshot().interaction.is_empty() and not world.player.controls_locked)
	var monitor: Dictionary=world.computer_portal.computers.filter(func(c: Dictionary):return c.id=="Reception_monitor")[0]
	world.player.teleport_to(Vector3(3.1,5.075,-5.221121))
	var toward: Vector3=monitor.point-world.player.global_position
	world.player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)
	await frames(10);await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	await frames()
	check("art portal owns interaction but grants no curriculum progress",world.computer_portal.inside and coordinator.snapshot().interaction=="portal" and coordinator.snapshot().zone=="purple_room" and coordinator.snapshot().stage=="entrance")
	world.set_menu_open(true)
	check("Settings suspends the portal owner",coordinator.snapshot().interaction=="menu" and coordinator.snapshot().suspended_interaction=="portal")
	world.set_menu_open(false)
	check("resuming restores portal ownership",coordinator.snapshot().interaction=="portal")
	world.set_menu_open(true);world.go_location(0);world.set_menu_open(false);await frames()
	check("developer portal exit clears suspended owner",coordinator.snapshot().interaction.is_empty() and coordinator.snapshot().suspended_interaction.is_empty())
	world.set_building_review_mode(true)
	check("review uses shared permission without gate evidence",world.entrance_gate.collision_layer==0 and coordinator.snapshot().review_mode and not coordinator.gates_earned() and gate_events(coordinator)==0)
	check("review is not reported as an NPC victory",not coordinator.npc_world_snapshot().entrance_unlocked)
	world.set_building_review_mode(false)
	world.player.teleport_to(Vector3(0,0,5.7));await frames(10);await key(KEY_E)
	check("real entrance interaction claims its owner",world.entrance_puzzle.visible and coordinator.snapshot().interaction=="entrance")
	Pipes.solve_all(world.entrance_puzzle.state)
	world.entrance_puzzle._build_tiles();world.entrance_puzzle._sync()
	check("all circuits without correct code leave shared gate locked",not coordinator.entrance_allowed())
	world.entrance_puzzle.code_input.text=world.entrance_puzzle.state.revealed_code()
	world.entrance_puzzle._unlock();await frames()
	check("code result publishes the shared entrance gate",coordinator.snapshot().gates.entrance and world.entrance_gate.collision_layer==0)
	check("HUD advances from the same session state",coordinator.snapshot().stage=="elevator" and world.hud.objective_label.text=="Next: Win the elevator shooter")
	world.entrance_puzzle.entrance_unlocked.emit()
	check("repeat UI result produces no duplicate event",gate_events(coordinator)==1)
	await key(KEY_ESCAPE)
	check("closing solved puzzle releases controls and owner",coordinator.snapshot().interaction.is_empty() and not world.player.controls_locked)
	world.player.teleport_to(world.LIFT_GROUND);await frames(12);await key(KEY_E)
	check("lower elevator game claims its owner",world.elevator_game.visible and coordinator.snapshot().interaction=="shooter" and not world.lift_in_progress)
	world.elevator_game.victory.emit();world.elevator_game.ride_requested.emit()
	check("premature shooter signals cannot grant shared ascent",not coordinator.ascent_allowed() and world.elevator_game.visible and not world.lift_in_progress)
	world.set_menu_open(true)
	check("Settings closes arcade and owns the session",not world.elevator_game.visible and coordinator.snapshot().interaction=="menu" and coordinator.snapshot().suspended_interaction.is_empty())
	world.set_menu_open(false);await key(KEY_E)
	world.elevator_game.state.rng.seed=42;world.elevator_game.state.start()
	for _i: int in range(18000):
		var state: RefCounted=world.elevator_game.state
		if state.phase in ["won","lost"]: break
		var target: float=state.ship.x
		if not state.enemies.is_empty():
			var enemy: Dictionary=state.enemies[0]
			target=enemy.home.x+sin((state.clock+(state.ship.y-enemy.at.y)/state.SHOT_SPEED)*.95+enemy.offset)*105
		state.step(1.0/60,Vector2(clampf((target-state.ship.x)/8,-1,1),0),true)
	world.elevator_game._sync();await frames()
	check("three-wave collisions publish shared shooter completion",world.elevator_game.state.completed() and coordinator.ascent_allowed() and gate_events(coordinator)==2)
	check("winning does not imply physical arrival or check-in",coordinator.snapshot().stage=="check_in_pending" and coordinator.snapshot().zone=="ground" and not world.lift_in_progress)
	check("HUD labels future check-in honestly",world.hud.objective_label.text=="Next: Check-in · coming next")
	world.elevator_game.primary_button.grab_focus();await key(KEY_ENTER)
	check("Ride hands ownership from arcade to lift",world.lift_in_progress and coordinator.snapshot().interaction=="lift" and not world.elevator_game.visible)
	if world.lift_in_progress: await world.lift_finished
	await frames(8)
	check("arrival updates location and releases interaction",coordinator.snapshot().zone=="upstairs" and coordinator.snapshot().interaction.is_empty() and not world.player.controls_locked)
	world.set_building_review_mode(true);world.set_building_review_mode(false);world.go_location(0);await frames()
	check("reset and review preserve earned gates and session",coordinator.gates_earned() and coordinator.snapshot().session_id==session_id and gate_events(coordinator)==2)
	check("gate progress never changes course energy or score",coordinator.snapshot().course==initial_course)
	for viewport: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);world.hud.size=viewport;await frames()
		check("objective fits viewport "+str(viewport),Rect2(Vector2.ZERO,viewport).encloses(world.hud.objective_label.get_global_rect()))
		check("initial hint does not overlap objective "+str(viewport),world.hud.hint_panel.position.y>world.hud.objective_label.get_global_rect().end.y)
	world.queue_free();await process_frame
	world=load("res://BuildingPlaytest.tscn").instantiate();root.add_child(world);await frames(10)
	check("a new world creates a fresh session and gates",world.orchestrator.snapshot().session_id!=session_id and world.orchestrator.snapshot().stage=="entrance" and not world.orchestrator.gates_earned() and not world.entrance_puzzle.state.unlocked and not world.elevator_game.state.completed())
	print("ORCHESTRATOR_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
