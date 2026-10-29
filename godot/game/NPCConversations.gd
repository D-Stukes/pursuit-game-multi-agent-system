extends Node3D
## One event coordinator owns social turns; animation culling never owns AI state.
const State = preload("res://game/NPCConversationState.gd")
const DialoguePanel = preload("res://game/NPCDialoguePanel.gd")
const ServiceClient = preload("res://game/NPCServiceClient.gd")
const INTERACTION_RADIUS: float = 2.1
var world: Node3D
var state: RefCounted = State.new()
var dialogue: Control
var actors: Array[Dictionary] = []
var active_npc: String = ""
var pending: Dictionary = {}
var request_serial: int = 0
var generation: int = 0
var refresh_remaining: float = 0
var selected: Dictionary = {}
var room_was_inside: bool = false
var cooldown: float = 0
var ambient_active: bool = false
var ambient_index: int = 0
var ambient_remaining: float = 0
var ambient_previous: String = ""
var ambient_lines_shown: int = 0
var caption: PanelContainer
var caption_speaker: Label
var caption_text: Label
var client: Node
var requests_started: int = 0
var last_usage: Dictionary = {}

func _ready() -> void:
	client = ServiceClient.new()
	add_child(client)
	client.completed.connect(_service_result)
	client.failed.connect(_service_failed)
	dialogue = DialoguePanel.new()
	dialogue.theme_source = world.hud
	dialogue.topics = state.data.topics
	world.hud.add_child(dialogue)
	dialogue.closed.connect(_conversation_closed)
	dialogue.topic_requested.connect(_on_topic)
	caption = PanelContainer.new()
	caption.add_theme_stylebox_override("panel",world.hud._panel_style())
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(caption)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_child(column)
	caption_speaker = world.hud._label("",14)
	column.add_child(caption_speaker)
	caption_text = world.hud._label("",18)
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption_text)
	caption.hide()
	caption.resized.connect(func(): caption.position = Vector2(16,world.hud.size.y-caption.size.y-62))
	world.hud.resized.connect(_fit_caption)
	_fit_caption()
	if world.population == null: return
	for npc_id: String in state.data.profiles:
		var actor_id: String = state.data.profiles[npc_id].get("actor",npc_id)
		var actor: Node3D = world.population.get_node_or_null(NodePath(actor_id))
		if actor == null: continue
		var label := Label3D.new()
		label.name = "TalkPrompt" + npc_id
		label.text = "E\nAsk Builder" if state.is_builder(npc_id) else "E\nTalk"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.pixel_size = .0028
		label.outline_size = 8
		label.visible = false
		add_child(label)
		label.global_position = actor.global_position + Vector3.UP * 2.05
		actors.append({"id":npc_id,"actor":actor,"label":label})

func _fit_caption() -> void:
	caption.size.x = minf(600,world.hud.size.x-32)
	caption_text.custom_minimum_size.x = caption.size.x-32
	caption.reset_size()
	caption.position = Vector2(16,world.hud.size.y-caption.size.y-62)

func can_operate() -> bool:
	return world.ready_for_test and not world.hud.menu_open and not world.entrance_puzzle.visible and not world.elevator_game.visible and not world.lift_in_progress and not world.computer_portal.inside and not world.computer_portal.transitioning

func in_room() -> bool:
	var p: Vector3 = world.player.global_position
	var bounds: Array = state.data.room.bounds
	return absf(p.y-float(state.data.room.floor))<.5 and p.x>bounds[0] and p.x<bounds[1] and p.z>bounds[2] and p.z<bounds[3]

func within_area(npc_id: String) -> bool:
	if not state.is_builder(npc_id): return in_room()
	for record: Dictionary in actors:
		if record.id == npc_id:
			return absf(record.actor.global_position.y-world.player.global_position.y)<.5 and record.actor.global_position.distance_to(world.player.global_position)<INTERACTION_RADIUS+.3
	return false

