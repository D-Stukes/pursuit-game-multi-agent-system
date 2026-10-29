extends RefCounted
## Provisional authored-data adapter. Only the Orchestrator publishes progress.
## No provider calls, Mr. P persona, model assets or real robot-game behavior.
const DEFAULTS: Dictionary = {"starting_energy":10,"maximum_energy":10,"incorrect_cost":1,"question_energy":1,"challenge_energy":3,"question_score":10,"challenge_score":30}
var error: String = ""
var _definition: Dictionary = {}
var _settings: Dictionary = DEFAULTS.duplicate(true)
var _recovery_phase: int = 0
var _recovery_revision: int = -1
var _recovery_id: String = ""

func _init(definition: Dictionary, settings: Dictionary = {}) -> void:
	_definition = definition.duplicate(true)
	for key: String in settings:
		if not DEFAULTS.has(key) or not (settings[key] is int or settings[key] is float) or not is_finite(float(settings[key])) or float(settings[key]) != floorf(float(settings[key])) or float(settings[key])<0:
			error = "invalid_settings"; return
		_settings[key] = int(settings[key])
	if _settings.maximum_energy<1 or _settings.starting_energy>_settings.maximum_energy or _settings.incorrect_cost<1:
		error = "invalid_settings"; return
	error = _validate()

