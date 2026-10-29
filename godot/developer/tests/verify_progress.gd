extends SceneTree
const Setup = preload("res://developer/tests/CourseWorldPilot.gd")
const Event = preload("res://game/SessionEvent.gd")
var world: Node3D
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)
func answer(id: String) -> RefCounted:
	var course: Dictionary = world.orchestrator.snapshot().course
	var event: RefCounted = world.orchestrator.new_event(Event.Kind.COURSE_ANSWER_SUBMITTED,{"question_id":course.question_id,"answer_id":id,"expected_revision":course.revision})
	world.orchestrator.submit(event);await frames()
	return event

func run() -> void:
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	var display: Control = world.hud.progress_display
	check("normal exploration shows shared baseline without developer view",display.is_visible_in_tree() and display.metrics.text=="Energy 10 / 10 · Score 0" and display.meter.value==10 and display.activity.text=="Activities: not started" and not world.hud.debug_mode)
	check("progress is noninteractive and cannot capture keyboard focus",display.mouse_filter==Control.MOUSE_FILTER_IGNORE and display.meter.focus_mode==Control.FOCUS_NONE and display.meter.mouse_filter==Control.MOUSE_FILTER_IGNORE and display.find_children("*","Button",true,false).is_empty())
	var original: Dictionary = world.orchestrator.snapshot()
	# Held-out input: different counts, IDs, maximum and large score, no HUD edits.
	var fixture: Dictionary = {"course":{"energy":3,"maximum_energy":7,"score":1234567890123,"mode":"authored","required_questions":["unseen-a","unseen-b"],"required_challenges":["unseen-c","unseen-d"],"completed_questions":["unseen-a","unseen-a","unknown"],"completed_challenges":["unseen-c"],"complete":true}}
	var saved: Dictionary = fixture.duplicate(true)
	var held_out: Control = load("res://game/GameHUD.gd").new();held_out.developer_tools_allowed=false;root.add_child(held_out)
	held_out.set_progress(fixture)
	check("held-out maximum score and required-set intersection display correctly",held_out.progress_display.metrics.text=="Energy 3 / 7 · Score 1234567890123" and held_out.progress_display.meter.max_value==7 and held_out.progress_display.meter.value==3 and held_out.progress_display.activity.text=="Activities: 2 / 4")
	check("rendering neither mutates its input nor authoritative state",fixture==saved and world.orchestrator.snapshot()==original)
	held_out.set_objective("Complete the currently required activities, then return to the classroom for the assessment and advancement presentation")
	for resolution: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=resolution;root.content_scale_size=resolution;await frames(8)
		var viewport := Rect2(Vector2.ZERO,Vector2(resolution))
		check("long objective and large score keep header visible "+str(resolution),viewport.encloses(held_out.title_panel.get_global_rect()) and viewport.encloses(held_out.settings_button.get_global_rect()))
		check("wrapped progress remains inside the header "+str(resolution),held_out.title_panel.get_global_rect().encloses(held_out.progress_display.metrics.get_global_rect()) and held_out.title_panel.get_global_rect().encloses(held_out.progress_display.activity.get_global_rect()))
		check("initial hint clears the enlarged header "+str(resolution),held_out.hint_panel.get_global_rect().position.y>held_out.title_panel.get_global_rect().end.y)
	held_out.queue_free();await process_frame
	world.set_building_review_mode(true);await frames()
	check("developer bypass changes no score energy or activity count",display.metrics.text=="Energy 10 / 10 · Score 0" and display.activity.text=="Activities: not started")
	root.size=Vector2i(800,600);root.content_scale_size=Vector2i(800,600);await frames(8)
	check("bypass banner and player stats share narrow header without clipping",root.get_visible_rect().encloses(world.hud.title_panel.get_global_rect()) and root.get_visible_rect().encloses(world.hud.developer.banner_panel.get_global_rect()) and root.get_visible_rect().encloses(world.hud.settings_button.get_global_rect()))
	world.set_building_review_mode(false)
	Setup.prepare_arrival(world);await frames()
	check("earned gates and arrival do not imply course completion",display.metrics.text=="Energy 10 / 10 · Score 0" and display.activity.text=="Activities: not started")
	check("classroom computer has a clear approach",Setup.approach_computer(world).is_finite())
	await frames();await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	await frames()
	check("sample course starts through existing adapter",world.sample_course.open())
	await frames()
	check("temporary required set is explicitly labelled sample",display.activity.text=="Sample activities: 0 / 4")
	var first: RefCounted = await answer("guess")
	check("accepted error updates the common HUD from shared state",display.metrics.text=="Energy 9 / 10 · Score 0" and display.meter.value==9 and display.activity.text=="Sample activities: 0 / 4")
	world.orchestrator.submit(first);await frames()
	check("replayed result cannot decrement the visible energy twice",display.metrics.text=="Energy 9 / 10 · Score 0")
	await answer("unknown-choice")
	check("rejected answer does not create visible progress",display.metrics.text=="Energy 9 / 10 · Score 0" and display.activity.text=="Sample activities: 0 / 4")
	for _index: int in range(9): await answer("guess")
	check("zero energy is visible in text and the empty meter",display.metrics.text=="Energy 0 / 10 · Score 0" and display.meter.value==0 and display.metrics.modulate==world.hud.ERROR)
	world.sample_course._start_recovery();await frames();world.sample_course._confirm_recovery();await frames()
	check("verified recovery refills without awarding progress",display.metrics.text=="Energy 10 / 10 · Score 0" and display.activity.text=="Sample activities: 0 / 4")
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://developer/course/sample-course.json"))
	var count: int = 0
	for step: Dictionary in definition.steps:
		await answer(step.correct_id);count+=1
		check("validated activity updates displayed count "+step.id,display.activity.text.begins_with("Sample activities: %d / %d"%[count,definition.steps.size()]) and display.meter.value==world.orchestrator.snapshot().course.energy)
	check("verified sample set remains distinct from real ending",display.activity.text=="Sample activities: 4 / 4 · Complete" and display.metrics.text=="Energy 10 / 10 · Score 60" and world.orchestrator.snapshot().stage=="ending_pending")
	world.sample_course.close();world.go_location(0);await frames()
	check("closing panel and travelling preserve player-facing results",display.is_visible_in_tree() and display.activity.text=="Sample activities: 4 / 4 · Complete" and display.metrics.text=="Energy 10 / 10 · Score 60")
	world.set_menu_open(true);await frames();world.set_menu_open(false);await frames()
	check("Settings preserves shared display and no provider was used",display.metrics.text=="Energy 10 / 10 · Score 60" and world.npc_conversations.requests_started==0)
	world.queue_free();await process_frame
	world=load("res://Main.tscn").instantiate();world.enable_developer_tools=false;root.add_child(world);await frames(12)
	check("new player-only world has fresh HUD without developer dependency",world.hud.developer==null and world.sample_course==null and world.hud.progress_display.metrics.text=="Energy 10 / 10 · Score 0" and world.hud.progress_display.activity.text=="Activities: not started")
	world.queue_free();await process_frame
	print("PROGRESS_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
