extends Node
## Guided hand-offs and reactions along the route: the host speaks first, Rosa walks the
## player to the elevator, reception meets them upstairs and leads them to check-in, then
## points to the classroom. People cheer, look up and head to work at the right moments.
## Reads verified progress only; nothing here can open a gate or change progress.
const LINES_PATH: String = "res://assets/characters/npc-dialogue.json"
const HOST: String = "StreetWestB"
const BUILDER: String = "StreetWestA"
const GREETER: String = "LobbyGreeter"
const GUIDE: String = "ReceptionA"
const RECEPTION: Array[String] = ["ReceptionA","ReceptionB"]
const UPSTAIRS: Array[String] = ["ReceptionA","ReceptionB"]
const GUIDE_PATIENCE: float = 150.0
## A lead ends if the player stays away this long (another floor, or wandered off).
const LEAD_PATIENCE: float = 45.0
var lobby_wait: float = 0
var upstairs_wait: float = 0
var world: Node3D
var population: Node3D
var lines: Dictionary
var done: Dictionary = {}
var lobby: String = "idle"
var upstairs: String = "idle"
var upstairs_clock: float = 0
var spots: Dictionary

func _ready() -> void:
	lines = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH)).journey_lines

func configure() -> void:
	var landing: Vector3 = world.UPPER_LIFT_EXIT
	spots = {
		"ground_escort":_spot("journey_ground_escort","ground",world.LOWER_LIFT_EXIT+Vector3(1.0,0,1.0),world.LIFT_GROUND+Vector3.UP*1.5),
		"upper_meet":_spot("journey_upper_meet","upper",landing+Vector3(1.0,0,1.6),landing+Vector3.UP*1.5),
		"checkin_side":_spot("journey_checkin_side","upper",Vector3(2.2,5.05,-5.6),Vector3(3.1,6.4,-5.2)),
	}

static func _spot(id: String, area: String, at: Vector3, face: Vector3, seconds: float = 6.0) -> Dictionary:
	return {"id":id,"area":area,"action":"look","position":at,"face":face,"seconds":[seconds,seconds]}

func person(id: String) -> CharacterBody3D:
	return population.get_node_or_null(NodePath(id))

func say(beat: String) -> bool:
	var line: Array = lines[beat]
	return world.npc_conversations.say(str(line[0]), str(line[1]))

func update(delta: float) -> void:
	if world.building_review_mode or (world.intro != null and world.intro.active): return
	var orchestrator: RefCounted = world.orchestrator
	var at: Vector3 = world.player.global_position
	_host_intro(at, orchestrator)
	_door_cheer(at, orchestrator)
	_lobby_escort(at, orchestrator)
	_upstairs_guide(at, orchestrator, delta)
	_arrival_alert(at)
	_after_check_in(at, orchestrator)
	_after_classroom(orchestrator)

func _near(id: String, at: Vector3, reach: float) -> bool:
	var body: CharacterBody3D = person(id)
	return body != null and body.visible and absf(body.global_position.y-at.y) < 1.5 and body.global_position.distance_to(at) < reach

## Street: the host speaks first as the player approaches the closed entrance.
func _host_intro(at: Vector3, orchestrator: RefCounted) -> void:
	if done.has("host_intro") or orchestrator.gate_passed("entrance"): return
	if at.y < 1 and _near(HOST, at, 5.0) and say("host_intro"):
		person(HOST).routine.cheer(person(HOST).wave_seconds()*.92)
		done.host_intro = true

## Street people cheer when the door opens (solved or skipped, it is open either way).
func _door_cheer(at: Vector3, orchestrator: RefCounted) -> void:
	if done.has("door_cheer") or not orchestrator.gate_passed("entrance"): return
	done.door_cheer = true
	for id: String in [HOST, BUILDER]:
		if _near(id, at, 12.0): person(id).routine.cheer(person(id).wave_seconds()*.92)
	if _near(HOST, at, 12.0): say("door_open")

