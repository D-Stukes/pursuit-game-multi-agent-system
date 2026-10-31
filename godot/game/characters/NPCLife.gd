extends RefCounted
## Everyday life for one ambient person: pick a place they like, walk there on the baked
## walkable floor, do something, then pick again. Local and scripted: no provider calls,
## and nothing here can open a gate or change energy, score or course progress.
## Shares NPCRoutineState's interface so conversations and travel treat both alike.
const WALK_SPEED: float = 1.2
const RUN_SPEED: float = 3.2
const HURRY_CHANCE: float = .15
const HURRY_DISTANCE: float = 12.0
const REPLAN_SECONDS: float = 3.0
const ABANDON_SECONDS: float = 7.0
const RIDE_SECONDS: float = 3.0
const LIFT_PATIENCE: float = 30.0
const FLOOR_CHANGE_COST: float = 8.0
var valid: bool = false
var started: bool = true
var talking: bool = false
var phase: String = "choose"
var id: String
var profile: Dictionary
var places: Array[Dictionary] = []
var actions: Dictionary
var claims: Dictionary
var planner: Callable
var area_open: Callable
var place: Dictionary = {}
var path: PackedVector3Array = PackedVector3Array()
var index: int = 0
var remaining: float = 0
var duration: float = 0
var speed: float = WALK_SPEED
var clock: float = 0
var last_done: Dictionary = {}
var avoid: Dictionary = {}
var stuck: float = 0
var exploring: bool = false
var rng := RandomNumberGenerator.new()
var visits: Array[String] = []
var reason: String = "starting"
var arrivals: int = 0
var conversations: int = 0
var lift: Dictionary = {}
var reserve_lift: Callable
var release_lift: Callable
var exit_clear: Callable
var riding_to: String = ""
var leg_target: Vector3
var lift_wait: float = 0
var rides: int = 0
var greeted: bool = false
var wave_remaining: float = 0

## places/actions come from npc-life.json; claims is shared by everyone so a spot holds one person.
func _init(actor_id: String, config: Dictionary, all_places: Array[Dictionary], action_table: Dictionary, shared_claims: Dictionary, path_planner: Callable, open_check: Callable) -> void:
	id = actor_id;profile = config;actions = action_table;claims = shared_claims
	planner = path_planner;area_open = open_check
	for record: Dictionary in all_places:
		if record.area in profile.get("areas", []): places.append(record)
	valid = not places.is_empty() and planner.is_valid() and area_open.is_valid()

## Optional elevator use: per-floor cab/exit/wait points plus the shared cab reservation.
func use_lift(points: Dictionary, reserve: Callable, release: Callable, clear: Callable) -> void:
	lift = points;reserve_lift = reserve;release_lift = release;exit_clear = clear

static func floor_of(point: Vector3) -> String:
	return "upper" if point.y > 3.0 else "lower"

func riding() -> bool:
	return phase in ["lift_wait","ride"]

## The first time someone notices the player while standing, they wave once.
func greet(seconds: float) -> bool:
	if greeted or talking or phase != "act": return false
	greeted = true;wave_remaining = seconds
	return true

func begin_conversation() -> void:
	talking = true;wave_remaining = 0

func end_conversation() -> void:
	talking = false
	conversations += 1

## Something else moved the body (an elevator errand): drop the spot and route afresh.
func interrupt() -> void:
	# A ride always finishes: the body is hidden in the cab and holds the shared reservation.
	if riding(): return
	_release();riding_to = "";place = {};path = PackedVector3Array();index = 0;stuck = 0;phase = "choose"

## "Go explore": head for the farthest place this person may visit.
func explore() -> bool:
	if not valid or talking or riding(): return false
	_release();exploring = true;phase = "choose"
	return true

func decide(position: Vector3, delta: float, allowed: bool) -> Dictionary:
	var idle: Dictionary = {"target":position,"speed":0.0,"animation":"Idle_Neutral","prop":_prop(),"face":null}
	if not valid or talking or not allowed: return idle
	clock += delta
	for key: String in avoid.keys():
		if avoid[key] <= clock: avoid.erase(key)
	if phase == "choose":
		if not _choose(position): return idle
	if phase == "walk":
		if path.is_empty():
			path = planner.call(position, leg_target);index = 0
			if path.is_empty():
				avoid[place.id] = clock+20;_release();phase = "choose";return idle
		while index < path.size() and _flat(path[index]-position) < .15: index += 1
		if index >= path.size():
			if riding_to.is_empty(): _arrive()
			else: phase = "lift_wait";lift_wait = 0
		else:
			return {"target":path[index],"speed":speed,"animation":"Run" if speed > 2.8 else "Walk","prop":_prop(),"face":null}
	if phase == "lift_wait" or phase == "ride": return _ride(position, delta)
	if wave_remaining > 0:
		# The wave pauses the action timer, then they carry on where they were.
		wave_remaining = maxf(0, wave_remaining-delta)
		return {"target":position,"speed":0.0,"animation":"Wave","prop":_prop(),"face":null,"greeting":true}
	remaining = maxf(0, remaining-delta)
	var action: Dictionary = actions[place.action]
	var animation: String = action.clip if remaining > duration*.6 else action.rest
	if remaining <= 0:
		_release();phase = "choose"
	return {"target":position,"speed":0.0,"animation":animation,"prop":_prop(),"face":place.face}

