extends Node3D
## All computer bodies share one distance/visibility interaction and one room.
signal transition_finished(inside: bool)
const INTERACTION_RADIUS: float = 1.8
const LABEL_DISTANCE: float = 10.0
var world: Node3D
@onready var room: Node3D = $PurpleRoom
var computers: Array[Dictionary] = []
var active_computer: Dictionary = {}
var inside: bool = false
var transitioning: bool = false
var return_position: Vector3
var return_heading: float = 0.0
var return_pitch: float = -.2
var return_zoom: float = 3.0
var previous_environment: Environment
var refresh_remaining: float = 0.0

func _ready() -> void:
	for mesh: MeshInstance3D in world.get_node("Building").find_children("*", "MeshInstance3D", true, false):
		var key: String = str(mesh.name).to_lower()
		# Register display bodies once, not their stands, bases, TVs or projector.
		if not (key.contains("generic laptop screen") or key.ends_with("facilitator laptop") or key.contains("monitor body ") or key == "reception_monitor"):
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		var label := Label3D.new()
		label.name = "ComputerPrompt%02d" % computers.size()
		label.text = "E\nUse computer"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = .0028
		label.font_size = 36
		label.outline_size = 8
		label.visibility_range_end = LABEL_DISTANCE
		label.modulate = Color(.90,.92,1)
		label.visible = false
		add_child(label)
		label.global_position = box.get_center() + Vector3.UP*1.0
		computers.append({"id":str(mesh.name), "node":mesh, "point":box.get_center(), "label":label,
			"floor":float(world.approved_layout.manifest.levels.upper)})
	assert(not computers.is_empty(), "No computer interaction bodies found")

func busy() -> bool:
	return transitioning or world.lift_in_progress or world.hud.menu_open or world.entrance_puzzle.visible or world.elevator_game.visible or world.arrival_busy() or (world.npc_conversations != null and world.npc_conversations.dialogue.visible)

func reachable_computer() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for computer: Dictionary in computers:
		if absf(world.player.global_position.y-float(computer.floor)) > .4: continue
		var delta: Vector3 = computer.point-world.player.global_position
		delta.y = 0
		if delta.length_squared() <= INTERACTION_RADIUS*INTERACTION_RADIUS: candidates.append(computer)
	var facing: Vector3 = -world.player.camera_pivot.global_basis.z
	facing.y = 0
	facing = facing.normalized()
	var feet: Vector3 = world.player.global_position
	# Camera alignment disambiguates adjacent screens, then proximity breaks ties.
	candidates.sort_custom(func(a: Dictionary,b: Dictionary):
		var da: Vector3 = a.point-feet; da.y = 0
		var db: Vector3 = b.point-feet; db.y = 0
		return da.length_squared()+4.0*(1.0-facing.dot(da.normalized())) < db.length_squared()+4.0*(1.0-facing.dot(db.normalized())))
	for computer: Dictionary in candidates:
		var ray := PhysicsRayQueryParameters3D.create(world.player.global_position+Vector3.UP*1.25,computer.point,1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		# Hitting the selected screen itself is expected; a nearer wall blocks use.
		if hit.is_empty() or hit.position.distance_to(computer.point) < .16: return computer
	return {}

func near_return() -> bool:
	return inside and world.player.global_position.distance_to(room.return_point.global_position) <= 1.65

func update_prompts(delta: float) -> void:
	refresh_remaining -= delta
	if refresh_remaining > 0: return
	refresh_remaining = .12
	active_computer = {} if inside or busy() else reachable_computer()
	for computer: Dictionary in computers:
		var same_floor: bool = absf(world.player.global_position.y-float(computer.floor)) < .8
		computer.label.visible = not inside and not transitioning and not world.arrival_busy() and same_floor and computer.point.distance_to(world.player.global_position) < LABEL_DISTANCE
		computer.label.modulate = Color(.21,.88,1) if computer == active_computer else Color(.90,.92,1)
	room.return_prompt.text = "E · Return to\ncomputer" if near_return() else "Return to\ncomputer"

func context_prompt() -> String:
	if busy(): return ""
	if near_return(): return "E: return to computer"
	if inside: return "Return to your computer at the marked floor pad"
	return "E: use computer" if not active_computer.is_empty() else ""

func try_use() -> bool:
	if busy(): return false
	if inside:
		if not near_return(): return false
		_travel(false)
		return true
	var computer: Dictionary = reachable_computer()
	if computer.is_empty(): return false
	if not world.orchestrator.claim("portal"): return false
	_travel(true)
	return true

func _travel(entering: bool) -> void:
	transitioning = true
	if entering:
		return_position = world.player.global_position
		return_heading = world.player.camera_pivot.rotation.y
		return_pitch = world.player.camera_pivot.rotation.x
		return_zoom = world.player.spring_arm.spring_length
		previous_environment = world.player.camera.environment
	world.player.set_controls_locked(true)
	world.hud.hint_panel.hide()
	world.hud.hint_timer.stop()
	world.hud.travel_label.text = "Mr. P’s purple room" if entering else "Returning to your computer"
	world.hud.travel_overlay.show()
	world.hud.set_travel_opacity(0)
	var fade_in := create_tween()
	fade_in.tween_method(world.hud.set_travel_opacity,0.0,1.0,.25)
	await fade_in.finished
	# Render a fully opaque frame before changing scene visibility or position.
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	inside = entering
	room.set_active(entering)
	world.player.camera.environment = room.room_environment if entering else previous_environment
	if entering:
		world.player.teleport_to(room.spawn.global_position)
	else:
		world.player.teleport_to(return_position,return_heading)
		world.player.camera_pivot.rotation.x = return_pitch
		world.player.spring_arm.spring_length = return_zoom
	await get_tree().create_timer(.12).timeout
	var fade_out := create_tween()
	fade_out.tween_method(world.hud.set_travel_opacity,1.0,0.0,.3)
	await fade_out.finished
	world.hud.travel_overlay.hide()
	transitioning = false
	if not inside: world.orchestrator.release("portal")
	world.player.set_controls_locked(world.hud.menu_open)
	refresh_remaining = 0
	update_prompts(0)
	transition_finished.emit(inside)

func leave_for_developer_travel() -> void:
	if not inside: return
	world.orchestrator.release("portal")
	inside = false
	room.set_active(false)
	world.player.camera.environment = previous_environment
	world.player.spring_arm.spring_length = return_zoom
	refresh_remaining = 0

func reset_in_room() -> bool:
	if not inside or transitioning: return false
	world.player.teleport_to(room.spawn.global_position)
	return true
