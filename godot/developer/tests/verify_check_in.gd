extends SceneTree
## Verified arrival evidence, real E/Enter interaction and modal cancellation.
const Rules = preload("res://game/CheckInState.gd")
const Event = preload("res://game/SessionEvent.gd")
const Session = preload("res://game/SessionState.gd")
const Pipes = preload("res://developer/tests/PipeTestPilot.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ", label)

func frames(count: int = 4) -> void:
	for _i: int in range(count): await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); await frames(2)
	event = event.duplicate(); event.pressed = false
	Input.parse_input_event(event); await frames(2)

static func solve_gates(world: Node3D) -> void:
	Pipes.solve_all(world.entrance_puzzle.state)
	world.entrance_puzzle.state.enter_code(world.entrance_puzzle.state.revealed_code())
	world._on_entrance_unlocked()
	world.elevator_game.state.start()
	while not world.elevator_game.state.completed():
		if world.elevator_game.state.phase == "between": world.elevator_game.state.between_waves = 0
		for enemy: Dictionary in world.elevator_game.state.enemies: world.elevator_game.state.shots.append(enemy.at)
		world.elevator_game.state.step(.001, Vector2.ZERO, false)
	world._on_shooter_won()

func approach(world: Node3D) -> void:
	world.player.teleport_to(Vector3(3.1, 5.075, -5.221121))
	var toward: Vector3 = world.check_in.computer.point - world.player.global_position
	world.player.camera_pivot.rotation.y = atan2(-toward.x, -toward.z)
	await frames(8)

