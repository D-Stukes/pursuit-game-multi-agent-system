extends RefCounted
## Gate, arrival and authored course submissions. Provider prose is not evidence.
const State = preload("res://game/SessionState.gd")
enum Kind { ENTRANCE_UNLOCKED, SHOOTER_WON, CHECK_IN_CONFIRMED, CLASSROOM_INTRODUCED, COURSE_ANSWER_SUBMITTED, COURSE_RECOVERY_COMPLETED, ENDING_PRESENTED }
var kind: Kind
var session_id: String
var event_id: String
var expected_stage: State.Stage
var payload: Dictionary
var interaction_id: String = ""

func _init(type: Kind, session: String, id: String, stage: State.Stage, data: Dictionary = {}) -> void:
	kind = type
	session_id = session
	event_id = id
	expected_stage = stage
	payload = data.duplicate(true)
