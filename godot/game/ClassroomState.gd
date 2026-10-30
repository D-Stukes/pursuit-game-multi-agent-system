extends RefCounted
## Ordered presentation evidence, separate from Mr. P's lesson state.
const BEATS: Array[String] = ["entered", "stand_up", "crowd", "get_to_work"]
var presented: Array[String] = []
var skipped: bool=false

func record(beat: String) -> bool:
	if completed() or beat != BEATS[presented.size()]: return false
	presented.append(beat)
	return true

func completed() -> bool:
	return presented == BEATS or (skipped and not presented.is_empty() and presented[0]=="entered")

func cancel(keep_completed: bool = false) -> void:
	if keep_completed and completed(): return
	presented.clear()
	skipped=false

func skip_remaining() -> bool:
	if completed() or presented.is_empty() or presented[0]!="entered":return false
	skipped=true
	return true
