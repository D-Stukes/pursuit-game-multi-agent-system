extends SceneTree
const Rules = preload("res://game/PipePuzzleState.gd")
const Pilot = preload("res://developer/tests/PipeTestPilot.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ", label)

func run() -> void:
	var state: RefCounted = Rules.new()
	check("new run starts at level one without rewards", state.level==0 and not state.completed() and state.rewards.is_empty())
	check("quarter turns preserve pipe shape", Rules.turn(3)==6 and Rules.turn(5)==10 and Rules.turn(9,4)==9)
	for level: int in range(4):
		check("expected board size "+str(level),state.width==[3,4,4,5][level] and state.masks.size()==state.width*state.width)
		check("board starts disconnected "+str(level),not state.connected() and not state.test_circuit())
		check("cannot skip unsolved board "+str(level),not state.next_level() and state.level==level and state.rewards.size()==level)
		var before: Array=state.masks.duplicate()
		check("invalid tile index rejected "+str(level),not state.rotate_tile(-1) and not state.rotate_tile(state.masks.size()) and state.masks==before)
		var hint: int=state.hint_index()
		check("hint explains a tile without granting reward "+str(level),hint>=0 and state.hint_text().contains("Connect") and not state.level_cleared)
		state.rotate_tile(hint)
		state.reset_level()
		check("reset restores this board only "+str(level),state.masks==before and state.moves==0 and state.rewards.size()==level)
		check("independent shape search finds a real solution "+str(level),Pilot.solve_level(state) and state.connected() and state.level_cleared)
		check("exactly one expected word reward "+str(level),state.rewards.size()==level+1 and state.rewards.back()==Rules.REWARDS[level])
		state.test_circuit();state.reset_level()
		check("cleared level is immutable and cannot duplicate reward "+str(level),not state.rotate_tile(0) and state.rewards.size()==level+1 and state.level_cleared)
		if level<3:
			check("intermediate phrase remains scrambled "+str(level),state.rewards.back()!="Welcome to Pursuit" and not state.completed())
			check("verified level advances once "+str(level),state.next_level() and state.level==level+1)
	check("fourth board reveals the exact final sentence",state.completed() and state.rewards.back()=="Welcome to Pursuit")
	check("no fifth level or repeated final reward",not state.next_level() and state.test_circuit() and state.rewards.size()==4)
	# Use nonauthored masks to exercise asymmetric connections and cycle safety.
	state=Rules.new()
	state.masks.fill(Rules.NORTH|Rules.SOUTH)
	state.masks[state.source]=Rules.WEST|Rules.EAST
	check("touching mismatched ports never carry power",state.reachable_tiles()==[state.source] and not state.connected())
	state.masks.fill(15)
	check("cycles terminate with each tile visited once",state.reachable_tiles().size()==9 and state.connected())
	state.masks[state.source]=Rules.NORTH|Rules.EAST
	check("source must face external input",state.reachable_tiles().is_empty() and not state.connected())
	var tile: Button=load("res://game/PipeTile.gd").new()
	tile.size=Vector2(96,96)
	root.add_child(tile)
	await process_frame
	tile.grab_focus()
	var clicks: Array=[]
	tile.pressed.connect(func():clicks.append(true))
	var event:=InputEventKey.new()
	event.keycode=KEY_ENTER
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await process_frame
	check("native tile accepts real keyboard activation",clicks.size()==1)
	tile.queue_free()
	await process_frame
	print("PIPES_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