## Lobby: once the door is open and the player is inside, Rosa walks them to the elevator.
func _lobby_escort(at: Vector3, orchestrator: RefCounted) -> void:
	var rosa: CharacterBody3D = person(GREETER)
	if rosa == null or lobby == "done": return
	if orchestrator.gate_passed("elevator") or at.y > 3:
		if lobby == "leading": rosa.routine.interrupt()
		lobby = "done";return
	if lobby == "idle" and orchestrator.gate_passed("entrance") and at.z < 4.4 and _near(GREETER, at, 8.0):
		if say("lobby_welcome") and rosa.routine.assign(spots.ground_escort, true, false, "walking the player to the elevator"):
			lobby = "leading"
	elif lobby == "leading" and rosa.routine.phase == "act" and rosa.routine.place.get("id","") == spots.ground_escort.id:
		say("lobby_arrived");lobby = "done"
	elif lobby == "leading":
		lobby_wait = lobby_wait+get_physics_process_delta_time() if not _near(GREETER, at, 6.0) else 0.0
		if lobby_wait > LEAD_PATIENCE: rosa.routine.interrupt();lobby = "done"

## Upstairs: after the elevator, the guide waits at the doors, cheers, then leads to check-in.
func _upstairs_guide(at: Vector3, orchestrator: RefCounted, delta: float) -> void:
	var guide: CharacterBody3D = person(GUIDE)
	if guide == null or upstairs == "done": return
	if orchestrator.checked_in():
		if upstairs != "idle": guide.routine.interrupt();guide.routine.release_hold()
		upstairs = "done";return
	match upstairs:
		"idle":
			if orchestrator.gate_passed("elevator") and guide.routine.assign(spots.upper_meet, false, true, "waiting for the player at the elevator"):
				upstairs = "meeting";upstairs_clock = 0
		"meeting":
			upstairs_clock += delta
			if at.y > 3 and _near(GUIDE, at, 4.5) and not guide.routine.riding() and say("upstairs_welcome"):
				guide.routine.cheer(guide.wave_seconds()*.92)
				guide.routine.assign(spots.checkin_side, true, false, "leading the player to check-in")
				upstairs = "leading"
			elif upstairs_clock > GUIDE_PATIENCE:
				guide.routine.release_hold();upstairs = "done"
		"leading":
			if guide.routine.phase == "act" and guide.routine.place.get("id","") == spots.checkin_side.id:
				say("checkin_here");upstairs = "done"
			else:
				upstairs_wait = upstairs_wait+delta if not _near(GUIDE, at, 6.0) else 0.0
				if upstairs_wait > LEAD_PATIENCE: guide.routine.interrupt();upstairs = "done"

## Reception looks up when the player first arrives upstairs.
func _arrival_alert(at: Vector3) -> void:
	if done.has("arrival_alert") or at.y < 3: return
	done.arrival_alert = true
	for id: String in RECEPTION:
		if _near(id, at, 12.0): person(id).alert_remaining = 3.0

## After check-in, the nearest reception person points the way to the classroom.
func _after_check_in(at: Vector3, orchestrator: RefCounted) -> void:
	if done.has("classroom_point") or not orchestrator.checked_in(): return
	done.classroom_point = true
	for id: String in RECEPTION:
		if _near(id, at, 9.0) and say("classroom_point"):
			var body: CharacterBody3D = person(id)
			var door: Vector3 = world.approved_layout.anchor("classroom_door")
			body.routine.assign(_spot("journey_point","upper",body.global_position,door+Vector3.UP*1.5,4.0), false, false, "pointing to the classroom")
			return

## After the stand-up, people head to their laptops for a while.
func _after_classroom(orchestrator: RefCounted) -> void:
	if done.has("laptops") or not orchestrator.snapshot().arrival.classroom_complete: return
	done.laptops = true
	for id: String in UPSTAIRS:
		var body: CharacterBody3D = person(id)
		if body != null: body.routine.boost("laptop", 4.0, 120.0)
