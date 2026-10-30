extends RefCounted
## Local arcade rules. Course energy, grades and agent progress are not touched.

const ARENA := Rect2(24, 100, 952, 434)
const WAVE_COUNTS: Array[int] = [5, 6, 7]
const TOTAL_DRONES: int = 18
const MAX_SHIELDS: int = 3
const SHIP_SPEED: float = 340.0
const SHOT_SPEED: float = 720.0
const SHIP_RADIUS: float = 22.0      ## base ship collision radius
const GROW_SCALE: float = 1.6        ## ship size while a resize pellet is active
const BUFF_TIME: float = 9.0         ## how long grow / double-fire last
const PICKUP_SPEED: float = 95.0     ## how slowly pellets rain down
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
const LANE_WARNING: float = 0.9
const LANE_DURATION: float = 0.2
var lane_delay: float = 0.0
# Falling power-ups: energy (restore shield), grow (bigger ship), fire (double shots).
# Energy rains on a per-level cadence; grow/fire are rarer separate treats.
var pickups: Array[Dictionary] = []
var energy_delay: float = 0.0
var treat_delay: float = 0.0
var grow_time: float = 0.0
var fire_time: float = 0.0
var collected: int = 0   ## total pellets caught (drives the pickup chime)
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
	pickups.clear()
	grow_time = 0.0
	fire_time = 0.0
	collected = 0
	_spawn_wave()

func _spawn_wave() -> void:
	wave += 1
	phase = "playing"
	enemies.clear()
	fire_delay = 1.4 if wave==1 else .9
	warnings.clear()
	lane_delay = 1.0 if wave == 2 else .1
	energy_delay = 3.0   # first energy batch rains down a few seconds into the wave
	treat_delay = 8.0    # resize / fireball treats start a little later
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
	grow_time = maxf(0, grow_time - dt)
	fire_time = maxf(0, fire_time - dt)
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
		if fire_time > 0:   # double-fire pellet: twin cannons
			shots.append(ship + Vector2(-10, -23))
			shots.append(ship + Vector2(10, -23))
		else:
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
		pickups.clear()
		if wave == WAVE_COUNTS.size() and cleared == TOTAL_DRONES:
			phase = "won"
		else:
			phase = "between"
			between_waves = 1.25
		return
	for i: int in range(warnings.size()-1,-1,-1):
		warnings[i].delay-=dt
		if warnings[i].delay<=0:
			hazards.append({"at":warnings[i].at,"velocity":warnings[i].velocity,"lane":warnings[i].get("lane",false),"life":LANE_DURATION})
			warnings.remove_at(i)
	# Mark the current row, then hold it briefly. Vertical movement is the counter;
	# the warning never follows the player after it is placed. Wave one is unchanged.
	if wave >= 2:
		lane_delay -= dt
		if lane_delay <= 0:
			warnings.append({"at":Vector2(ARENA.position.x,ship.y), "velocity":Vector2.ZERO, "delay":LANE_WARNING, "lane":true})
			lane_delay = 60.0 if wave == 2 else 30.0   # once a minute on L2, every 30s on L3
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
		var lane: bool = hazards[i].get("lane",false)
		if lane: hazards[i].life -= dt
		var reach: float = ship_radius()
		var contact: bool = absf(ship.y-hazards[i].at.y)<reach if lane else ship.distance_to(hazards[i].at)<reach
		var hit: bool = invulnerable <= 0 and contact
		if hit:
			shields -= 1
			invulnerable = 1.4
		if (hit and not lane) or (lane and hazards[i].life<=0) or not ARENA.has_point(hazards[i].at): hazards.remove_at(i)
		if shields <= 0:
			phase = "lost"
			break
	# Rain pellets down slowly; the player flies into them to catch them.
	if phase == "playing":
		# Energy pellets on a per-level cadence (L1: 1-2/10s, L2: 2/8s, L3: 3/6s).
		energy_delay -= dt
		if energy_delay <= 0:
			for _n: int in range(energy_count()):
				_spawn_pickup("energy")
			energy_delay = energy_interval()
		# Resize / fireball treats stay occasional so they feel special.
		treat_delay -= dt
		if treat_delay <= 0:
			_spawn_pickup("grow" if rng.randf() < 0.5 else "fire")
			treat_delay = rng.randf_range(12.0, 16.0)
		for i: int in range(pickups.size() - 1, -1, -1):
			pickups[i].at += Vector2(0, PICKUP_SPEED * dt)
			if ship.distance_to(pickups[i].at) < ship_radius() + 12:
				_collect(pickups[i].kind)
				pickups.remove_at(i)
			elif pickups[i].at.y > ARENA.end.y - 4:
				pickups.remove_at(i)

func ship_radius() -> float:
	return SHIP_RADIUS * (GROW_SCALE if grow_time > 0 else 1.0)

func energy_interval() -> float:
	return [10.0, 8.0, 6.0][mini(maxi(wave, 1), 3) - 1]

func energy_count() -> int:
	match mini(maxi(wave, 1), 3):
		2: return 2
		3: return 3
		_: return rng.randi_range(1, 2)   # level 1: one or two

func _spawn_pickup(kind: String) -> void:
	var x: float = rng.randf_range(ARENA.position.x + 40, ARENA.end.x - 40)
	pickups.append({"at": Vector2(x, ARENA.position.y + 6), "kind": kind})

func _collect(kind: String) -> void:
	collected += 1
	match kind:
		"energy": shields = mini(MAX_SHIELDS, shields + 1)
		"grow": grow_time = BUFF_TIME
		"fire": fire_time = BUFF_TIME

func completed() -> bool:
	return phase == "won" and cleared == TOTAL_DRONES and wave == WAVE_COUNTS.size()

func movement_frequency() -> float:
	return [.95,1.18,1.4][maxi(0,wave-1)]