func reachable_npc() -> Dictionary:
	if not can_operate() or dialogue.visible: return {}
	var facing: Vector3 = -world.player.camera_pivot.global_basis.z
	facing.y = 0
	facing = facing.normalized()
	var best: Dictionary = {}
	var best_score: float = INF
	for record: Dictionary in actors:
		if not within_area(record.id): continue
		var delta: Vector3 = record.actor.global_position-world.player.global_position
		if absf(delta.y)>.5: continue
		delta.y = 0
		if delta.length()>INTERACTION_RADIUS or facing.dot(delta.normalized())<.3: continue
		var destination: Vector3 = record.actor.global_position+Vector3.UP*1.2
		var ray := PhysicsRayQueryParameters3D.create(world.player.global_position+Vector3.UP*1.2,destination,1|8)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=record.actor: continue
		var score: float = delta.length_squared()+4.0*(1.0-facing.dot(delta.normalized()))
		if score<best_score:
			best = record
			best_score = score
	return best

func try_talk() -> bool:
	if not can_operate() or dialogue.visible: return false
	var record: Dictionary = reachable_npc()
	if record.is_empty(): return false
	if not world.orchestrator.claim("npc"): return false
	_cancel_pending()
	_stop_ambient()
	active_npc = record.id
	world.player.set_controls_locked(true)
	world.hud.hint_panel.hide()
	world.hud.hint_timer.stop()
	dialogue.open_for(state.data.profiles[active_npc].label,state.greeting(active_npc),state.topics_for(active_npc))
	state.met_npcs[active_npc] = true
	return true

func _conversation_closed() -> void:
	world.orchestrator.release("npc")
	_cancel_pending()
	active_npc = ""
	world.player.set_controls_locked(world.hud.menu_open or world.lift_in_progress or world.entrance_puzzle.visible or world.elevator_game.visible or world.computer_portal.transitioning)

func interrupt() -> void:
	_cancel_pending()
	_stop_ambient()
	if dialogue.visible: dialogue.close()
	selected = {}
	for record: Dictionary in actors: record.label.hide()

func _cancel_pending() -> void:
	generation += 1
	pending = {}
	if client != null: client.cancel()

func _on_topic(topic: String) -> void:
	if not pending.is_empty() or active_npc.is_empty() or not dialogue.visible or topic not in state.topics_for(active_npc): return
	dialogue.set_waiting(true)
	_request(active_npc,topic,false)

func _request(npc_id: String, topic: String, ambient: bool) -> void:
	request_serial += 1
	var snapshot: Dictionary = world.orchestrator.builder_world_snapshot() if state.is_builder(npc_id) else world.orchestrator.npc_world_snapshot()
	var body: Dictionary = state.payload(npc_id,topic,"npc-%d"%request_serial,snapshot,ambient_previous if ambient else "")
	pending = {"body":body,"ambient":ambient,"generation":generation}
	if state.is_builder(npc_id) and client.provider == "claude" and not ambient:
		if client.start(body) != OK: call_deferred("_service_failed",str(body.request_id),"service_unavailable")
		else: requests_started += 1
	else:
		call_deferred("_local_result",body,generation)

func _service_result(request_id: String, result: Dictionary) -> void:
	if pending.is_empty() or pending.body.request_id != request_id: return
	if not accept_reply(result): _service_failed(request_id,"invalid_response")

func _service_failed(request_id: String, _reason: String) -> void:
	if pending.is_empty() or pending.body.request_id != request_id: return
	var body: Dictionary = pending.body
	accept_reply({"schema":body.schema,"request_id":body.request_id,"npc_id":body.npc_id,"topic":body.topic,
		"text":state.local_reply(body.npc_id,body.topic,body.world),"mode":"local"},true)

func _local_result(body: Dictionary, token: int) -> void:
	if token!=generation or pending.is_empty() or pending.body.request_id!=body.request_id: return
	accept_reply({"schema":body.schema,"request_id":body.request_id,"npc_id":body.npc_id,"topic":body.topic,
		"text":state.local_reply(body.npc_id,body.topic,body.world),"mode":"local" if state.is_builder(body.npc_id) else "scripted"})

