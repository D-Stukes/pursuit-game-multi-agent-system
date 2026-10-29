extends Node
## Explicit developer fixture UI. It neither implements nor calls Lady D's Mr. P.
const Rules = preload("res://game/CourseAdapter.gd")
const Event = preload("res://game/SessionEvent.gd")
const DATA: String = "res://developer/course/sample-course.json"
var world: Node3D
var adapter: RefCounted
var is_open: bool = false
var overlay: ColorRect
var panel: PanelContainer
var column: VBoxContainer
var body: VBoxContainer
var scroll: ScrollContainer
var status: Label
var prompt: Label
var notice: Label
var disclaimer: Label
var answer_box: VBoxContainer
var answers: Array[Button] = []
var help_button: Button
var recovery_button: Button
var recovery_box: VBoxContainer
var recovery_confirm: Button
var recovery_decline: Button
var close_button: Button
var _recovery_open: bool = false
var _recovery_id: String = ""

func _ready() -> void:
	adapter = Rules.new(JSON.parse_string(FileAccess.get_file_as_string(DATA)))
	_build_ui()
	world.hud.resized.connect(_fit)
	_fit()

func available() -> bool:
	if world.hud.developer==null or world.building_review_mode or not world.computer_portal.inside or world.computer_portal.transitioning or world.lift_in_progress: return false
	var state: Dictionary = world.orchestrator.snapshot()
	if state.stage!="mr_p_pending" and state.course.get("mode","")!="sample": return false
	return state.arrival.classroom_complete and state.stage in ["mr_p_pending","course_active","ending_pending"]

func open() -> bool:
	if is_open or not available() or world.hud.menu_open or world.arrival_busy() or world.npc_conversations.dialogue.visible: return false
	world.orchestrator.release("portal")
	if not world.orchestrator.claim("course"): return false
	var result: Dictionary = world.orchestrator.begin_course(adapter)
	if not result.accepted:
		world.orchestrator.release("course");world.orchestrator.claim("portal")
		return false
	is_open = true
	_recovery_open = false
	overlay.show()
	world.hud.hint_panel.hide();world.hud.hint_timer.stop()
	world.player.set_controls_locked(true)
	_sync()
	return true

func close() -> void:
	if not is_open: return
	is_open = false
	_recovery_open = false;_recovery_id = "";adapter.cancel_recovery()
	overlay.hide()
	world.orchestrator.release("course")
	if world.computer_portal.inside: world.orchestrator.claim("portal")
	world.player.set_controls_locked(world.hud.menu_open or world.lift_in_progress or world.arrival_busy())

