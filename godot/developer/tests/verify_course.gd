extends SceneTree
## Data contract + coordinator behavior, no rendered world or provider call.
const Adapter = preload("res://game/CourseAdapter.gd")
const Pilot = preload("res://developer/tests/CourseTestPilot.gd")
const Event = preload("res://game/SessionEvent.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(label: String, success: bool) -> void:
	checks += 1
	if not success: failures += 1
	print("PASS " if success else "FAIL ",label)

func run() -> void:
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://developer/course/sample-course.json"))
	var adapter: RefCounted = Adapter.new(definition)
	check("sample package validates independently of real Mr P",adapter.valid() and adapter.is_sample())
	var bad: Dictionary = definition.duplicate(true);bad.steps[1].id=bad.steps[0].id
	check("duplicate activity identity is rejected",not Adapter.new(bad).valid())
	bad=definition.duplicate(true);bad.steps[0].correct_id="invented"
	check("missing answer key is rejected",not Adapter.new(bad).valid())
	check("invalid energy settings are rejected",not Adapter.new(definition,{"maximum_energy":0}).valid() and not Adapter.new(definition,{"incorrect_cost":0}).valid())
	var early: RefCounted = Pilot.context(false).coordinator
	check("gates and classroom cannot be skipped",not early.claim("course") and not early.begin_course(adapter).accepted and early.snapshot().stage=="entrance")
	var disabled: RefCounted = Pilot.context(true,false).coordinator
	check("sample cannot enter a player-only game",not disabled.begin_course(adapter).accepted)
	var c: RefCounted = Pilot.context().coordinator
	c.set_review(true)
	check("review bypass cannot start course",not c.begin_course(adapter).accepted)
	c.set_review(false);c.observe_zone("upstairs")
	check("course requires the actual purple-world location",not c.begin_course(adapter).accepted)
	c.observe_zone("purple_room")
	check("verified arrival starts labelled sample course",c.begin_course(adapter).accepted and c.snapshot().course.mode=="sample" and c.snapshot().stage=="course_active")
	check("same adapter reopens without resetting",c.begin_course(adapter).duplicate)
	check("another adapter cannot replace active rules",not c.begin_course(Adapter.new(definition)).accepted)
	check("presentation never receives the answer key",not adapter.activity(c.snapshot().course).has("correct_id"))
	var before: Dictionary = c.snapshot()
	check("unknown choice has no cost",not c.submit(Pilot.answer(c,"unknown")).accepted and c.snapshot()==before)
	check("untyped done prose cannot award progress",not c.submit({"done":true,"question_complete":true}).accepted and c.snapshot()==before)
	var first: RefCounted = Pilot.answer(c,"guess")
	var late: RefCounted = Pilot.answer(c,"guess")
	check("first error costs one and rephrases",c.submit(first).accepted and c.snapshot().course.energy==9 and c.snapshot().course.attempts==1 and c.snapshot().course.feedback==definition.steps[0].rephrase)
	before=c.snapshot()
	check("same submission replay is idempotent",c.submit(first).duplicate and c.snapshot()==before)
	check("old same-question revision is rejected",c.submit(late).reason=="stale_course" and c.snapshot()==before)
	var conflict: RefCounted = Pilot.answer(c,"observe");conflict.event_id=first.event_id
	check("reusing event identity with new content fails",c.submit(conflict).reason=="event_id_conflict" and c.snapshot()==before)
	check("second error costs one and offers help",c.submit(Pilot.answer(c,"guess")).accepted and c.snapshot().course.energy==8 and c.snapshot().course.attempts==2 and c.snapshot().course.help_available)
	check("later errors keep retries and help",c.submit(Pilot.answer(c,"guess")).accepted and c.snapshot().course.energy==7 and c.snapshot().course.attempts==3)
	var cancelled: RefCounted = Pilot.answer(c,"observe")
	c.release("course");c.claim("course")
	before=c.snapshot()
	check("late result after close/reopen is rejected",c.submit(cancelled).reason=="stale_interaction" and c.snapshot()==before)
	c.menu(true)
	check("Settings blocks course submissions",not c.submit(Pilot.answer(c,"observe")).accepted)
	c.menu(false)
	check("correct answer advances immediately and resets attempts",c.submit(Pilot.answer(c,"observe")).accepted and c.snapshot().course.question_id=="sample-decide" and c.snapshot().course.attempts==0 and c.snapshot().course.energy==8 and c.snapshot().course.score==10)
	check("next correct answer awards only its own reward",c.submit(Pilot.answer(c,"decide")).accepted and c.snapshot().course.energy==9 and c.snapshot().course.score==20)
	c.submit(Pilot.answer(c,"claim"))
	check("challenge receipt uses +3 capped and 30 points",c.submit(Pilot.answer(c,"verify")).accepted and c.snapshot().course.energy==10 and c.snapshot().course.score==50 and c.snapshot().course.completed_challenges==["sample-challenge-checkpoint"])
	check("challenge alone cannot finish remaining questions",c.snapshot().stage=="course_active" and not c.snapshot().course.complete)
	var last: RefCounted = Pilot.answer(c,"return")
	check("all required sample results expose ending boundary",c.submit(last).accepted and c.snapshot().stage=="ending_pending" and c.snapshot().course.complete and c.snapshot().course.score==60 and c.snapshot().course.energy==10)
	before=c.snapshot()
	check("completed receipt cannot duplicate rewards",c.submit(last).duplicate and c.snapshot()==before)
	check("new event cannot answer a completed course",not c.submit(Pilot.answer(c,"return")).accepted and c.snapshot()==before)
	var zero_adapter: RefCounted = Adapter.new(definition)
	var z: RefCounted = Pilot.context().coordinator;z.begin_course(zero_adapter)
	for attempt: int in range(10):
		check("actual incorrect submission costs one",z.submit(Pilot.answer(z,"guess")).accepted and z.snapshot().course.energy==9-attempt)
	check("zero-energy shared feedback requires recovery",z.snapshot().course.feedback.contains("Confirm recovery") and not z.snapshot().course.feedback.contains("keep trying"))
	before=z.snapshot()
	check("zero blocks even a correct answer without extra cost",z.submit(Pilot.answer(z,"observe")).reason=="recovery_required" and z.snapshot()==before)
	var forged: RefCounted = z.new_event(Event.Kind.COURSE_RECOVERY_COMPLETED,{"expected_revision":z.snapshot().course.revision,"recovery_id":"fake"})
	check("done signal alone cannot refill energy",z.submit(forged).reason=="recovery_incomplete" and z.snapshot()==before)
	var recovery_id: String = zero_adapter.begin_recovery(z.snapshot().course)
	check("recovery needs a presented supportive interaction",not recovery_id.is_empty() and not zero_adapter.confirm_recovery(z.snapshot().course,recovery_id))
	zero_adapter.present_recovery(z.snapshot().course,recovery_id);zero_adapter.cancel_recovery()
	check("declining recovery retains zero and attempts",z.snapshot().course==before.course and not zero_adapter.confirm_recovery(z.snapshot().course,recovery_id))
	var current_id: String = zero_adapter.begin_recovery(z.snapshot().course)
	zero_adapter.present_recovery(z.snapshot().course,current_id);zero_adapter.confirm_recovery(z.snapshot().course,current_id)
	check("cancelled recovery identity stays invalid",not z.submit(z.new_event(Event.Kind.COURSE_RECOVERY_COMPLETED,{"expected_revision":z.snapshot().course.revision,"recovery_id":recovery_id})).accepted)
	var recovered: RefCounted = z.new_event(Event.Kind.COURSE_RECOVERY_COMPLETED,{"expected_revision":z.snapshot().course.revision,"recovery_id":current_id})
	check("completed support refills 10 and retains attempts",z.submit(recovered).accepted and z.snapshot().course.energy==10 and z.snapshot().course.attempts==10 and z.snapshot().course.question_id=="sample-observe")
	before=z.snapshot()
	check("recovery replay is idempotent",z.submit(recovered).duplicate and z.snapshot()==before)
	check("nonzero recovery cannot farm energy",zero_adapter.begin_recovery(z.snapshot().course).is_empty())
	check("correct after recovery resets only the next question",z.submit(Pilot.answer(z,"observe")).accepted and z.snapshot().course.attempts==0 and z.snapshot().course.score==10 and z.snapshot().course.energy==10)
	# New data/order/count/config, unchanged adapter: no special routing for sample IDs.
	var held_out: Dictionary = {"id":"held-out-package","sample":true,"steps":[definition.steps[2].duplicate(true),definition.steps[0].duplicate(true)]}
	for index: int in range(held_out.steps.size()):
		held_out.steps[index].id="held-out-%d"%index
		held_out.steps[index].choices=[{"id":"new-no","text":"An unsupported claim"},{"id":"new-yes","text":"A verified result"}]
		held_out.steps[index].correct_id="new-yes"
	var path: String = "res://.godot/playtest/held-out-course.json"
	DirAccess.make_dir_recursive_absolute("res://.godot/playtest")
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(held_out));file.close()
	var fresh: RefCounted = Adapter.new(JSON.parse_string(FileAccess.get_file_as_string(path)),{"starting_energy":4,"maximum_energy":7})
	var h: RefCounted = Pilot.context().coordinator
	check("fresh held-out package binds without adapter edits",h.begin_course(fresh).accepted and h.snapshot().course.energy==4 and h.snapshot().course.maximum_energy==7)
	for step: Dictionary in held_out.steps: check("held-out answer verifies",h.submit(Pilot.answer(h,step.correct_id)).accepted)
	check("held-out count and challenge order define completion",h.snapshot().course.complete and h.snapshot().course.score==40 and h.snapshot().course.energy==7)
	check("fresh session has no prior course progress",Pilot.context(false).coordinator.snapshot().course.question_id.is_empty())
	print("COURSE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
