extends RefCounted
## Pure controller fixtures. They are setup, not an input-driven gate playthrough.
const Coordinator = preload("res://game/GameOrchestrator.gd")
const Event = preload("res://game/SessionEvent.gd")
const Pipes = preload("res://developer/tests/PipeTestPilot.gd")

static func context(arrived: bool = true, tools: bool = true) -> Dictionary:
	var entrance: RefCounted = preload("res://game/EntrancePuzzleState.gd").new()
	var shooter: RefCounted = preload("res://game/ElevatorShooterState.gd").new()
	var check_in: RefCounted = preload("res://game/CheckInState.gd").new()
	var classroom: RefCounted = preload("res://game/ClassroomState.gd").new()
	var coordinator: RefCounted = Coordinator.new(entrance,shooter,tools,check_in,classroom)
	if arrived:
		Pipes.solve_all(entrance); entrance.enter_code(entrance.revealed_code())
		assert(coordinator.submit(coordinator.new_event(Event.Kind.ENTRANCE_UNLOCKED)).accepted)
		shooter.start()
		while not shooter.completed():
			if shooter.phase=="between": shooter.between_waves=0
			for enemy: Dictionary in shooter.enemies: shooter.shots.append(enemy.at)
			shooter.step(.001,Vector2.ZERO,false)
		assert(coordinator.submit(coordinator.new_event(Event.Kind.SHOOTER_WON)).accepted)
		coordinator.observe_zone("upstairs");coordinator.claim("check_in")
		check_in.start_photo("Adapter fixture");check_in.take_photo();check_in.confirm()
		assert(coordinator.submit(coordinator.new_event(Event.Kind.CHECK_IN_CONFIRMED)).accepted)
		coordinator.release("check_in");coordinator.claim("classroom")
		for beat: String in classroom.BEATS: classroom.record(beat)
		assert(coordinator.submit(coordinator.new_event(Event.Kind.CLASSROOM_INTRODUCED)).accepted)
		coordinator.release("classroom");coordinator.observe_zone("purple_room");coordinator.claim("course")
	return {"coordinator":coordinator,"entrance":entrance,"shooter":shooter,"check_in":check_in,"classroom":classroom}

static func answer(coordinator: RefCounted, choice: String) -> RefCounted:
	var course: Dictionary = coordinator.snapshot().course
	return coordinator.new_event(Event.Kind.COURSE_ANSWER_SUBMITTED,{"question_id":course.question_id,"answer_id":choice,"expected_revision":course.revision})
