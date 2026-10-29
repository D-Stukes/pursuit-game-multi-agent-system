extends RefCounted
## Deterministic local coordinator. No provider calls or authored course answers.
const State = preload("res://game/SessionState.gd")
const Event = preload("res://game/SessionEvent.gd")
const EntranceRules = preload("res://game/EntrancePuzzleState.gd")
const ShooterRules = preload("res://game/ElevatorShooterState.gd")
const CheckInRules = preload("res://game/CheckInState.gd")
const ClassroomRules = preload("res://game/ClassroomState.gd")
const OWNERS: Array[String] = ["entrance", "shooter", "npc", "portal", "lift", "check_in", "classroom"]
const ZONES: Array[String] = ["street", "ground", "upstairs", "purple_room"]
var _state: RefCounted = State.new()
var _entrance: RefCounted
var _shooter: RefCounted
var _serial: int = 0
var _accepted: Dictionary = {}
var _allow_developer_tools: bool
var _check_in: RefCounted
var _classroom: RefCounted

func _init(entrance: RefCounted, shooter: RefCounted, allow_developer_tools: bool=true, check_in: RefCounted=null, classroom: RefCounted=null) -> void:
	assert(entrance is EntranceRules and shooter is ShooterRules)
	assert(check_in == null or check_in is CheckInRules)
	assert(classroom == null or classroom is ClassroomRules)
	_entrance = entrance
	_shooter = shooter
	_allow_developer_tools=allow_developer_tools and OS.is_debug_build()
	_check_in = check_in
	_classroom = classroom

func snapshot() -> Dictionary:
	return _state.snapshot()

func objective() -> String:
	return State.OBJECTIVES[_state._stage]

func review_enabled() -> bool:
	return _state._review

func new_event(kind: Event.Kind) -> RefCounted:
	_serial += 1
	return Event.new(kind,_state._session_id,"gate-%d"%_serial,_state._stage)

func submit(candidate: Variant) -> Dictionary:
	if not candidate is Event: return _reject("invalid_event")
	if candidate.session_id != _state._session_id: return _reject("stale_session")
	if candidate.kind not in [Event.Kind.ENTRANCE_UNLOCKED,Event.Kind.SHOOTER_WON,Event.Kind.CHECK_IN_CONFIRMED,Event.Kind.CLASSROOM_INTRODUCED]: return _reject("unsupported_event")
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_.:-]{1,80}$")
	if pattern.search(candidate.event_id) == null: return _reject("invalid_event_id")
	var fingerprint: Array = [candidate.kind,candidate.expected_stage]
	if _accepted.has(candidate.event_id):
		if _accepted[candidate.event_id] != fingerprint: return _reject("event_id_conflict")
		return {"accepted":true,"duplicate":true,"reason":"already_applied"}
	if candidate.expected_stage != _state._stage: return _reject("wrong_stage")
	var gate: String = ""
	var record_kind: String = "gate_verified"
	match candidate.kind:
		Event.Kind.ENTRANCE_UNLOCKED:
			if _state._stage != State.Stage.ENTRANCE: return _reject("wrong_stage")
			if not _entrance.completed() or not _entrance.unlocked: return _reject("postcondition_failed")
			gate = "entrance"
		Event.Kind.SHOOTER_WON:
			if _state._stage != State.Stage.ELEVATOR or not _state._gates.entrance: return _reject("wrong_stage")
			if not _shooter.completed(): return _reject("postcondition_failed")
			gate = "elevator"
		Event.Kind.CHECK_IN_CONFIRMED:
			if not check_in_allowed() or _state._interaction != "check_in": return _reject("wrong_stage")
			if _check_in == null or not _check_in.completed(): return _reject("postcondition_failed")
			_state._arrival.checked_in = true
			_state._arrival.display_name = _check_in.display_name
			_state._stage = State.Stage.CLASSROOM
			record_kind = "check_in_verified"
		Event.Kind.CLASSROOM_INTRODUCED:
			if not classroom_allowed() or _state._interaction != "classroom": return _reject("wrong_stage")
			if _classroom == null or not _classroom.completed(): return _reject("postcondition_failed")
			_state._arrival.classroom_complete = true
			_state._stage = State.Stage.PLATFORM
			record_kind = "classroom_verified"
	# Publish earned permission and the next objective in the same local turn.
	if not gate.is_empty():
		_state._gates[gate] = true
		_state._stage = State.Stage.ELEVATOR if gate == "entrance" else State.Stage.CHECK_IN
	_accepted[candidate.event_id] = fingerprint
	_state._record(record_kind,{"event_id":candidate.event_id,"gate":gate,"stage":State.STAGES[_state._stage]})
	return {"accepted":true,"duplicate":false,"reason":"verified"}

