extends RefCounted
## Session progress is published only by GameOrchestrator. Readers receive copies.
enum Stage { ENTRANCE, ELEVATOR, CHECK_IN, CLASSROOM, PLATFORM, COURSE, ENDING }
const STAGES: Array[String] = ["entrance", "elevator", "check_in_pending", "classroom_pending", "mr_p_pending", "course_active", "ending_pending"]
const OBJECTIVES: Array[String] = ["Unlock the entrance", "Win the elevator shooter", "Check in at upstairs reception", "Join the classroom stand-up", "Use a classroom computer", "Complete the sample course activities", "Return to the classroom for your results"]
const MAX_LOG: int = 128

var _session_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
var _stage: Stage = Stage.ENTRANCE
var _gates: Dictionary = {"entrance":false,"elevator":false}
var _zone: String = "street"
var _interaction: String = ""
var _suspended: String = ""
var _review: bool = false
var _revision: int = 0
var _log: Array[Dictionary] = []
var _course: Dictionary = {"energy":10,"maximum_energy":10,"score":0,"question_id":"","attempts":0,"robot_parts":[]}
var _arrival: Dictionary = {"checked_in":false,"display_name":"","classroom_complete":false}
var _ending: Dictionary = {"presented":false}

func snapshot() -> Dictionary:
	return {"session_id":_session_id,"stage":STAGES[_stage],"objective":"Journey complete · Ready for L3" if _ending.presented else OBJECTIVES[_stage],
		"gates":_gates.duplicate(true),"zone":_zone,"interaction":_interaction,
		"suspended_interaction":_suspended,"review_mode":_review,"revision":_revision,
		"course":_course.duplicate(true),"arrival":_arrival.duplicate(true),"ending":_ending.duplicate(true),"log":_log.duplicate(true)}

func _record(kind: String, details: Dictionary = {}) -> void:
	_revision += 1
	_log.append({"revision":_revision,"kind":kind,"details":details.duplicate(true)})
	while _log.size() > MAX_LOG: _log.pop_front()
