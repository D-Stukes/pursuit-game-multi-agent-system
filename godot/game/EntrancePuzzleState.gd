extends "res://game/PipePuzzleState.gd"
## The first verified circuit unlocks code entry; later circuits are optional.
var digits: Array[int] = []
var solved: bool:
 get: return completed()
var unlocked: bool = false
func _init() -> void:
 super()
 for i in range(4):digits.append(randi_range(0,9))
func completed() -> bool:
 return not rewards.is_empty()
func revealed_code() -> String:
 if not solved:return ""
 return "%d%d%d%d" % [digits[0],digits[1],digits[2],digits[3]]
func enter_code(value: String) -> bool:
 if not solved or value!=revealed_code():return false
 unlocked=true
 return true

## Skip support: mark the first circuit complete and the door unlocked so the
## orchestrator accepts the unlock exactly as a real solve would.
func force_complete() -> void:
 if rewards.is_empty():
  level_cleared=true
  rewards.append(REWARDS[level])
 unlocked=true
