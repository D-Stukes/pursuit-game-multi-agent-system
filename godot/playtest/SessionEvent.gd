extends RefCounted
## Only these two gate-result types are connected. Mr. P needs a later adapter.
const State = preload("res://playtest/SessionState.gd")
enum Kind { ENTRANCE_UNLOCKED, SHOOTER_WON }
var kind: Kind
var session_id: String
var event_id: String
var expected_stage: State.Stage

func _init(type: Kind, session: String, id: String, stage: State.Stage) -> void:
	kind = type
	session_id = session
	event_id = id
	expected_stage = stage