## The body reports when collision stops it; replan, then give the spot up.
func report_blocked(delta: float) -> void:
	if phase != "walk": return
	stuck += delta
	if stuck >= ABANDON_SECONDS:
		avoid[place.id] = clock+20;_release();riding_to = "";phase = "choose";reason = "gave up on "+str(place.id)+": path blocked"
	elif stuck >= REPLAN_SECONDS and fmod(stuck, REPLAN_SECONDS) < delta:
		path = PackedVector3Array();index = 0

func report_moving() -> void: stuck = 0

## Wait for the shared cab, ride hidden, then step out on the other floor and walk on.
func _ride(position: Vector3, delta: float) -> Dictionary:
	var here: String = floor_of(position)
	if phase == "lift_wait":
		if reserve_lift.call(id):
			phase = "ride";remaining = RIDE_SECONDS
			return {"target":lift[here].cab,"speed":0.0,"animation":"Idle_Neutral","prop":"","face":null,"hidden":true,"teleport":lift[here].cab}
		lift_wait += delta
		if lift_wait >= LIFT_PATIENCE:
			avoid[place.id] = clock+30;_release();riding_to = "";phase = "choose";reason = "gave up waiting for the elevator"
		return {"target":position,"speed":0.0,"animation":"Idle_Neutral","prop":"","face":lift[here].cab+Vector3.UP*1.5}
	remaining = maxf(0, remaining-delta)
	if remaining > 0 or not exit_clear.call(riding_to):
		return {"target":position,"speed":0.0,"animation":"Idle_Neutral","prop":"","face":null,"hidden":true}
	var exit: Vector3 = lift[riding_to].exit
	release_lift.call(id);rides += 1
	riding_to = "";phase = "walk";leg_target = place.position;index = 0
	path = planner.call(exit, place.position)
	return {"target":exit,"speed":0.0,"animation":"Idle_Neutral","prop":"","face":null,"hidden":false,"teleport":exit}

func current_action() -> String:
	return "" if place.is_empty() else str(place.action)

func _prop() -> String:
	if place.is_empty() or phase != "act": return ""
	var action: Dictionary = actions[place.action]
	return action.prop if remaining <= duration*.6 else ""

func _choose(position: Vector3) -> bool:
	var best: Dictionary = {}
	var best_score: float = -1
	var best_reason: String = ""
	for candidate: Dictionary in places:
		if candidate.id == place.get("id","") or avoid.has(candidate.id) or not area_open.call(candidate.area): continue
		if claims.get(candidate.id, id) != id: continue
		var crossing: bool = floor_of(candidate.position) != floor_of(position)
		if crossing and lift.is_empty(): continue
		var like: float = float(profile.likes.get(candidate.action, 0.0))
		if like <= 0: continue
		var since: float = clock-float(last_done.get(candidate.action, -120.0))
		var novelty: float = clampf(since/60.0, .15, 1.0)
		var distance: float = _flat(candidate.position-position)
		if crossing: distance = _flat(lift[floor_of(position)].wait-position)+_flat(candidate.position-lift[floor_of(candidate.position)].exit)+FLOOR_CHANGE_COST
		var reach: float = (1.0+distance/10.0) if exploring else 1.0/(1.0+distance/20.0)
		var home: float = float(profile.get("home_weight", 1.0)) if candidate.id == profile.get("home","") else 1.0
		var score: float = like*novelty*reach*home*rng.randf_range(.75, 1.25)
		if score > best_score:
			best = candidate;best_score = score
			best_reason = "%s: likes %s, last did it %ds ago%s" % [candidate.action, str(like), int(minf(since, 999)), " (home)" if home > 1 else ""]
	if best.is_empty(): return false
	var goal: Vector3 = best.position if floor_of(best.position) == floor_of(position) else lift[floor_of(position)].wait
	# Already standing there: no route needed (the navigation query returns nothing for it).
	var route: PackedVector3Array = PackedVector3Array([goal]) if _flat(goal-position) < .35 else planner.call(position, goal)
	if route.is_empty() or _flat(route[route.size()-1]-goal) > .35:
		avoid[best.id] = clock+30
		return false
	place = best;path = route;index = 0;stuck = 0;phase = "walk";leg_target = goal
	riding_to = "" if goal == best.position else floor_of(best.position)
	claims[place.id] = id
	reason = ("exploring → " if exploring else "")+best_reason
	exploring = false
	speed = RUN_SPEED if _length(route) > HURRY_DISTANCE and rng.randf() < HURRY_CHANCE else WALK_SPEED
	return true

func _arrive() -> void:
	phase = "act";arrivals += 1;stuck = 0
	duration = rng.randf_range(float(place.seconds[0]), float(place.seconds[1]));remaining = duration
	last_done[place.action] = clock
	visits.append(place.id)
	if visits.size() > 12: visits.pop_front()

func _release() -> void:
	if not place.is_empty() and claims.get(place.id, "") == id: claims.erase(place.id)

static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

static func _length(route: PackedVector3Array) -> float:
	var total: float = 0
	for i: int in range(1, route.size()): total += route[i].distance_to(route[i-1])
	return total
