extends RefCounted
## Session-only entrance rules. The code is revealed only by a verified order.

const STEPS: Array[String] = ["Sense", "Decide", "Act"]
var digits: Array[int] = []
var solved: bool = false
var unlocked: bool = false

func _init() -> void:
	var pool: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	pool.shuffle()
	digits.assign(pool.slice(0, 3))

func check_order(order: Array) -> bool:
	if order != [0, 1, 2]:
		return false
	solved = true
	return true

func revealed_code() -> String:
	if not solved:
		return ""
	return "%d%d%d" % [digits[0], digits[1], digits[2]]

func enter_code(value: String) -> bool:
	if not solved or value.strip_edges() != revealed_code():
		return false
	unlocked = true
	return true
