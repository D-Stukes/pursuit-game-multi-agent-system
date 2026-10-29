extends Node
## Short local arrival/presentation. Mr. P has no dependency on this controller.
signal finished(completed: bool)
const Event = preload("res://game/SessionEvent.gd")
const WALK_SPEED: float = 2.2
const BEAT_SECONDS: Dictionary = {"stand_up":3.2, "crowd":2.0, "get_to_work":4.0}
var world: Node3D
var state: RefCounted
var active: bool = false
var phase: String = "idle"
var elapsed: float = 0
var was_in_classroom: bool = false
var transfer: bool = false
var destination: Vector3
var caption: PanelContainer
var speaker: Label
var line: Label
var manager: Node3D
var manager_heading: float = 0
var crowd: AudioStreamPlayer
var presentation_camera: Camera3D

func _ready() -> void:
	if world.population != null: manager = world.population.get_node_or_null("ClassroomTeaching")
	caption = PanelContainer.new()
	caption.add_theme_stylebox_override("panel",world.hud._panel_style())
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(caption)
	var column := VBoxContainer.new()
	caption.add_child(column)
	speaker = world.hud._label("Program Manager", 18)
	line = world.hud._label("", 20)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(speaker); column.add_child(line)
	caption.resized.connect(_fit)
	world.hud.resized.connect(_fit)
	caption.hide()
	_fit()
	crowd = AudioStreamPlayer.new()
	crowd.bus = "Effects"
	crowd.volume_db = -14
	add_child(crowd)
	presentation_camera = Camera3D.new()
	presentation_camera.fov = 65
	presentation_camera.near = .05
	add_child(presentation_camera)

func _fit() -> void:
	caption.custom_minimum_size.x = minf(600,world.hud.size.x-32)
	line.custom_minimum_size.x = caption.custom_minimum_size.x-32
	caption.reset_size()
	caption.position = Vector2(16,world.hud.size.y-caption.size.y-62)

func in_classroom() -> bool:
	var point: Vector3 = world.player.global_position
	var door: Vector3 = world.approved_layout.anchor("classroom_door")
	return absf(point.y-door.y)<.4 and point.x> -14.9 and point.x<2.9 and point.z>door.z+.2 and point.z<4.7

func start(from_reception: bool = true) -> bool:
	if active or not world.orchestrator.classroom_allowed() or world.hud.menu_open or world.lift_in_progress or world.computer_portal.inside or world.computer_portal.transitioning: return false
	if not from_reception and not in_classroom(): return false
	world.npc_conversations.interrupt()
	world.check_in.close()
	if not world.orchestrator.claim("classroom"): return false
	state.cancel()
	active = true
	if manager != null: manager_heading = manager.rotation.y
	transfer = from_reception and not in_classroom()
	phase = "fade" if transfer else "stand_up"
	elapsed = 0
	world.player.set_controls_locked(true)
	world.hud.hint_panel.hide(); world.hud.hint_timer.stop()
	if transfer:
		world.hud.travel_label.text = "Entering the classroom"
		world.hud.set_travel_opacity(0)
		world.hud.travel_overlay.show()
	else:
		state.record("entered")
		_present("stand_up")
	return true

func cancel() -> void:
	if not active: return
	active = false
	phase = "idle"
	state.cancel(world.orchestrator.snapshot().arrival.classroom_complete)
	crowd.stop(); caption.hide(); world.hud.travel_overlay.hide()
	if presentation_camera.current: world.player.camera.make_current()
	world.player.scripted_move_speed = 0
	if manager != null:
		manager.rotation.y = manager_heading
		manager.animation.speed_scale = 1
		manager.animation.play("Idle_Neutral",.15)
	world.orchestrator.release("classroom")
	world.player.set_controls_locked(world.hud.menu_open or world.lift_in_progress)
	finished.emit(world.orchestrator.snapshot().arrival.classroom_complete)

func _place_at_entry() -> bool:
	var door: Vector3 = world.approved_layout.anchor("classroom_door")
	var start_point: Vector3 = door + Vector3(0, .03, -.7)
	destination = door + Vector3(0, .03, 1.25)
	var ray := PhysicsRayQueryParameters3D.create(start_point+Vector3.UP*.2,start_point-Vector3.UP*.3,1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.9: return false
	start_point.y = hit.position.y+.015
	destination.y = start_point.y
	var capsule := CapsuleShape3D.new()
	capsule.height = world.player.HEIGHT; capsule.radius = world.player.RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,start_point+Vector3.UP*world.player.HEIGHT*.5)
	query.collision_mask = 1|4|8
	if not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return false
	var transform: Transform3D = world.player.global_transform
	transform.origin = start_point
	if world.player.test_move(transform,destination-start_point): return false
	world.player.global_position = start_point
	world.player.velocity = Vector3.ZERO
	world.player.camera_pivot.rotation = Vector3(-.2,PI,0)
	world.player.visual.rotation.y = PI
	world.player.reset_physics_interpolation()
	return true

