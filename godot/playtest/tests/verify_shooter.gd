extends SceneTree
## Deterministic rules and real modal input; the full world handoff has its own check.
const Rules = preload("res://playtest/ElevatorShooterState.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ", label)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var state: RefCounted = Rules.new()
	state.rng.seed = 42
	check("starts unearned and ready", state.phase == "ready" and not state.completed())
	state.step(1, Vector2.RIGHT, true)
	check("ready waits for explicit launch", state.ship == Vector2(500,480) and state.shots.is_empty())
	state.start()
	check("launch creates first wave and three shields", state.enemies.size() == 5 and state.shields == 3 and state.wave == 1)
	state.step(0.05, Vector2(1,-1), true)
	check("diagonal movement is normalized", absf(state.ship.distance_to(Vector2(500,480)) - Rules.SHIP_SPEED * 0.05) < .001)
	check("shoot input produces moving laser", state.shots.size() == 1 and state.shots[0].y < state.ship.y - 23)
	state.paused = true
	var paused_at: Vector2 = state.ship
	var paused_time: float = state.clock
	state.step(1, Vector2.LEFT, true)
	check("pause freezes clock and movement", state.clock == paused_time and state.ship == paused_at)
	state.paused = false
	for _i: int in range(80): state.step(.05, Vector2(-1,1), false)
	check("ship stays within arena", state.ship.x >= 52 and state.ship.y <= 506)
	# Real projectile collisions supply damage; no direct health mutation.
	state.hazards.clear()
	state.hazards.append({"at":state.ship,"velocity":Vector2.ZERO})
	state.hazards.append({"at":state.ship,"velocity":Vector2.ZERO})
	state.step(.01, Vector2.ZERO, false)
	check("overlapping hits cost one shield with grace period", state.shields == 2 and state.invulnerable > 1)
	state.hazards.clear()
	for _i: int in range(2):
		state.invulnerable = 0
		state.hazards.append({"at":state.ship,"velocity":Vector2.ZERO})
		state.step(.01, Vector2.ZERO, false)
	check("third separated hit ends run without unlock", state.phase == "lost" and not state.completed())
	state.start()
	check("retry restores all waves and shields", state.phase == "playing" and state.wave == 1 and state.shields == 3 and state.cleared == 0)
	# A deterministic pilot supplies only the supported movement/fire inputs.
	for _i: int in range(18000):
		if state.phase in ["won", "lost"]: break
		var target: float = state.ship.x
		if not state.enemies.is_empty():
			var enemy: Dictionary = state.enemies[0]
			target = enemy.home.x + sin((state.clock + (state.ship.y - enemy.at.y) / Rules.SHOT_SPEED) * .95 + enemy.offset) * 105
		var direction := Vector2(clampf((target - state.ship.x) / 8, -1, 1), 0)
		state.step(1.0/60, direction, true)
	check("input-only pilot clears real projectiles across three waves", state.completed())
	check("win requires all eighteen real collisions", state.cleared == 18 and state.enemies.is_empty() and state.wave == 3)
	var finish_clock: float = state.clock
	state.step(1, Vector2.RIGHT, true)
	check("completed run stops simulation", state.clock == finish_clock)
	state.start()
	check("start cannot erase an earned win", state.completed())
	var hud: Control = load("res://playtest/PlaytestHUD.gd").new()
	root.add_child(hud)
	var game: Control = load("res://playtest/ElevatorShooter.gd").new()
	game.theme_source = hud
	hud.add_child(game)
	await process_frame
	check("arcade is hidden at startup", not game.visible)
	game.open()
	check("ready screen has launch and controls", game.center_panel.visible and game.primary_button.text == "Launch flight")
	await key(KEY_ENTER, true);await key(KEY_ENTER, false)
	check("real keyboard button activation launches", game.state.phase == "playing" and not game.center_panel.visible)
	await key(KEY_D, true);await create_timer(.12).timeout;await key(KEY_D, false)
	check("real D input moves the ship", game.state.ship.x > 510)
	await key(KEY_SPACE, true);await create_timer(.12).timeout;await key(KEY_SPACE, false)
	check("real Space input fires without pausing", not game.state.shots.is_empty() and not game.state.paused)
	await key(KEY_P, true);await key(KEY_P, false)
	check("P pauses and shows resume", game.state.paused and game.primary_button.text == "Resume flight")
	await key(KEY_P, true);await key(KEY_P, false)
	check("P resumes", not game.state.paused)
	await key(KEY_ESCAPE, true);await key(KEY_ESCAPE, false)
	var closed_clock: float = game.state.clock
	await create_timer(.08).timeout
	check("Escape closes and freezes session progress", not game.visible and game.state.clock == closed_clock)
	game.open()
	check("reopening resumes the existing run", game.state.phase == "playing" and game.state.clock == closed_clock)
	for resolution: Vector2 in [Vector2(1280,720), Vector2(800,600)]:
		game.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		game.size = resolution
		await process_frame
		var bounds := Rect2(Vector2.ZERO, resolution)
		check("arcade frame fits " + str(resolution), bounds.encloses(game.frame.get_global_rect()))
		check("close button fits " + str(resolution), bounds.encloses(game.close_button.get_global_rect()))
		check("pause button fits " + str(resolution), bounds.encloses(game.pause_button.get_global_rect()))
	game.close()
	hud.queue_free()
	await process_frame
	print("SHOOTER_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
