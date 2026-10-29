extends RefCounted
## Ordered presentation evidence, separate from Mr. P's lesson state.
const BEATS: Array[String] = ["entered", "stand_up", "crowd", "get_to_work"]
var presented: Array[String] = []

func record(beat: String) -> bool:
	if completed() or beat != BEATS[presented.size()]: return false
	presented.append(beat)
	return true

func completed() -> bool:
	return presented == BEATS

func cancel(keep_completed: bool = false) -> void:
	if keep_completed and completed(): return
	presented.clear()