func _reject(reason: String) -> Dictionary:
	return {"accepted":false,"duplicate":false,"reason":reason}

func entrance_allowed() -> bool:
	return _state._review or _state._gates.entrance

func ascent_allowed() -> bool:
	return _state._review or (_state._gates.entrance and _state._gates.elevator)

func gates_earned() -> bool:
	return _state._gates.entrance and _state._gates.elevator

func checked_in() -> bool:
	return _state._arrival.checked_in

func check_in_allowed() -> bool:
	return _state._stage == State.Stage.CHECK_IN and gates_earned() and _state._zone == "upstairs" and not _state._review

func classroom_allowed() -> bool:
	return _state._stage == State.Stage.CLASSROOM and checked_in() and _state._zone == "upstairs" and not _state._review

func set_review(enabled: bool) -> void:
	var permitted: bool = enabled and _allow_developer_tools
	if permitted == _state._review: return
	_state._review = permitted
	_state._record("review_changed",{"enabled":permitted})

func observe_zone(zone: String) -> void:
	if zone not in ZONES or zone == _state._zone: return
	_state._zone = zone
	_state._record("zone_changed",{"zone":zone})

func claim(owner: String) -> bool:
	if owner not in OWNERS: return false
	if not _state._interaction.is_empty(): return _state._interaction == owner
	if owner == "entrance" and _state._stage != State.Stage.ENTRANCE: return false
	if owner == "shooter" and _state._stage != State.Stage.ELEVATOR: return false
	_state._interaction = owner
	_state._record("interaction_started",{"owner":owner})
	return true

func release(owner: String) -> void:
	if _state._interaction == owner:
		_state._interaction = ""
		_state._record("interaction_ended",{"owner":owner})
	elif _state._suspended == owner:
		_state._suspended = ""
		_state._record("suspended_interaction_ended",{"owner":owner})

func menu(open: bool) -> void:
	if open:
		if _state._interaction == "menu": return
		_state._suspended = _state._interaction
		_state._interaction = "menu"
	else:
		if _state._interaction != "menu": return
		_state._interaction = _state._suspended
		_state._suspended = ""
	_state._record("menu_changed",{"open":open})

func npc_world_snapshot() -> Dictionary:
	# Social requests use reception as their known local area, never a review win.
	return {"zone":"reception","entrance_unlocked":bool(_state._gates.entrance),"elevator_unlocked":bool(_state._gates.elevator)}

func builder_world_snapshot() -> Dictionary:
	var challenge: Dictionary = {"kind":"travel" if _state._zone in ["street","ground"] else "none"}
	if _state._stage == State.Stage.ENTRANCE:
		challenge = _entrance.help_observation()
	elif _state._stage == State.Stage.ELEVATOR:
		challenge = {"kind":"shooter","phase":_shooter.phase,"wave":_shooter.wave,
			"cleared":_shooter.cleared,"shields":_shooter.shields}
	return {"zone":_state._zone,"stage":State.STAGES[_state._stage],
		"entrance_unlocked":bool(_state._gates.entrance),"elevator_unlocked":bool(_state._gates.elevator),
		"challenge":challenge.duplicate(true)}