func valid_builder_usage(result: Dictionary, topic: String) -> bool:
	var usage: Variant = result.get("usage")
	var tools: Variant = result.get("tools_used")
	if not usage is Dictionary or usage.size()!=4 or not tools is Array or tools.size()>4: return false
	for field: String in ["model_calls","tool_calls","input_tokens","output_tokens"]:
		var value: Variant = usage.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or float(value)<0: return false
	if usage.model_calls<1 or usage.model_calls>3 or usage.tool_calls>4 or usage.tool_calls<tools.size() or usage.input_tokens>10000000 or usage.output_tokens>540: return false
	for tool: Variant in tools:
		if tool not in ["read_current_objective","inspect_current_challenge","get_approved_hint","recall_my_conversation"]: return false
	return "read_current_objective" in tools and (topic=="next" or "get_approved_hint" in tools)

func accept_reply(result: Dictionary, fallback: bool = false) -> bool:
	if pending.is_empty() or not can_operate() or not within_area(pending.body.npc_id): return false
	var body: Dictionary = pending.body
	if state.is_builder(body.npc_id) and body.world!=world.orchestrator.builder_world_snapshot():
		_cancel_pending();dialogue.set_waiting(false);dialogue.status.text="Game state changed. Ask again."
		return false
	if result.get("schema")!=body.schema or result.get("request_id")!=body.request_id or result.get("npc_id")!=body.npc_id or result.get("topic")!=body.topic: return false
	if result.get("mode") not in ["local","claude","scripted"] or not result.get("text") is String or result.text.strip_edges().is_empty() or result.text.length()>600: return false
	if state.is_builder(body.npc_id) and result.mode=="claude":
		if not valid_builder_usage(result,body.topic): return false
		last_usage=result.usage.duplicate(true)
	var ambient: bool = pending.ambient
	if ambient and not ambient_active: return false
	if not ambient and (not dialogue.visible or active_npc!=body.npc_id): return false
	pending = {}
	state.remember(body.npc_id,body.topic,result.text)
	if ambient:
		ambient_previous = result.text
		ambient_index += 1
		ambient_lines_shown += 1
		ambient_remaining = float(state.data.room.line_seconds)
		caption_speaker.text = state.data.profiles[body.npc_id].label + " · Scripted"
		caption_text.text = result.text
		caption.show()
		_fit_caption()
	else:
		dialogue.present_reply(result.text,result.mode,fallback)
	return true

func _stop_ambient() -> void:
	ambient_active = false
	caption.hide()
	ambient_previous = ""

func update(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	var inside: bool = in_room()
	if not can_operate() or (dialogue.visible and not within_area(active_npc)):
		if dialogue.visible or ambient_active or not pending.is_empty(): interrupt()
	elif dialogue.visible:
		pass
	elif inside:
		var contacted: bool = state.met_npcs.has("ReceptionA") and state.met_npcs.has("ReceptionB")
		if not room_was_inside and cooldown<=0 and contacted:
			ambient_active = true
			ambient_index = 0
			ambient_remaining = .6
			cooldown = float(state.data.room.ambient_cooldown)
		if ambient_active:
			ambient_remaining -= delta
			if ambient_remaining<=0 and pending.is_empty():
				if ambient_index>=state.data.room.ambient_speakers.size(): _stop_ambient()
				else: _request(state.data.room.ambient_speakers[ambient_index],"ambient",true)
	elif ambient_active:
		_stop_ambient()
		if pending.get("ambient",false): _cancel_pending()
	room_was_inside = inside
	refresh_remaining -= delta
	if refresh_remaining>0: return
	refresh_remaining = .15
	selected = reachable_npc()
	for record: Dictionary in actors:
		record.label.global_position = record.actor.global_position+Vector3.UP*2.05
		record.label.visible = can_operate() and not dialogue.visible and (state.is_builder(record.id) or inside) and absf(record.actor.global_position.y-world.player.global_position.y)<.5 and record.actor.global_position.distance_to(world.player.global_position)<5.0
		record.label.modulate = Color(.21,.88,1) if record==selected else Color(.90,.92,1)

func context_prompt() -> String:
	return "E: talk to " + str(state.data.profiles[selected.id].label) if not selected.is_empty() and can_operate() and not dialogue.visible else ""