func _identifier(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length()>80: return false
	var pattern := RegEx.new(); pattern.compile("^[A-Za-z0-9_.:-]+$")
	return pattern.search(value) != null

func _validate() -> String:
	if not _identifier(_definition.get("id")) or not _definition.get("sample") is bool: return "invalid_definition"
	var steps: Variant = _definition.get("steps")
	if not steps is Array or steps.is_empty() or steps.size()>64: return "invalid_steps"
	var seen: Array[String] = []
	for value: Variant in steps:
		if not value is Dictionary: return "invalid_activity"
		var step: Dictionary = value
		if not _identifier(step.get("id")) or step.id in seen or step.get("kind","") not in ["question","challenge"]: return "invalid_activity"
		seen.append(step.id)
		for key: String in ["prompt","rephrase","hint","explanation"]:
			if not step.get(key) is String or step[key].strip_edges().is_empty() or step[key].length()>700: return "invalid_activity_text"
		var choices: Variant = step.get("choices")
		if not choices is Array or choices.size()<2 or choices.size()>6: return "invalid_choices"
		var ids: Array[String] = []
		for choice: Variant in choices:
			if not choice is Dictionary or not _identifier(choice.get("id")) or choice.id in ids: return "invalid_choices"
			if not choice.get("text") is String or choice.text.strip_edges().is_empty() or choice.text.length()>240: return "invalid_choices"
			ids.append(choice.id)
		if not step.get("correct_id") in ids: return "invalid_answer_key"
	return ""

func valid() -> bool: return error.is_empty()
func is_sample() -> bool: return bool(_definition.get("sample",false))
func fingerprint() -> String: return JSON.stringify([_definition,_settings]).sha256_text()

func initial_course() -> Dictionary:
	if not valid(): return {}
	var questions: Array[String] = []
	var challenges: Array[String] = []
	for step: Dictionary in _definition.steps:
		if step.kind == "question": questions.append(step.id)
		else: challenges.append(step.id)
	return {"energy":_settings.starting_energy,"maximum_energy":_settings.maximum_energy,"score":0,
		"question_id":_definition.steps[0].id,"attempts":0,"robot_parts":[],"index":0,
		"mode":"sample" if is_sample() else "authored","package_id":_definition.id,"revision":0,
		"completed_questions":[],"completed_challenges":[],"required_questions":questions,
		"required_challenges":challenges,"help_available":false,"complete":false,
		"last_result":"","feedback":""}

func activity(course: Dictionary) -> Dictionary:
	if not valid() or course.get("package_id","") != _definition.id or course.get("complete",false): return {}
	var index: int = int(course.get("index",-1))
	if index<0 or index>=_definition.steps.size(): return {}
	var result: Dictionary = _definition.steps[index].duplicate(true)
	result.erase("correct_id")
	return result

func _reject(reason: String) -> Dictionary: return {"accepted":false,"reason":reason}

func _context(course: Dictionary, payload: Dictionary, keys: Array[String]) -> String:
	if not valid() or course.get("package_id","") != _definition.id: return "wrong_course"
	if course.get("complete",false): return "course_complete"
	if payload.size()!=keys.size(): return "invalid_payload"
	for key: String in keys:
		if not payload.has(key): return "invalid_payload"
	if not payload.expected_revision is int or payload.expected_revision != course.revision: return "stale_course"
	return ""

func answer(course: Dictionary, payload: Dictionary) -> Dictionary:
	var invalid: String = _context(course,payload,["question_id","answer_id","expected_revision"])
	if not invalid.is_empty(): return _reject(invalid)
	var index: int = int(course.index)
	if index<0 or index>=_definition.steps.size(): return _reject("invalid_course_index")
	var step: Dictionary = _definition.steps[index]
	if payload.question_id != step.id or course.question_id != step.id: return _reject("wrong_question")
	if not payload.answer_id is String or not step.choices.any(func(choice: Dictionary): return choice.id == payload.answer_id): return _reject("invalid_answer")
	if course.energy<=0: return _reject("recovery_required")
	var next: Dictionary = course.duplicate(true)
	next.revision += 1
	if payload.answer_id != step.correct_id:
		next.energy = maxi(0,int(next.energy)-int(_settings.incorrect_cost))
		next.attempts += 1
		next.help_available = next.attempts>=2
		next.last_result = "retry"
		next.feedback = step.rephrase if next.attempts==1 else "Stronger sample help is available. You can keep trying or open the hint."
	else:
		var challenge: bool = step.kind == "challenge"
		var completed: Array = next.completed_challenges if challenge else next.completed_questions
		if step.id in completed: return _reject("already_completed")
		completed.append(step.id)
		next.score += int(_settings.challenge_score if challenge else _settings.question_score)
		next.energy = mini(int(next.maximum_energy),int(next.energy)+int(_settings.challenge_energy if challenge else _settings.question_energy))
		next.index += 1
		next.attempts = 0
		next.help_available = false
		next.last_result = "challenge_complete" if challenge else "question_complete"
		next.feedback = step.explanation
		next.complete = next.index == _definition.steps.size() and next.completed_questions.size()==next.required_questions.size() and next.completed_challenges.size()==next.required_challenges.size()
		next.question_id = "" if next.complete else _definition.steps[next.index].id
	return {"accepted":true,"reason":"verified","course":next,"result":next.last_result}

func begin_recovery(course: Dictionary) -> String:
	if not valid() or course.get("package_id","") != _definition.id or course.get("complete",false) or course.energy!=0: return ""
	_recovery_revision = int(course.revision); _recovery_phase = 1
	_recovery_id = Crypto.new().generate_random_bytes(16).hex_encode()
	return _recovery_id

func present_recovery(course: Dictionary, id: String) -> bool:
	if _recovery_phase!=1 or _recovery_revision!=course.revision or course.energy!=0 or id!=_recovery_id: return false
	_recovery_phase = 2; return true

func confirm_recovery(course: Dictionary, id: String) -> bool:
	if _recovery_phase!=2 or _recovery_revision!=course.revision or course.energy!=0 or id!=_recovery_id: return false
	_recovery_phase = 3; return true

func cancel_recovery() -> void:
	_recovery_phase = 0; _recovery_revision = -1; _recovery_id = ""

func recover(course: Dictionary, payload: Dictionary) -> Dictionary:
	var invalid: String = _context(course,payload,["expected_revision","recovery_id"])
	if not invalid.is_empty(): return _reject(invalid)
	if course.energy!=0: return _reject("recovery_not_needed")
	if _recovery_phase!=3 or _recovery_revision!=course.revision or payload.recovery_id!=_recovery_id: return _reject("recovery_incomplete")
	var next: Dictionary = course.duplicate(true)
	next.energy = next.maximum_energy
	next.revision += 1
	next.last_result = "recovery_complete"
	next.feedback = "Sample recovery complete. Return to the same unanswered task."
	return {"accepted":true,"reason":"verified","course":next,"result":"recovery_complete"}