func _label(text: String, size: int) -> Label:
	var label: Label = world.hud._label(text,size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = world.hud.NAVY;overlay.color.a = .65
	world.hud.add_child(overlay)
	panel = PanelContainer.new();panel.add_theme_stylebox_override("panel",world.hud._panel_style())
	overlay.add_child(panel)
	column = VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	column.add_child(_label("SAMPLE COURSE — TEMPORARY",22))
	disclaimer = _label("Sample only. Lady D owns Mr. P and the robot. This connects to the shared ending.",16)
	column.add_child(disclaimer)
	status = _label("",16);column.add_child(status)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	body = VBoxContainer.new();body.add_theme_constant_override("separation",12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	prompt = _label("",18);body.add_child(prompt)
	notice = _label("",16);body.add_child(notice)
	answer_box = VBoxContainer.new();answer_box.add_theme_constant_override("separation",10);body.add_child(answer_box)
	help_button = world.hud._button("Sample hint",false);help_button.pressed.connect(_show_hint);body.add_child(help_button)
	recovery_button = world.hud._button("Dial-a-Friend — sample recovery",true)
	recovery_button.pressed.connect(_start_recovery);body.add_child(recovery_button)
	recovery_box = VBoxContainer.new();recovery_box.add_theme_constant_override("separation",12);body.add_child(recovery_box)
	recovery_box.add_child(_label("SAMPLE FRIEND\nTake a breath. We can break this into one step. Read the hint and return when you're ready. This supportive conversation is a scripted placeholder.",18))
	recovery_confirm = world.hud._button("Ready to try again — finish recovery",true)
	recovery_confirm.pressed.connect(_confirm_recovery);recovery_box.add_child(recovery_confirm)
	recovery_decline = world.hud._button("Not now — keep recovery available",false)
	recovery_decline.pressed.connect(_decline_recovery);recovery_box.add_child(recovery_decline)
	close_button = world.hud._button("Close sample [Esc]",false);close_button.pressed.connect(close);column.add_child(close_button)
	panel.resized.connect(_center)
	# Container minimums settle after visibility/wrapping changes. Refit then,
	# rather than centering a stale expanded minimum above a narrow window.
	panel.minimum_size_changed.connect(func():call_deferred("_fit"))
	recovery_box.hide();recovery_button.hide()
	overlay.hide()

func _fit() -> void:
	panel.custom_minimum_size = Vector2(minf(530,world.hud.size.x-48),minf(610,world.hud.size.y-48))
	panel.size = panel.custom_minimum_size
	var width: float = panel.custom_minimum_size.x-32
	disclaimer.custom_minimum_size.x = width;status.custom_minimum_size.x = width
	for label: Label in [prompt,notice]: label.custom_minimum_size.x = width-16
	for answer: Button in answers:
		answer.custom_minimum_size.y = maxf(42,answer.get_theme_font("font").get_multiline_string_size(answer.text,HORIZONTAL_ALIGNMENT_CENTER,width-48,18).y+20)
	_center()

func _center() -> void: panel.position = (world.hud.size-panel.size)*.5

func _sync() -> void:
	var course: Dictionary = world.orchestrator.snapshot().course
	status.text = "Energy %d / %d · Score %d · Attempts %d\nQuestions %d / %d · Sample checkpoints %d / %d"%[course.energy,course.maximum_energy,course.score,course.attempts,course.completed_questions.size(),course.required_questions.size(),course.completed_challenges.size(),course.required_challenges.size()]
	for child: Node in answer_box.get_children(): answer_box.remove_child(child);child.queue_free()
	answers.clear()
	var step: Dictionary = adapter.activity(course)
	if course.complete:
		prompt.text = "Sample course results verified. Close this panel to return to the classroom for your results and the story ending."
	else:
		prompt.text = str(step.rephrase if course.attempts>0 else step.prompt)
		for choice: Dictionary in step.choices:
			var answer: Button = world.hud._button(choice.text,false)
			answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			answer.set_meta("answer_id",choice.id)
			answer.disabled = course.energy==0 or _recovery_open
			answer.pressed.connect(_answer.bind(step.id,choice.id,int(course.revision)))
			answer_box.add_child(answer);answers.append(answer)
	notice.text = ("Try again: " if course.last_result=="retry" else "Verified: " if course.last_result in ["question_complete","challenge_complete"] else "")+str(course.feedback)
	notice.modulate = world.hud.ERROR if course.last_result=="retry" else world.hud.SUCCESS if course.last_result in ["question_complete","challenge_complete"] else world.hud.WHITE
	help_button.visible = not course.complete and not _recovery_open
	help_button.text = "Stronger sample help" if course.help_available else "Sample hint"
	recovery_button.visible = not course.complete and course.energy==0 and not _recovery_open
	recovery_box.visible = _recovery_open
	# At zero, prioritize the recovery action instead of filling the viewport
	# with choices that cannot be submitted. Recovery gets its own readable view.
	answer_box.visible = not _recovery_open and course.energy>0
	prompt.visible = not _recovery_open
	notice.visible = not _recovery_open
	if course.energy==0 and not _recovery_open: notice.text = "Recovery needed: Energy is zero, so answers are paused. Open sample recovery to refill, or close this panel and return later."
	_fit()
	call_deferred("_fit")
	if course.complete: close_button.grab_focus()
	elif _recovery_open: recovery_decline.grab_focus()
	elif course.energy==0: recovery_button.grab_focus()
	elif not answers.is_empty(): answers[0].grab_focus()
	call_deferred("_show_view_start")

func _show_view_start() -> void:
	# Initial keyboard focus can scroll a wrapped prompt a few pixels out of view.
	# Wait for container/focus layout, then start the new view at its first line.
	await get_tree().process_frame
	if is_open: scroll.scroll_vertical = 0

func _answer(question_id: String, answer_id: String, revision: int) -> void:
	if not is_open or _recovery_open: return
	var result: Dictionary = world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.COURSE_ANSWER_SUBMITTED,{"question_id":question_id,"answer_id":answer_id,"expected_revision":revision}))
	_sync()
	if not result.accepted: notice.text = "That submission no longer matches the current step. Progress was preserved."

func _show_hint() -> void:
	var step: Dictionary = adapter.activity(world.orchestrator.snapshot().course)
	if not is_open or step.is_empty() or _recovery_open: return
	notice.text = "Sample hint: "+str(step.hint)
	notice.modulate = world.hud.CYAN

func _start_recovery() -> void:
	if not is_open: return
	_recovery_id = adapter.begin_recovery(world.orchestrator.snapshot().course)
	if _recovery_id.is_empty(): return
	_recovery_open = true;recovery_confirm.disabled = true
	var id: String = _recovery_id
	_sync()
	await get_tree().process_frame
	if is_open and _recovery_open and id==_recovery_id and recovery_box.is_visible_in_tree() and adapter.present_recovery(world.orchestrator.snapshot().course,id):
		recovery_confirm.disabled = false;recovery_confirm.grab_focus()

func _confirm_recovery() -> void:
	if not is_open or not _recovery_open or not adapter.confirm_recovery(world.orchestrator.snapshot().course,_recovery_id): return
	var result: Dictionary = world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.COURSE_RECOVERY_COMPLETED,{"expected_revision":world.orchestrator.snapshot().course.revision,"recovery_id":_recovery_id}))
	if result.accepted: _recovery_open = false;_recovery_id = ""
	_sync()

func _decline_recovery() -> void:
	adapter.cancel_recovery();_recovery_open = false;_recovery_id = ""
	_sync()
