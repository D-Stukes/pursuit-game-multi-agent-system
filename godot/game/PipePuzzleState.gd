extends RefCounted
## Four authored rotate-to-connect boards. Rendering never grants progress.

const NORTH: int = 1
const EAST: int = 2
const SOUTH: int = 4
const WEST: int = 8
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const REWARDS: Array[String] = ["Pursuit · Welcome · to", "to · Pursuit · Welcome", "Welcome · Pursuit · to", "Welcome to Pursuit"]
const BOARDS: Array[Dictionary] = [
	{"name":"First connection", "size":3, "path":[Vector2i(0,1),Vector2i(1,1),Vector2i(1,0),Vector2i(2,0)], "scramble":[0,1,3,0]},
	{"name":"Around the corner", "size":4, "path":[Vector2i(0,2),Vector2i(1,2),Vector2i(1,1),Vector2i(2,1),Vector2i(2,0),Vector2i(3,0)], "scramble":[0,1,0,3,1,0]},
	{"name":"Crossed wires", "size":4, "path":[Vector2i(0,1),Vector2i(1,1),Vector2i(1,2),Vector2i(2,2),Vector2i(2,1),Vector2i(3,1)], "scramble":[1,1,3,0,1,0]},
	{"name":"The final link", "size":5, "path":[Vector2i(0,3),Vector2i(1,3),Vector2i(1,2),Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3),Vector2i(4,3)], "scramble":[0,1,0,3,1,1,0,3,0]},
]
var level: int = 0
var width: int = 3
var source: int
var target: int
var masks: Array[int] = []
var initial_masks: Array[int] = []
var _solution: Dictionary = {}
var level_cleared: bool = false
var rewards: Array[String] = []
var moves: int = 0

func _init() -> void:
	_load_level()

static func turn(mask: int, times: int = 1) -> int:
	for _i: int in range(posmod(times, 4)):
		mask = ((mask << 1) & 15) | ((mask >> 3) & 1)
	return mask

func _load_level() -> void:
	var board: Dictionary = BOARDS[level]
	width = board.size
	masks.clear()
	_solution.clear()
	level_cleared = false
	moves = 0
	for i: int in range(width * width):
		masks.append(turn(NORTH | EAST if (i + level) % 3 else NORTH | SOUTH, (i * 3 + level) % 4))
	var path: Array = board.path
	source = path[0].y * width + path[0].x
	target = path[-1].y * width + path[-1].x
	for i: int in range(path.size()):
		var at: Vector2i = path[i]
		var before: Vector2i = path[i - 1] if i > 0 else at + Vector2i.LEFT
		var after: Vector2i = path[i + 1] if i + 1 < path.size() else at + Vector2i.RIGHT
		var mask: int = (1 << DIRECTIONS.find(before - at)) | (1 << DIRECTIONS.find(after - at))
		var index: int = at.y * width + at.x
		_solution[index] = mask
		masks[index] = turn(mask, board.scramble[i])
	initial_masks.assign(masks)

func rotate_tile(index: int) -> bool:
	if level_cleared or index < 0 or index >= masks.size(): return false
	masks[index] = turn(masks[index])
	moves += 1
	return true

func reachable_tiles() -> Array[int]:
	var visited: Array[int] = []
	if masks[source] & WEST == 0: return visited
	var pending: Array[int] = [source]
	while not pending.is_empty():
		var index: int = pending.pop_front()
		if index in visited: continue
		visited.append(index)
		var at := Vector2i(index % width, index / width)
		for direction: int in range(4):
			if masks[index] & (1 << direction) == 0: continue
			var next: Vector2i = at + DIRECTIONS[direction]
			if next.x < 0 or next.x >= width or next.y < 0 or next.y >= width: continue
			var neighbor: int = next.y * width + next.x
			if masks[neighbor] & (1 << ((direction + 2) % 4)) and neighbor not in visited:
				pending.append(neighbor)
	return visited

func connected() -> bool:
	return masks[target] & EAST != 0 and target in reachable_tiles()

func test_circuit() -> bool:
	if not connected(): return false
	if not level_cleared:
		level_cleared = true
		rewards.append(REWARDS[level])
	return true

func next_level() -> bool:
	if not level_cleared or level >= BOARDS.size() - 1: return false
	level += 1
	_load_level()
	return true

func reset_level() -> void:
	if level_cleared: return
	masks.assign(initial_masks)
	moves = 0

func hint_index() -> int:
	if level_cleared or connected(): return -1
	for index: int in _solution:
		if masks[index] != _solution[index]: return index
	return -1

func help_observation() -> Dictionary:
	# Read the existing authored hint without rotating, highlighting or verifying.
	var phase: String = "code" if completed() else ("next" if level_cleared else ("test" if connected() else "rotate"))
	var index: int = hint_index() if phase == "rotate" else -1
	var ports: Array[String] = []
	if index >= 0:
		for direction: int in range(4):
			if _solution[index] & (1 << direction): ports.append(["north","east","south","west"][direction])
	return {"kind":"pipe","phase":phase,"level":level+1,"size":width,"circuits":rewards.size(),
		"row":int(index/width)+1 if index>=0 else 0,"column":index%width+1 if index>=0 else 0,"ports":ports}

func hint_text() -> String:
	var index: int = hint_index()
	if index < 0: return "The route is connected. Choose Test circuit."
	return "Highlighted tile: row %d, column %d. Connect %s." % [index / width + 1, index % width + 1, ports_text(_solution[index])]

static func ports_text(mask: int) -> String:
	var ports := PackedStringArray()
	for i: int in range(4):
		if mask & (1 << i): ports.append(["up", "right", "down", "left"][i])
	return " + ".join(ports)

func completed() -> bool:
	return level == BOARDS.size() - 1 and level_cleared and rewards.size() == BOARDS.size()
