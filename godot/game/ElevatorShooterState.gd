extends RefCounted
## Local arcade rules. Course energy, grades and agent progress are not touched.

const ARENA := Rect2(24, 100, 952, 434)
const WAVE_COUNTS: Array[int] = [5, 6, 7]
const TOTAL_DRONES: int = 18
const MAX_SHIELDS: int = 3
const SHIP_SPEED: float = 340.0
const SHOT_SPEED: float = 720.0
var phase: String = "ready"
var paused: bool = false
var wave: int = 0
var cleared: int = 0
var shields: int = MAX_SHIELDS
var ship := Vector2(500, 480)
var enemies: Array[Dictionary] = []
var shots: Array[Vector2] = []
var hazards: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var clock: float = 0.0
var cooldown: float = 0.0
var fire_delay: float = 1.4
var invulnerable: float = 0.0
var between_waves: float = 0.0
var warnings: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func start() -> void:
	if phase not in ["ready", "lost"]: return
	wave = 0
	cleared = 0
	shields = MAX_SHIELDS
	ship = Vector2(500, 480)
	clock = 0.0
	cooldown = 0.0
	invulnerable = 0.0
	paused = false
	shots.clear()
	hazards.clear()
	bursts.clear()
	warnings.clear()
	_spawn_wave()

func _spawn_wave() -> void:
	wave += 1
	phase = "playing"
	enemies.clear()
	fire_delay = 1.4 if wave==1 else .9
	warnings.clear()
	for i: int in range(WAVE_COUNTS[wave - 1]):
		var home := Vector2(230 + (i % 4) * 180, 162 + (i / 4) * 67)
		enemies.append({"home": home, "at": home, "offset": i * 0.7})

func step(delta: float, direction: Vector2, firing: bool) -> void:
	if paused or phase not in ["playing", "between"]: return
	# Avoid jumping projectiles through targets after a window drag or stall.
	var dt: float = clampf(delta, 0.0, 0.05)
	clock += dt
	cooldown = maxf(0, cooldown - dt)
	invulnerable = maxf(0, invulnerable - dt)
	ship += direction.limit_length() * SHIP_SPEED * dt
	ship = ship.clamp(Vector2(52, 340), Vector2(948, 506))
	for i: int in range(bursts.size() - 1, -1, -1):
		bursts[i].age += dt
		if bursts[i].age >= 0.5: bursts.remove_at(i)
	if phase == "between":
		between_waves -= dt
		if between_waves <= 0: _spawn_wave()
		return
	if firing and cooldown <= 0:
		shots.append(ship + Vector2(0, -23))
		cooldown = 0.17
	for enemy: Dictionary in enemies:
		enemy.at = enemy.home + Vector2(sin(clock * movement_frequency() + enemy.offset) * 105, sin(clock * (1.3+wave*.1) + enemy.offset) * (12+wave*4))
	for i: int in range(shots.size() - 1, -1, -1):
		shots[i].y -= SHOT_SPEED * dt
		var hit: bool = false
		for j: int in range(enemies.size() - 1, -1, -1):
			if shots[i].distance_to(enemies[j].at) < 27:
				bursts.append({"at": enemies[j].at, "age": 0.0})
				enemies.remove_at(j)
				cleared += 1
				hit = true
				break
		if hit or shots[i].y < ARENA.position.y + 8: shots.remove_at(i)
	if enemies.is_empty():
		shots.clear()
		hazards.clear()
		warnings.clear()
		if wave == WAVE_COUNTS.size() and cleared == TOTAL_DRONES:
			phase = "won"
		else:
			phase = "between"
			between_waves = 1.25
		return
	for i: int in range(warnings.size()-1,-1,-1):
		warnings[i].delay-=dt
		if warnings[i].delay<=0:
			hazards.append({"at":warnings[i].at,"velocity":warnings[i].velocity})
			warnings.remove_at(i)
	fire_delay -= dt
	if fire_delay <= 0:
		var origin: Vector2=enemies[rng.randi_range(0,enemies.size()-1)].at+Vector2(0,20)
		var aim: Vector2=(ship-origin).normalized()
		if wave==1:
			hazards.append({"at":origin,"velocity":aim*170})
		elif wave==2:
			for shot: int in range(2): warnings.append({"at":origin,"velocity":aim*210,"delay":.4+shot*.16})
		else:
			for spread: float in [-.18,0.0,.18]: warnings.append({"at":origin,"velocity":aim.rotated(spread)*245,"delay":.45})
		fire_delay=[.77,.85,.72][wave-1]
	for i: int in range(hazards.size() - 1, -1, -1):
		hazards[i].at += hazards[i].velocity * dt
		var hit: bool = invulnerable <= 0 and ship.distance_to(hazards[i].at) < 22
		if hit:
			shields -= 1
			invulnerable = 1.4
		if hit or not ARENA.has_point(hazards[i].at): hazards.remove_at(i)
		if shields <= 0:
			phase = "lost"
			break

func completed() -> bool:
	return phase == "won" and cleared == TOTAL_DRONES and wave == WAVE_COUNTS.size()

func movement_frequency() -> float:
	return [.95,1.18,1.4][maxi(0,wave-1)]
