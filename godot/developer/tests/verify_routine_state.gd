extends SceneTree
const Routine = preload("res://game/characters/NPCRoutineState.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	var config: Dictionary = {"offsets":[[1,0,0],[0,0,0]],"speed":1.2,"wait_seconds":2,"activity":"Interact"}
	var state: RefCounted = Routine.new(config,Vector3.ZERO)
	check("uncontacted actor stays idle",state.valid and state.decide(Vector3.ZERO,1,true).speed==0 and not state.started)
	state.begin_conversation()
	check("conversation itself cannot start walking",state.decide(Vector3.ZERO,1,true).speed==0)
	state.end_conversation()
	check("closing starts the authored route",state.started and state.conversations==1 and state.decide(Vector3.ZERO,.1,true).target==Vector3.RIGHT)
	check("paused actor has no motion",state.decide(Vector3.ZERO,.5,false).speed==0)
	state.decide(Vector3.RIGHT,.1,true)
	check("actual arrival selects the next waypoint and activity",state.arrivals==1 and state.index==1 and state.phase=="activity")
	var remaining: float = state.remaining
	state.decide(Vector3.RIGHT,1,false);state.begin_conversation();state.decide(Vector3.RIGHT,1,true)
	check("menu or conversation preserves activity time",state.remaining==remaining)
	state.end_conversation();state.decide(Vector3.RIGHT,3,true)
	check("another conversation resumes instead of resetting",state.conversations==2 and state.index==1 and state.phase=="walk")
	state.decide(Vector3.ZERO,.1,true)
	check("round trip cycles without a game reward",state.index==0 and state.arrivals==2)
	var other: Dictionary = {"offsets":[[0,0,-2],[-1,0,-2],[0,0,0]],"speed":3.4,"wait_seconds":1,"activity":"Wave"}
	var home := Vector3(20,128,-8)
	var held_out: RefCounted = Routine.new(other,home);held_out.end_conversation()
	check("unseen three-point route and home use unchanged controller",held_out.valid and held_out.waypoints.size()==3 and held_out.decide(home,.1,true).target==home+Vector3(0,0,-2))
	check("run clip is an available bounded movement capability",held_out.decide(home,.1,true).animation=="Run")
	for change: Dictionary in [{"speed":0},{"speed":INF},{"wait_seconds":NAN},{"activity":"UnlockGate"},{"offsets":[[50,0,0],[0,0,0]]},{"offsets":[[1,2,0],[0,0,0]]},{"offsets":[[1,.08,0],[0,0,0]]},{"offsets":[[0,0,0],[0,0,0]]},{"offsets":[[true,0,0],[0,0,0]]}]:
		var invalid: Dictionary = config.duplicate(true);invalid.merge(change,true)
		check("invalid route stays inert "+str(change),not Routine.new(invalid,Vector3.ZERO).valid)
	check("fresh role has no inherited activation",not Routine.new(config,Vector3.ZERO).started)
	print("ROUTINE_STATE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
