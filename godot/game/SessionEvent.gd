extends RefCounted
## Gate and arrival evidence. Mr. P needs a separate later adapter.
const State = preload("res://game/SessionState.gd")
enum Kind { ENTRANCE_UNLOCKED, SHOOTER_WON, CHECK_IN_CONFIRMED }
var kind: Kind
var session_id: String
var event_id: String
var expected_stage: State.Stage

func _init(type: Kind, session: String, id: String, stage: State.Stage) -> void:
	kind = type
	session_id = session
	event_id = id
	expected_stage = stage
