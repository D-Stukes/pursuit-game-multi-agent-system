extends Node
## Reception interaction and simulated avatar photo; no camera, service or disk.
signal classroom_requested
const Rules = preload("res://game/CheckInState.gd")
const Event = preload("res://game/SessionEvent.gd")
var world: Node3D
var state: RefCounted
var computer: Dictionary
var overlay: ColorRect
var panel: PanelContainer
var heading: Label
var message: Label
var name_input: LineEdit
var portrait: TextureRect
var notice: Label
var primary: Button
var close_button: Button
var photo_viewport: SubViewport
var is_open: bool = false
var photo_remaining: float = 0

func _ready() -> void:
	for device: Dictionary in world.computer_portal.computers:
		if device.id == "Reception_monitor": computer = device
	assert(not computer.is_empty(), "Reception check-in computer is missing")
	_build_ui()

func targets(device: Dictionary) -> bool:
	return not device.is_empty() and device.id == computer.id and not world.building_review_mode

func try_use(device: Dictionary) -> bool:
	if not targets(device) or is_open or world.hud.menu_open or world.lift_in_progress or world.arrival_busy() or world.npc_conversations.dialogue.visible or world.computer_portal.inside or world.computer_portal.transitioning: return false
	if world.computer_portal.reachable_computer().get("id", "") != computer.id: return false
	if not world.orchestrator.claim("check_in"): return false
	is_open = true
	world.npc_conversations.interrupt()
	world.player.set_controls_locked(true)
	world.hud.hint_panel.hide()
	world.hud.hint_timer.stop()
	name_input.text = world.orchestrator.snapshot().arrival.display_name
	portrait.visible = false
	name_input.visible = not world.orchestrator.checked_in()
	name_input.editable = world.orchestrator.check_in_allowed()
	primary.disabled = not world.orchestrator.check_in_allowed()
	primary.text = "Take photo"
	message.text = "Enter your name to check in. The photo uses your game character."
	notice.text = ""
	if world.orchestrator.checked_in():
		_show_confirmed()
	elif not world.orchestrator.check_in_allowed():
		message.text = "Check-in opens after you finish the entrance puzzle and elevator flight, then arrive upstairs."
	overlay.show()
	_fit()
	if name_input.editable: name_input.grab_focus()
	else: close_button.grab_focus()
	return true

func close() -> void:
	if not is_open: return
	is_open = false
	photo_remaining = 0
	state.cancel(world.orchestrator.checked_in())
	name_input.text = ""
	overlay.hide()
	if photo_viewport != null: photo_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world.orchestrator.release("check_in")
	world.player.set_controls_locked(world.hud.menu_open or world.lift_in_progress or world.arrival_busy())

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = world.hud.NAVY
	overlay.color.a = .65
	world.hud.add_child(overlay)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", world.hud._panel_style())
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	heading = world.hud._label("Check-In Console", 24)
	column.add_child(heading)
	message = world.hud._label("", 18)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Your name"
	name_input.max_length = Rules.MAX_NAME
	name_input.custom_minimum_size.y = 42
	name_input.add_theme_font_size_override("font_size", 18)
	name_input.add_theme_color_override("font_color", world.hud.WHITE)
	for style: String in ["normal", "focus"]:
		var box: StyleBoxFlat = world.hud._panel_style()
		box.border_color = world.hud.CYAN
		box.set_border_width_all(2 if style == "focus" else 1)
		name_input.add_theme_stylebox_override(style, box)
	name_input.text_submitted.connect(func(_value: String): _primary())
	column.add_child(name_input)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 160)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(portrait)
	notice = world.hud._label("", 18)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	primary = world.hud._button("Take photo", true)
	primary.pressed.connect(_primary)
	column.add_child(primary)
	close_button = world.hud._button("Close [Esc]", false)
	close_button.pressed.connect(close)
	column.add_child(close_button)
	panel.resized.connect(_center)
	world.hud.resized.connect(_fit)
	overlay.hide()

func _fit() -> void:
	panel.custom_minimum_size.x = minf(530, world.hud.size.x - 48)
	message.custom_minimum_size.x = panel.custom_minimum_size.x - 32
	notice.custom_minimum_size.x = message.custom_minimum_size.x
	panel.reset_size()
	_center()

func _center() -> void:
	panel.position = (world.hud.size - panel.size) * .5

func _primary() -> void:
	if not is_open or primary.disabled: return
	if world.orchestrator.checked_in():
		close()
		classroom_requested.emit()
		return
	if not world.orchestrator.check_in_allowed(): return
	if state.phase == Rules.Phase.PHOTO:
		if not state.confirm(): return
		var result: Dictionary = world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.CHECK_IN_CONFIRMED))
		if not result.accepted:
			state.cancel()
			notice.text = "Check-in changed. Close and try again."
			primary.disabled = true
			return
		_show_confirmed()
	else:
		if not state.start_photo(name_input.text):
			notice.text = "Enter a name of 1–32 characters."
			name_input.grab_focus()
			return
		name_input.editable = false
		primary.disabled = true
		notice.text = "Smile…"
		_create_portrait()
		photo_remaining = .4
	_fit()

func _show_confirmed() -> void:
	name_input.hide()
	portrait.hide()
	message.text = "Welcome, %s. You’re checked in." % world.orchestrator.snapshot().arrival.display_name
	notice.text = "Your classroom is through the double doors beside the desk."
	primary.text = "Continue to classroom"
	primary.disabled = false
	primary.grab_focus()
	_fit()

func _create_portrait() -> void:
	if photo_viewport != null: photo_viewport.queue_free()
	photo_viewport = SubViewport.new()
	photo_viewport.size = Vector2i(240, 160)
	photo_viewport.own_world_3d = true
	photo_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(photo_viewport)
	var background := WorldEnvironment.new()
	background.environment = Environment.new()
	background.environment.background_mode = Environment.BG_COLOR
	background.environment.background_color = world.hud.NAVY
	background.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	background.environment.ambient_light_color = Color.WHITE
	background.environment.ambient_light_energy = .8
	photo_viewport.add_child(background)
	var avatar: Node3D = world.player.visual.duplicate()
	avatar.position = Vector3.ZERO
	avatar.rotation = Vector3.ZERO
	avatar.visible = true
	avatar.process_mode = Node.PROCESS_MODE_DISABLED
	photo_viewport.add_child(avatar)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	photo_viewport.add_child(light)
	var camera := Camera3D.new()
	photo_viewport.add_child(camera)
	camera.position = Vector3(0, 1.4, -2.3)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.fov = 35
	portrait.texture = photo_viewport.get_texture()
	portrait.show()

func _process(delta: float) -> void:
	if not is_open or photo_remaining <= 0: return
	photo_remaining -= delta
	if photo_remaining > 0: return
	if not state.take_photo(): return
	photo_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	message.text = "Your in-game photo is ready. Confirm to finish checking in."
	notice.text = "Name: " + state.display_name
	primary.text = "Confirm check-in"
	primary.disabled = false
	primary.grab_focus()
	_fit()