func run() -> void:
	var rules: RefCounted = Rules.new()
	for invalid: String in ["", "  ", "a\nb", "a".repeat(33), "a"+String.chr(127)]:
		check("invalid display name rejected", not rules.start_photo(invalid) and not rules.completed())
	check("photo and confirm cannot skip name", not rules.take_photo() and not rules.confirm())
	check("held-out Unicode name accepted without a roster", rules.start_photo("  李 Ada  ") and rules.display_name == "李 Ada")
	check("name alone cannot finish", not rules.confirm() and not rules.completed())
	check("photo still requires explicit confirmation", rules.take_photo() and not rules.completed())
	rules.cancel()
	check("cancel discards draft evidence", rules.display_name.is_empty() and rules.phase == Rules.Phase.NAME)
	var world: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(world); await frames(12)
	var console: Node = world.check_in
	var coordinator: RefCounted = world.orchestrator
	var course: Dictionary = coordinator.snapshot().course
	await approach(world); await key(KEY_E)
	check("reception E opens check-in rather than portal", console.is_open and not world.computer_portal.transitioning)
	check("inspection without wins cannot confirm", console.primary.disabled and not coordinator.checked_in())
	await key(KEY_ESCAPE)
	check("Escape closes modal and restores ownership", not console.is_open and coordinator.snapshot().interaction.is_empty() and not world.player.controls_locked)
	solve_gates(world)
	coordinator.observe_zone("ground"); coordinator.claim("check_in")
	check("won games still require upstairs arrival", not coordinator.submit(coordinator.new_event(Event.Kind.CHECK_IN_CONFIRMED)).accepted)
	coordinator.release("check_in")
	coordinator.observe_zone("upstairs"); coordinator.set_review(true); coordinator.claim("check_in")
	check("review cannot grant arrival progress", not coordinator.submit(coordinator.new_event(Event.Kind.CHECK_IN_CONFIRMED)).accepted and not coordinator.checked_in())
	coordinator.release("check_in"); coordinator.set_review(false)
	await approach(world); await key(KEY_E)
	check("ready console owns modal and accepts a name", console.is_open and console.name_input.editable and coordinator.snapshot().interaction == "check_in" and world.player.controls_locked)
	check("unconfirmed signal cannot publish check-in", not coordinator.submit(coordinator.new_event(Event.Kind.CHECK_IN_CONFIRMED)).accepted)
	console.name_input.text = "  "; await key(KEY_ENTER)
	check("empty name stays editable with feedback", console.name_input.editable and not console.notice.text.is_empty() and not coordinator.checked_in())
	console.name_input.text = "Draft"; await key(KEY_ENTER)
	world.set_menu_open(true)
	await create_timer(.5).timeout
	check("Settings cancels photo and pending draft", not console.is_open and console.state.display_name.is_empty() and not coordinator.checked_in() and coordinator.snapshot().interaction == "menu")
	world.set_menu_open(false); await approach(world); await key(KEY_E)
	console.name_input.text = "Unconfirmed"
	world.go_location(0); await frames()
	check("developer travel discards only the pending form", not console.is_open and console.state.display_name.is_empty() and not coordinator.checked_in() and coordinator.snapshot().interaction.is_empty())
	await approach(world); await key(KEY_E)
	console.name_input.text = "Nia Test"; await key(KEY_ENTER)
	await create_timer(.5).timeout; await frames()
	check("photo is simulated from the avatar and still unconfirmed", console.portrait.visible and console.photo_viewport != null and console.state.phase == Rules.Phase.PHOTO and not coordinator.checked_in())
	check("photo locks other world interactions", not world.try_lift() and not world.computer_portal.try_use() and not world.npc_conversations.try_talk())
	await key(KEY_ENTER); await frames()
	check("explicit confirmation publishes name and next objective", coordinator.checked_in() and coordinator.snapshot().arrival.display_name == "Nia Test" and coordinator.snapshot().stage == "classroom_pending")
	var revision: int = coordinator.snapshot().revision
	var applied: Dictionary = coordinator.snapshot().log.filter(func(row: Dictionary): return row.kind == "check_in_verified")[0]
	var replay: RefCounted = Event.new(Event.Kind.CHECK_IN_CONFIRMED, coordinator.snapshot().session_id, applied.details.event_id, Session.Stage.CHECK_IN)
	check("exact check-in replay is idempotent", coordinator.submit(replay).duplicate and coordinator.snapshot().revision == revision)
	var foreign: RefCounted = Event.new(Event.Kind.CHECK_IN_CONFIRMED, "other-session", "foreign", Session.Stage.CHECK_IN)
	check("foreign session cannot reuse confirmed arrival", coordinator.submit(foreign).reason == "stale_session")
	var conflict: RefCounted = Event.new(Event.Kind.SHOOTER_WON, coordinator.snapshot().session_id, applied.details.event_id, Session.Stage.ELEVATOR)
	check("confirmed event identity cannot change meaning", coordinator.submit(conflict).reason == "event_id_conflict")
	check("repeat confirmation cannot publish again", not coordinator.submit(coordinator.new_event(Event.Kind.CHECK_IN_CONFIRMED)).accepted and coordinator.snapshot().revision == revision)
	await key(KEY_ESCAPE)
	world.go_location(0); await frames()
	check("travel preserves confirmed arrival but no course reward", coordinator.checked_in() and coordinator.snapshot().course == course)
	await approach(world); await key(KEY_E)
	check("return visit shows receipt without re-entering name", console.is_open and not console.name_input.visible and console.message.text.contains("Nia Test") and console.primary.text == "Continue to classroom")
	for viewport: Vector2i in [Vector2i(800,600), Vector2i(1440,900)]:
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		world.hud.size = viewport; await frames()
		check("check-in panel fits viewport", console.panel.get_global_rect().end.x <= viewport.x and console.panel.get_global_rect().end.y <= viewport.y and console.panel.position.x >= 0 and console.panel.position.y >= 0)
	console.close()
	check("no provider turn or teacher work was created", world.npc_conversations.requests_started == 0 and coordinator.snapshot().course.question_id.is_empty())
	world.queue_free(); await process_frame
	var fresh: RefCounted = Rules.new()
	check("new session keeps no previous name or photo", not fresh.completed() and fresh.display_name.is_empty())
	print("CHECK_IN_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
