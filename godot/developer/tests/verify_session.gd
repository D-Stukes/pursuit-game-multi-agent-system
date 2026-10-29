extends SceneTree
## Deterministic session rules; projectile fixtures are not an input playthrough.
const State = preload("res://game/SessionState.gd")
const Event = preload("res://game/SessionEvent.gd")
const Coordinator = preload("res://game/GameOrchestrator.gd")
const Entrance = preload("res://game/EntrancePuzzleState.gd")
const Shooter = preload("res://game/ElevatorShooterState.gd")
const Pipes = preload("res://developer/tests/PipeTestPilot.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, success: bool) -> void:
	checks += 1
	if not success: failures += 1
	print("PASS " if success else "FAIL ",label)

func win_fixture(shooter: RefCounted) -> void:
	shooter.start()
	while not shooter.completed():
		if shooter.phase == "between": shooter.between_waves = 0
		for enemy: Dictionary in shooter.enemies: shooter.shots.append(enemy.at)
		shooter.step(.001,Vector2.ZERO,false)

func run() -> void:
	var entrance: RefCounted = Entrance.new()
	var shooter: RefCounted = Shooter.new()
	var coordinator: RefCounted = Coordinator.new(entrance,shooter)
	var initial: Dictionary = coordinator.snapshot()
	check("fresh session has unique identity and entrance objective",initial.session_id.length()==32 and initial.stage=="entrance")
	check("both gates start locked",not coordinator.entrance_allowed() and not coordinator.ascent_allowed())
	check("course starts at approved placeholders",initial.course.energy==10 and initial.course.maximum_energy==10 and initial.course.score==0)
	initial.gates.entrance=true;initial.course.energy=99;initial.log.append({"fake":true})
	check("read snapshots cannot mutate live progress",not coordinator.snapshot().gates.entrance and coordinator.snapshot().course.energy==10 and coordinator.snapshot().log.is_empty())
	check("done prose cannot advance",not coordinator.submit({"done":true,"to":"orchestrator"}).accepted)
	check("Mr P results require a separate future adapter",not coordinator.submit({"question_complete":true,"energy":10}).accepted)
	var unlocked: RefCounted = coordinator.new_event(Event.Kind.ENTRANCE_UNLOCKED)
	check("early unlock event fails actual postcondition",coordinator.submit(unlocked).reason=="postcondition_failed")
	entrance.unlocked=true
	check("a flag alone cannot verify unsolved circuits",not coordinator.submit(unlocked).accepted)
	entrance.unlocked=false
	Pipes.solve_all(entrance)
	check("four boards without code still do not unlock",not coordinator.submit(unlocked).accepted)
	check("wrong entry code remains rejected",not entrance.enter_code("000") and not coordinator.submit(unlocked).accepted)
	entrance.enter_code(entrance.revealed_code())
	var stale: RefCounted = Event.new(Event.Kind.ENTRANCE_UNLOCKED,"other-session","stale",State.Stage.ENTRANCE)
	check("foreign session cannot publish real evidence",coordinator.submit(stale).reason=="stale_session")
	var bad: RefCounted = Event.new(Event.Kind.ENTRANCE_UNLOCKED,coordinator.snapshot().session_id,"bad\nvalue",State.Stage.ENTRANCE)
	check("malformed event identity rejected",coordinator.submit(bad).reason=="invalid_event_id")
	check("shooter cannot skip the entrance stage",not coordinator.submit(coordinator.new_event(Event.Kind.SHOOTER_WON)).accepted)
	check("verified boards and code publish entrance once",coordinator.submit(unlocked).accepted and coordinator.snapshot().stage=="elevator" and coordinator.entrance_allowed())
	var revision: int = coordinator.snapshot().revision
	check("exact replay is idempotent",coordinator.submit(unlocked).duplicate and coordinator.snapshot().revision==revision)
	var conflict: RefCounted = Event.new(Event.Kind.SHOOTER_WON,unlocked.session_id,unlocked.event_id,State.Stage.ELEVATOR)
	check("reused event id cannot change meaning",coordinator.submit(conflict).reason=="event_id_conflict")
	check("new repeat cannot earn entrance twice",not coordinator.submit(coordinator.new_event(Event.Kind.ENTRANCE_UNLOCKED)).accepted)
	check("entrance win alone cannot allow ascent",not coordinator.ascent_allowed())
	check("unfinished shooter cannot publish a win",not coordinator.submit(coordinator.new_event(Event.Kind.SHOOTER_WON)).accepted)
	win_fixture(shooter)
	var won: RefCounted = coordinator.new_event(Event.Kind.SHOOTER_WON)
	check("actual three-wave completion publishes elevator permission",coordinator.submit(won).accepted and coordinator.ascent_allowed())
	check("next objective is pending check-in rather than finished game",coordinator.snapshot().stage=="check_in_pending")
	check("objective does not imply physical arrival",coordinator.snapshot().zone=="street")
	coordinator.observe_zone("upstairs")
	check("physical zone is recorded separately",coordinator.snapshot().zone=="upstairs" and coordinator.snapshot().stage=="check_in_pending")
	coordinator.observe_zone("invented_course_completion")
	check("unknown physical zones are ignored",coordinator.snapshot().zone=="upstairs")
	check("gate events never charge or reward course values",coordinator.snapshot().course==State.new().snapshot().course)
	check("one active owner can claim the session",coordinator.claim("npc") and coordinator.snapshot().interaction=="npc")
	check("another interaction cannot overlap",not coordinator.claim("portal") and not coordinator.claim("lift"))
	coordinator.release("portal")
	check("wrong owner cannot release another interaction",coordinator.snapshot().interaction=="npc")
	coordinator.release("npc")
	check("closing releases ownership",coordinator.claim("portal"))
	coordinator.menu(true)
	check("Settings suspends portal ownership",coordinator.snapshot().interaction=="menu" and coordinator.snapshot().suspended_interaction=="portal" and not coordinator.claim("npc"))
	coordinator.menu(false)
	check("closing Settings restores only suspended owner",coordinator.snapshot().interaction=="portal" and coordinator.snapshot().suspended_interaction.is_empty())
	coordinator.release("portal");coordinator.claim("lift");coordinator.menu(true);coordinator.release("lift");coordinator.menu(false)
	check("completed suspended action cannot resume later",coordinator.snapshot().interaction.is_empty())
	check("unsupported interaction owner rejected",not coordinator.claim("mrp_auto_complete"))
	var second: RefCounted = Coordinator.new(Entrance.new(),Shooter.new())
	second.set_review(true)
	check("debug review allows inspection without earned gates",second.entrance_allowed() and second.ascent_allowed() and not second.gates_earned())
	check("review does not change objective or NPC progress facts",second.snapshot().stage=="entrance" and not second.npc_world_snapshot().entrance_unlocked and not second.npc_world_snapshot().elevator_unlocked)
	second.observe_zone("purple_room");second.set_review(false)
	check("leaving review restores undefeated gate locks",not second.entrance_allowed() and not second.ascent_allowed() and second.snapshot().stage=="entrance")
	check("fresh session cannot accept previous session event",second.snapshot().session_id!=coordinator.snapshot().session_id and second.submit(won).reason=="stale_session")
	check("new session resets course and progress",second.snapshot().course==State.new().snapshot().course and not second.gates_earned())
	for i: int in range(160): second.observe_zone("street" if i%2==0 else "ground")
	check("event history is bounded",second.snapshot().log.size()==State.MAX_LOG)
	print("SESSION_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
