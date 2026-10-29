extends "res://game/PipePuzzleState.gd"
## Door code is available only after all four independently verified circuits.
var digits: Array[int] = []
var solved: bool:
	get: return completed()
var unlocked: bool = false

func _init() -> void:
	super()
	var pool: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	pool.shuffle()
	digits.assign(pool.slice(0, 3))

func revealed_code() -> String:
	if not solved:
		return ""
	return "%d%d%d" % [digits[0], digits[1], digits[2]]

func enter_code(value: String) -> bool:
	if not solved or value.strip_edges() != revealed_code():
		return false
	unlocked = true
	return true