func _present(beat: String) -> void:
	phase = beat; elapsed = 0
	speaker.text = "Classroom" if beat == "crowd" else "Program Manager"
	match beat:
		"stand_up":
			line.text = "All right, everybody, time for the daily stand-up."
			if manager != null:
				var toward: Vector3 = manager.global_position-world.player.global_position
				world.player.camera_pivot.rotation.y = atan2(-toward.x,-toward.z)
				world.player.visual.rotation.y = world.player.camera_pivot.rotation.y
				manager.rotation.y = atan2(-toward.x,-toward.z)
				presentation_camera.global_position = manager.global_position+Vector3(0,1.5,2.6)
				presentation_camera.look_at(manager.global_position+Vector3.UP)
				presentation_camera.make_current()
				manager.animation.play("Wave",.15)
		"crowd":
			line.text = "Builders share a quick round of updates."
			if crowd.stream == null: crowd.stream = _crowd_murmur()
			crowd.play()
		"get_to_work":
			line.text = "All right, people, get to work. Find a classroom computer when you’re ready."
			if manager != null: manager.animation.play("Interact",.15)
	caption.show(); _fit()

func _physics_process(delta: float) -> void:
	if not world.ready_for_test: return
	var inside: bool = in_classroom()
	if not active:
		if not inside: was_in_classroom = false
		elif not was_in_classroom and not world.arrival_busy():
			if start(false): was_in_classroom = true
		return
	was_in_classroom = inside
	crowd.stream_paused = world.hud.menu_open
	caption.visible = not world.hud.menu_open and phase in BEAT_SECONDS
	if manager != null: manager.animation.speed_scale = 0 if world.hud.menu_open else 1
	if world.hud.menu_open: return
	if world.building_review_mode or world.computer_portal.inside:
		cancel(); return
	elapsed += delta
	if phase == "fade":
		world.hud.set_travel_opacity(minf(elapsed/.25,1))
		if elapsed>=.3:
			if not _place_at_entry():
				cancel()
				world.hud.hint_label.text = "The classroom entry is blocked. Try again when the doorway is clear."
				world.hud.hint_panel.show(); world.hud.hint_timer.start()
				return
			phase = "reveal"; elapsed = 0
	elif phase == "reveal":
		world.hud.set_travel_opacity(maxf(1-elapsed/.3,0))
		if elapsed>=.3:
			world.hud.travel_overlay.hide()
			phase = "walk"; elapsed = 0
			world.player.scripted_move_speed = WALK_SPEED
	elif phase == "walk":
		var difference: Vector3 = destination-world.player.global_position
		difference.y = 0
		if elapsed>4 or world.player.move_and_collide(difference.normalized()*minf(difference.length(),WALK_SPEED*delta)) != null:
			cancel(); return
		if difference.length()<.04:
			world.player.scripted_move_speed = 0
			state.record("entered")
			_present("stand_up")
	elif elapsed >= float(BEAT_SECONDS[phase]):
		state.record(phase)
		match phase:
			"stand_up": _present("crowd")
			"crowd": _present("get_to_work")
			"get_to_work":
				world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.CLASSROOM_INTRODUCED))
				cancel()

func _crowd_murmur() -> AudioStreamWAV:
	# Quiet synthetic, unintelligible babble. No source speech or recording.
	var samples := PackedByteArray()
	var rate: int = 16000
	samples.resize(rate*2*2)
	var rng := RandomNumberGenerator.new(); rng.seed = 2048
	var noise: float = 0
	for index: int in range(rate*2):
		var t: float = float(index)/rate
		noise = .92*noise+.08*rng.randf_range(-1,1)
		var voices: float = 0
		for voice: int in range(5):
			voices += sin(TAU*(112+voice*37)*t)*( .5+.5*sin(TAU*(2.1+voice*.3)*t+voice))
		var envelope: float = minf(t/.15,1)*minf((2-t)/.2,1)
		var sample: int = clampi(int((voices*.055+noise*.5)*envelope*32767),-32768,32767)
		samples[index*2] = sample & 255
		samples[index*2+1] = (sample >> 8) & 255
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = samples
	return sound
