extends RefCounted
## Independent shape-constrained route search for tests, never imported by game.
## Reads visible pipe shapes/terminals, not the authored solution or hint map.
const D: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func route(state: RefCounted) -> Dictionary:
	return _search(state, state.source, 3, [], {})

static func _search(state: RefCounted, index: int, incoming: int, visited: Array, rotations: Dictionary) -> Dictionary:
	if index in visited: return {}
	var used: Array = visited.duplicate()
	used.append(index)
	for rotation: int in range(4):
		var mask: int = state.turn(state.masks[index], rotation)
		if mask & (1 << incoming) == 0: continue
		for outgoing: int in range(4):
			if outgoing == incoming or mask & (1 << outgoing) == 0: continue
			var candidate: Dictionary = rotations.duplicate()
			candidate[index] = rotation
			if index == state.target and outgoing == 1: return candidate
			var at: Vector2i = Vector2i(index % state.width, index / state.width) + D[outgoing]
			if at.x < 0 or at.x >= state.width or at.y < 0 or at.y >= state.width: continue
			var result: Dictionary = _search(state, at.y * state.width + at.x, (outgoing + 2) % 4, used, candidate)
			if not result.is_empty(): return result
	return {}

static func solve_level(state: RefCounted) -> bool:
	var rotations: Dictionary = route(state)
	if rotations.is_empty(): return false
	for index: int in rotations:
		for _i: int in range(rotations[index]): state.rotate_tile(index)
	return state.test_circuit()

static func solve_all(state: RefCounted) -> bool:
	for _i: int in range(4):
		if not solve_level(state): return false
		if state.level<state.BOARDS.size()-1 and not state.next_level(): return false
	return state.completed()
