extends Node3D
## Local movement/camera proof. This does not modify the imported building.

signal lift_finished
signal restart_requested
const RESTART_OPTIONS: StringName = &"pursuit_restart_options"

const PlayerController = preload("res://game/BuildingPlayer.gd")
const GameHUD = preload("res://game/GameHUD.gd")
const ApprovedLayout = preload("res://game/ApprovedLayout.gd")
const EntranceDoors = preload("res://game/EntranceDoors.gd")
const EntrancePuzzle = preload("res://game/EntrancePuzzle.gd")
const ElevatorShooter = preload("res://game/ElevatorShooter.gd")
const Coordinator = preload("res://game/GameOrchestrator.gd")
const SessionEvent = preload("res://game/SessionEvent.gd")
const BUILDING_PATH: String = "res://assets/generated/pursuit-building.glb"
var LOCATIONS: Array[Vector3] = []
const LOCATION_NAMES: Array[String] = ["Street entrance", "Second-floor reception", "Classroom"]
const LOCATION_HEADINGS: Array[float] = [0.0, PI, -PI / 2.0]
var LIFT_GROUND: Vector3
var LIFT_UPPER: Vector3
var UPPER_LIFT_EXIT: Vector3
var LOWER_LIFT_EXIT: Vector3
var LIFT_HEADING: float
const ACTIVE_FPS: int = 60
const BACKGROUND_FPS: int = 15
const LIFT_INTERACTION_RADIUS: float = 2.1

var player: CharacterBody3D
var mesh_count: int = 0
var collision_triangles: int = 0
var last_location: int = 0
var status_label: Label
var hud: Control
var ready_for_test: bool = false
var lift_in_progress: bool = false
var frame_budget_enabled: bool = false
var refresh_building_resources: bool = false
var approved_layout: RefCounted
var entrance_puzzle: Control
var entrance_doors: Node3D
var keypad_approach_armed: bool=true
var entering: bool=false
var stairs_hint_seen: bool=false
var entrance_gate: StaticBody3D
var entrance_keypad: Node3D
var ENTRANCE_POINT: Vector3
var orchestrator: RefCounted
var building_review_mode: bool:
	get: return orchestrator != null and orchestrator.review_enabled()
var classroom_cast: Node3D
@export var include_classroom_cast: bool = true
var population: Node3D
@export var include_population: bool = true
var computer_portal: Node3D
var elevator_game: Control
var npc_conversations: Node3D
var check_in: Node
var classroom_sequence: Node
var sample_course: Node
var intro: Control
var guide: Control
var ending_sequence: Node
@export var auto_play_ending: bool=true
var _hud_progress_revision: int = -1
var _restarting: bool = false
@export var enable_developer_tools: bool=true

func _ready() -> void:
	var restarting: bool=get_tree().root.has_meta(RESTART_OPTIONS)
	if restarting:
		var options: Dictionary=get_tree().root.get_meta(RESTART_OPTIONS)
		get_tree().root.remove_meta(RESTART_OPTIONS)
		enable_developer_tools=options.developer
		include_population=options.population
		include_classroom_cast=options.cast
	frame_budget_enabled = DisplayServer.get_name() != "headless"
	if frame_budget_enabled:
		_apply_frame_budget(get_window().has_focus())
	else:
		# Headless verification should not wait for the interactive frame cap.
		Engine.max_fps = 0
	_build_lighting()
	_build_hud()
	if not ResourceLoader.exists(BUILDING_PATH):
		status_label.text = "Building asset missing. Run python tools/prepare_game.py from the repo root, then import the Godot project."
		push_error(status_label.text)
		return
	# Only the review harness forces a refresh after an asset has been reimported.
	var cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_REPLACE_DEEP if refresh_building_resources else ResourceLoader.CACHE_MODE_REUSE
	var packed: PackedScene = ResourceLoader.load(BUILDING_PATH, "PackedScene", cache_mode)
	var building: Node3D = packed.instantiate()
	building.name = "Building"
	add_child(building)
	if refresh_building_resources:
		# Existing review windows can refresh the assembly without an OS relaunch.
		var layout_script: GDScript = load("res://game/ApprovedLayout.gd")
		layout_script.source_code = FileAccess.get_file_as_string("res://game/ApprovedLayout.gd")
		assert(layout_script.reload(true) == OK)
	approved_layout = ApprovedLayout.new()
	approved_layout.apply(building)
	for id: String in ["street_spawn", "reception_spawn", "classroom_spawn"]:
		LOCATIONS.append(approved_layout.anchor(id))
	ENTRANCE_POINT = approved_layout.anchor("entrance")
	LIFT_GROUND = approved_layout.anchor("lift_ground")
	LIFT_UPPER = approved_layout.anchor("lift_upper")
	UPPER_LIFT_EXIT = approved_layout.anchor("lift_upper_exit")
	LOWER_LIFT_EXIT = approved_layout.anchor("lift_ground_exit")
	LIFT_HEADING = float(approved_layout.manifest.lift_heading_yaw)
	var faces := PackedVector3Array()
	_collect_faces(building, faces)
	var static_body := StaticBody3D.new()
	static_body.name = "BuildingCollision"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	static_body.add_child(collision)
	add_child(static_body)
	collision_triangles = faces.size() / 3
	player = CharacterBody3D.new()
	player.set_script(PlayerController)
	add_child(player)
	player.sit_feedback.connect(hud.show_navigation_hint)
	player.reset_requested.connect(func():
		if computer_portal == null or not computer_portal.reset_in_room(): go_location(last_location))
	if include_classroom_cast:
		classroom_cast = preload("res://scenes/ClassroomCast.tscn").instantiate()
		classroom_cast.world = self
		add_child(classroom_cast)
	if include_population:
		population = preload("res://scenes/BuildingPopulation.tscn").instantiate()
		population.player = player
		population.world = self
		add_child(population)
	_build_entrance()
	_build_elevator_game()
	var check_in_state: RefCounted = preload("res://game/CheckInState.gd").new()
	var classroom_state: RefCounted = preload("res://game/ClassroomState.gd").new()
	orchestrator = Coordinator.new(entrance_puzzle.state,elevator_game.state,hud.developer!=null,check_in_state,classroom_state)
	_refresh_progress_hud()
	_build_street_limits()
	computer_portal = preload("res://scenes/ComputerPortal.tscn").instantiate()
	computer_portal.world = self
	add_child(computer_portal)
	npc_conversations = preload("res://game/NPCConversations.gd").new()
	npc_conversations.world = self
	add_child(npc_conversations)
	check_in = preload("res://game/CheckInConsole.gd").new()
	check_in.world = self
	check_in.state = check_in_state
	add_child(check_in)
	classroom_sequence = preload("res://game/ClassroomSequence.gd").new()
	classroom_sequence.world = self
	classroom_sequence.state = classroom_state
	add_child(classroom_sequence)
	check_in.classroom_requested.connect(func(): classroom_sequence.start())
	classroom_sequence.finished.connect(npc_conversations.classroom_presented)
	if hud.developer != null:
		sample_course = load("res://developer/course/SampleCourse.gd").new()
		sample_course.world = self
		add_child(sample_course)
	ending_sequence=preload("res://game/EndingSequence.gd").new()
	ending_sequence.world=self
	add_child(ending_sequence)
	var intro_layer:=CanvasLayer.new();intro_layer.layer=5;add_child(intro_layer)
	intro=preload("res://game/JourneyIntro.gd").new();intro.world=self;intro_layer.add_child(intro)
	var guide_layer:=CanvasLayer.new();guide_layer.layer=4;add_child(guide_layer)
	guide=preload("res://game/JourneyGuide.gd").new();guide.world=self;guide_layer.add_child(guide)
	guide.close_requested.connect(func():set_menu_open(false))
	set_building_review_mode(not restarting and OS.get_cmdline_user_args().has("--developer-review"))
	go_location(0)
	ready_for_test = true
	print("BUILDING_READY meshes=", mesh_count, " triangles=", collision_triangles)
	if not restarting and not GamePreferences.intro_seen and DisplayServer.get_name()!="headless" and not OS.get_cmdline_args().has("--script"):
		intro.call_deferred("start")

func _notification(what: int) -> void:
	if not frame_budget_enabled:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply_frame_budget(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_apply_frame_budget(false)

func _apply_frame_budget(focused: bool) -> void:
	Engine.max_fps = ACTIVE_FPS if focused else BACKGROUND_FPS

func _collect_faces(node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		mesh_count += 1
		var vertices: PackedVector3Array = node.mesh.get_faces()
		var to_world: Transform3D = node.global_transform
		if not EntranceDoors.is_leaf(node):
			for vertex: Vector3 in vertices:
				faces.append(to_world * vertex)
	for child: Node in node.get_children():
		_collect_faces(child, faces)

func _build_lighting() -> void:
	preload("res://game/EnvironmentLighting.gd").setup(self)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = GameHUD.new()
	hud.developer_tools_allowed=enable_developer_tools
	layer.add_child(hud)
	status_label = hud.floor_label
	hud.menu_requested.connect(set_menu_open)
	hud.restart_confirmed.connect(request_restart)
	hud.replay_intro_requested.connect(func():set_menu_open(false);intro.start())
	hud.bonus_requested.connect(_open_bonus_puzzles)
	hud.guide_requested.connect(open_guide)
	hud.progress_display.pellet_requested.connect(func():orchestrator.use_reserve_pellet())
	if hud.developer != null:
		hud.developer.location_requested.connect(func(index: int): go_location(index); set_menu_open(false))
		hud.developer.review_requested.connect(set_building_review_mode)
		hud.developer.skip_requested.connect(_developer_skip_gate)
		hud.developer.sample_course_requested.connect(_open_sample_course)
		hud.developer.ending_preview_requested.connect(_preview_ending)
		hud.developer.intro_preview_requested.connect(func():set_menu_open(false);intro.start(true))

func _developer_skip_gate(gate: String) -> void:
	if not ready_for_test or lift_in_progress or arrival_busy() or computer_portal.transitioning: return
	if not orchestrator.skip_gate(gate): return
	set_building_review_mode(false)
	set_menu_open(false)
	_refresh_entrance_gate()
	if gate=="entrance" and not orchestrator.gate_passed("elevator"):
		player.teleport_to(LOWER_LIFT_EXIT,LIFT_HEADING)
		# Use the same physical interaction and ownership path as normal play.
		await get_tree().physics_frame
		await get_tree().physics_frame
		try_lift()

func _preview_ending() -> void:
	if ending_sequence==null or ending_sequence.active or lift_in_progress or computer_portal.transitioning: return
	set_menu_open(false)
	ending_sequence.start(true)

func request_restart() -> void:
	if _restarting or not ready_for_test: return
	if not restart_requested.has_connections() and get_tree().current_scene!=self:
		hud.restart_accept.disabled=false
		push_error("Restart requires the main scene or a connected review host")
		return
	_restarting=true
	npc_conversations.interrupt()
	ready_for_test=false
	player.set_controls_locked(true)
	get_tree().root.set_meta(RESTART_OPTIONS,{"developer":enable_developer_tools,"population":include_population,"cast":include_classroom_cast})
	if restart_requested.has_connections():
		restart_requested.emit()
	else:
		call_deferred("_reload_run")

func _reload_run() -> void:
	var result: Error=get_tree().reload_current_scene()
	if result!=OK:
		get_tree().root.remove_meta(RESTART_OPTIONS)
		_restarting=false
		ready_for_test=true
		hud.restart_accept.disabled=false
		push_error("Could not restart run: "+error_string(result))

func _open_sample_course() -> void:
	if sample_course == null or not sample_course.available(): return
	set_menu_open(false)
	sample_course.open()

func set_menu_open(open: bool, developer_view: bool=false) -> void:
	if not ready_for_test or entering or (intro!=null and intro.active) or (computer_portal != null and computer_portal.transitioning):
		return
	if guide!=null:guide.hide()
	if open: hud.set_debug_mode(developer_view)
	if open and entrance_puzzle.visible:
		entrance_puzzle.close()
	if open and elevator_game.visible:
		elevator_game.close()
	if open and npc_conversations != null:
		npc_conversations.interrupt()
	if open and check_in != null: check_in.close()
	if open and sample_course != null: sample_course.close()
	orchestrator.menu(open)
	hud.set_menu_open(open)
	player.set_controls_locked(open or lift_in_progress or entrance_puzzle.visible or elevator_game.visible or arrival_busy())

func arrival_busy() -> bool:
	# All existing modal guards also exclude the developer sample interaction.
	return entering or (intro!=null and intro.active) or (check_in != null and check_in.is_open) or (classroom_sequence != null and classroom_sequence.active) or (sample_course != null and sample_course.is_open) or (ending_sequence!=null and ending_sequence.active)

func _build_elevator_game() -> void:
	elevator_game = ElevatorShooter.new()
	elevator_game.theme_source = hud
	hud.add_child(elevator_game)
	elevator_game.closed.connect(func():
		orchestrator.release("shooter")
		orchestrator.release("replay")
		player.set_controls_locked(hud.menu_open or lift_in_progress))
	elevator_game.victory.connect(_on_shooter_won)
	elevator_game.ride_requested.connect(func():
		# Verify the encounter result; a UI signal alone cannot grant travel.
		if not elevator_game.state.completed() or not orchestrator.ascent_allowed(): return
		_leave_shooter_for_lift())

func _build_entrance() -> void:
	entrance_doors=EntranceDoors.new();add_child(entrance_doors)
	entrance_doors.configure(get_node("Building"))
	collision_triangles+=entrance_doors.triangle_count
	entrance_puzzle = EntrancePuzzle.new()
	entrance_puzzle.theme_source = hud
	hud.add_child(entrance_puzzle)
	entrance_puzzle.closed.connect(func():
		orchestrator.release("entrance")
		orchestrator.release("bonus")
		player.set_controls_locked(hud.menu_open or lift_in_progress))
	entrance_gate = StaticBody3D.new()
	entrance_gate.name = "EntranceLock"
	entrance_gate.collision_layer = 4
	entrance_gate.collision_mask = 0
	entrance_gate.position = ENTRANCE_POINT + Vector3.UP * 1.34
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.63, 2.68, 0.12)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	entrance_gate.add_child(collision)
	add_child(entrance_gate)
	entrance_keypad = preload("res://scenes/EntranceKeypad.tscn").instantiate()
	entrance_keypad.entrance_point = ENTRANCE_POINT
	add_child(entrance_keypad)
	entrance_puzzle.entrance_unlocked.connect(_on_entrance_unlocked)
	entrance_puzzle.skip_requested.connect(_on_entrance_skipped)
	entrance_puzzle.entry_requested.connect(_enter_after_unlock)

func _on_entrance_unlocked() -> void:
	var first: bool=not orchestrator.snapshot().gates.entrance
	if first:
		orchestrator.submit(orchestrator.new_event(SessionEvent.Kind.ENTRANCE_UNLOCKED))
	_refresh_entrance_gate()
	if first and entrance_puzzle.visible and orchestrator.snapshot().gates.entrance: entrance_puzzle.entry_pending=true

## Skip opens the door without a verified solve: no reserve pellet and no earned gate.
func _on_entrance_skipped() -> void:
	if not orchestrator.skip_challenge("entrance"): return
	GameAudio.play("unlock")
	_refresh_entrance_gate()
	_enter_after_unlock()

## Leaving the solved keypad fades out and returns the player centred before the
## open doors, clear of the swinging leaves, instead of beside the keypad.
func _enter_after_unlock() -> void:
	if entering: return
	entering=true;player.set_controls_locked(true)
	var animated: bool=DisplayServer.get_name()!="headless"
	if animated: await _fade_travel(0.0,1.0,.3)
	entrance_puzzle.close()
	go_location(0)
	player.set_controls_locked(true)
	if animated:
		await get_tree().create_timer(.15).timeout
		await _fade_travel(1.0,0.0,.35)
	entering=false;player.set_controls_locked(hud.menu_open or lift_in_progress)
	hud.show_navigation_hint("The entrance is open. Walk in, then take the stairs or the ramp to the elevators.")

func _fade_travel(from: float, to: float, seconds: float) -> void:
	hud.travel_label.text="";hud.travel_overlay.show()
	var fade:=create_tween();fade.tween_method(hud.set_travel_opacity,from,to,seconds)
	await fade.finished
	if to<=0.0: hud.travel_overlay.hide()

## Fade the arcade screen out first so the win does not cut straight into the ride.
func _leave_shooter_for_lift() -> void:
	if DisplayServer.get_name()!="headless":
		elevator_game.primary_button.disabled=true;elevator_game.replay_button.disabled=true
		var fade:=create_tween();fade.tween_property(elevator_game,"modulate:a",0.0,.35)
		await fade.finished
	elevator_game.modulate.a=1.0
	# Esc during the fade already closed the arcade; leaving it closed means no ride.
	if not elevator_game.visible: return
	elevator_game.close()
	try_lift()

## Practice copies of the two gate games; earned gates and rewards are unaffected.
func try_replay() -> bool:
	if lift_in_progress or hud.menu_open or entrance_puzzle.visible or elevator_game.visible or arrival_busy(): return false
	if replay_target()=="entrance":
		if not orchestrator.claim("bonus"): return false
		player.set_controls_locked(true);entrance_puzzle.open();entrance_puzzle.start_replay()
		return true
	if replay_target()=="shooter":
		if not orchestrator.claim("replay"): return false
		player.set_controls_locked(true);elevator_game.open();elevator_game.start_replay()
		return true
	return false

func replay_target() -> String:
	if computer_portal.inside: return ""
	# Only a real earned result can be practised; review access or developer skips offer nothing.
	if entrance_puzzle.state.unlocked and entrance_keypad.nearby(player,1.8) and player.global_position.z>ENTRANCE_POINT.z: return "entrance"
	if elevator_game.state.completed() and not elevator_game.skipped and orchestrator.ascent_allowed() and player.global_position.distance_to(LIFT_GROUND)<LIFT_INTERACTION_RADIUS: return "shooter"
	return ""

func _on_shooter_won() -> void:
	if elevator_game.skipped: orchestrator.skip_challenge("elevator")
	elif not orchestrator.gates_earned():
		orchestrator.submit(orchestrator.new_event(SessionEvent.Kind.SHOOTER_WON))

func _refresh_entrance_gate() -> void:
	var open: bool = orchestrator.entrance_allowed()
	entrance_gate.collision_layer = 0 if open else 4
	entrance_gate.visible = not open
	entrance_keypad.set_open(open)
	entrance_doors.set_open(open)

func _build_street_limits() -> void:
	# These gameplay colliders share the manifest with the visible GLB barricades.
	# They stop step-over/edge bypass without affecting the second-floor interior.
	var limits: Dictionary = approved_layout.manifest.street_review_limits
	for x: float in [float(limits.min_x),float(limits.max_x)]:
		var body := StaticBody3D.new()
		body.name = "StreetReviewBoundaryWest" if x == float(limits.min_x) else "StreetReviewBoundaryEast"
		body.collision_layer = 4
		body.collision_mask = 0
		body.position = Vector3(x,(float(limits.floor)+float(limits.top))*.5,-(float(limits.min_depth)+float(limits.max_depth))*.5)
		var shape := BoxShape3D.new()
		shape.size = Vector3(.16,float(limits.top)-float(limits.floor),float(limits.max_depth)-float(limits.min_depth))
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func set_building_review_mode(enabled: bool) -> void:
	if lift_in_progress or (ending_sequence!=null and ending_sequence.active) or (computer_portal != null and computer_portal.transitioning):
		hud.set_review_mode(building_review_mode)
		return
	if enabled:
		if sample_course != null: sample_course.close()
		if check_in != null: check_in.close()
		if classroom_sequence != null: classroom_sequence.cancel()
	orchestrator.set_review(enabled)
	if building_review_mode and entrance_puzzle.visible:
		entrance_puzzle.close()
	if building_review_mode and elevator_game.visible:
		elevator_game.close()
	_refresh_entrance_gate()
	hud.set_review_mode(building_review_mode)

func try_entrance(automatic: bool=false) -> bool:
	if lift_in_progress or hud.menu_open or entrance_puzzle.visible or elevator_game.visible or arrival_busy():
		return false
	if building_review_mode or orchestrator.entrance_allowed():
		return false
	if not (entrance_keypad.can_approach(player) if automatic else entrance_keypad.can_use(player)):
		return false
	if not orchestrator.claim("entrance"): return false
	player.set_controls_locked(true)
	hud.hint_panel.hide()
	hud.hint_timer.stop()
	keypad_approach_armed=false
	entrance_puzzle.open()
	return true

func can_open_guide() -> bool:
	return guide!=null and ready_for_test and not arrival_busy() and not lift_in_progress and not computer_portal.transitioning and not entrance_puzzle.visible and not elevator_game.visible and not npc_conversations.dialogue.visible and not hud.restart_dialog_open

func open_guide(page: String="Objective") -> void:
	if not can_open_guide():return
	set_menu_open(true)
	hud.menu_overlay.hide();guide.open(page)

func _input(event: InputEvent) -> void:
	if classroom_sequence!=null and classroom_sequence.active and not hud.menu_open and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:
		classroom_sequence.skip();get_viewport().set_input_as_handled();return
	if guide!=null and guide.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE,KEY_B]:set_menu_open(false)
			elif event.keycode==KEY_M:guide.show_page("Map")
			if event.keycode in [KEY_ESCAPE,KEY_B,KEY_M]:get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_B,KEY_M] and can_open_guide():
		open_guide("Map" if event.keycode==KEY_M else "Objective")
		get_viewport().set_input_as_handled();return
	if intro!=null and intro.active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
			intro.finish();get_viewport().set_input_as_handled()
		return
	if hud!=null and hud.restart_dialog_open:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			hud.cancel_restart_confirmation()
			get_viewport().set_input_as_handled()
		return
	if ending_sequence!=null and ending_sequence.active and ending_sequence.preview and not hud.menu_open and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		ending_sequence.close_preview()
		get_viewport().set_input_as_handled()
		return
	if computer_portal != null and computer_portal.transitioning:
		if event is InputEventKey: get_viewport().set_input_as_handled()
		return
	if ready_for_test and sample_course != null and sample_course.is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		sample_course.close()
		get_viewport().set_input_as_handled()
		return
	if ready_for_test and check_in != null and check_in.is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		check_in.close()
		get_viewport().set_input_as_handled()
		return
	if ready_for_test and entrance_puzzle.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		entrance_puzzle.leave()
		get_viewport().set_input_as_handled()
		return
	if ready_for_test and elevator_game.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		elevator_game.close()
		get_viewport().set_input_as_handled()
		return
	if ready_for_test and npc_conversations != null and npc_conversations.dialogue.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		npc_conversations.dialogue.close()
		get_viewport().set_input_as_handled()
		return
	if ready_for_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3 and hud.developer!=null:
		var close_debug: bool = hud.menu_open and hud.debug_mode
		hud.set_debug_mode(not close_debug)
		set_menu_open(not close_debug,true)
		get_viewport().set_input_as_handled()
	if ready_for_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_menu_open(not hud.menu_open)
		get_viewport().set_input_as_handled()

func go_location(index: int) -> void:
	if lift_in_progress or (ending_sequence!=null and ending_sequence.active) or (computer_portal != null and computer_portal.transitioning):
		return
	if sample_course != null: sample_course.close()
	if computer_portal != null: computer_portal.leave_for_developer_travel()
	if npc_conversations != null: npc_conversations.interrupt()
	if check_in != null: check_in.close()
	if classroom_sequence != null: classroom_sequence.cancel()
	last_location = clampi(index, 0, LOCATIONS.size() - 1)
	player.teleport_to(LOCATIONS[last_location], LOCATION_HEADINGS[last_location])

func try_lift() -> bool:
	if population != null and population.travel != null and not population.travel.lift_actor.is_empty(): return false
	if lift_in_progress or hud.menu_open or entrance_puzzle.visible or elevator_game.visible or arrival_busy() or (npc_conversations != null and npc_conversations.dialogue.visible) or (computer_portal != null and (computer_portal.inside or computer_portal.transitioning)):
		return false
	var ground_distance: float = player.global_position.distance_to(LIFT_GROUND)
	var upper_distance: float = player.global_position.distance_to(LIFT_UPPER)
	if ground_distance < LIFT_INTERACTION_RADIUS and _lift_line_clear(LIFT_GROUND):
		if orchestrator.ascent_allowed():
			if not orchestrator.claim("lift"): return false
			_perform_lift(LIFT_GROUND, LIFT_UPPER)
		else:
			if not orchestrator.claim("shooter"): return false
			player.set_controls_locked(true)
			hud.hint_panel.hide()
			hud.hint_timer.stop()
			elevator_game.open()
		return true
	if upper_distance < LIFT_INTERACTION_RADIUS and _lift_line_clear(LIFT_UPPER):
		if not orchestrator.claim("lift"): return false
		_perform_lift(LIFT_UPPER, LIFT_GROUND)
		return true
	return false

func _lift_line_clear(source: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, source + Vector3.UP * 0.8, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _perform_lift(source: Vector3, destination: Vector3) -> void:
	lift_in_progress = true
	player.set_controls_locked(true)
	var approach: Vector3 = source + Vector3.UP * 0.012 - player.global_position
	player.scripted_move_speed = 2.2 if approach.length() > 0.1 else 0.0
	if approach.length() > 0.1:
		player.visual.rotation.y = atan2(-approach.x, -approach.z)
	var entry := create_tween()
	entry.tween_property(player, "global_position", source + Vector3.UP * 0.012, clampf(approach.length() / 2.2, 0.15, 0.9))
	await entry.finished
	player.scripted_move_speed = 0.0
	hud.travel_label.text = "Elevator · " + ("Second Floor" if destination.y > source.y else "Ground Floor")
	hud.travel_overlay.show()
	var fade_in := create_tween()
	fade_in.tween_method(hud.set_travel_opacity, 0.0, 1.0, 0.25)
	await fade_in.finished
	player.teleport_to(destination, LIFT_HEADING)
	await get_tree().create_timer(0.35).timeout
	var fade_out := create_tween()
	fade_out.tween_method(hud.set_travel_opacity, 1.0, 0.0, 0.3)
	await fade_out.finished
	hud.travel_overlay.hide()
	player.scripted_move_speed = 2.2
	player.visual.rotation.y = LIFT_HEADING
	# Stop just outside the upper jamb; the player chooses the onward walk.
	var exit_offset: Vector3 = (UPPER_LIFT_EXIT if destination.y > source.y else LOWER_LIFT_EXIT)-destination
	var exit := create_tween()
	exit.tween_property(player, "global_position", destination + exit_offset, exit_offset.length() / 2.2)
	await exit.finished
	player.scripted_move_speed = 0.0
	lift_in_progress = false
	orchestrator.release("lift")
	player.set_controls_locked(hud.menu_open)
	lift_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_test or hud.menu_open or lift_in_progress or entrance_puzzle.visible or elevator_game.visible or arrival_busy() or (npc_conversations != null and npc_conversations.dialogue.visible) or (computer_portal != null and computer_portal.transitioning) or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		# Explicit developer-menu travel still works; normal shortcuts cannot skip the lock.
		if hud.developer!=null and building_review_mode:
			go_location(event.keycode - KEY_1)
	elif event.keycode == KEY_F:
		if try_replay(): get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E:
		var npc: Dictionary = npc_conversations.reachable_npc()
		var computer: Dictionary = {} if computer_portal.inside else computer_portal.reachable_computer()
		if prefers_keypad(npc,computer) and try_entrance():
			get_viewport().set_input_as_handled()
			return
		if prefers_npc(npc,computer) and npc_conversations.try_talk():
			get_viewport().set_input_as_handled()
			return
		if check_in.try_use(computer):
			get_viewport().set_input_as_handled()
			return
		if computer_portal.try_use():
			get_viewport().set_input_as_handled()
			return
		if not try_entrance():
			try_lift()

func interaction_score(point: Vector3) -> float:
	var toward: Vector3 = point-player.global_position
	toward.y = 0
	var facing: Vector3 = -player.camera_pivot.global_basis.z
	facing.y = 0
	return toward.length_squared()+4.0*(1.0-facing.normalized().dot(toward.normalized()))

func prefers_npc(npc: Dictionary, computer: Dictionary) -> bool:
	if npc.is_empty(): return false
	return computer.is_empty() or interaction_score(npc.actor.global_position)<interaction_score(computer.point)

func prefers_keypad(npc: Dictionary, computer: Dictionary) -> bool:
	if building_review_mode or orchestrator.entrance_allowed() or not entrance_keypad.can_use(player): return false
	var score: float = interaction_score(entrance_keypad.global_position)
	return (npc.is_empty() or score<=interaction_score(npc.actor.global_position)) and (computer.is_empty() or score<=interaction_score(computer.point))

func _maybe_show_stairs_hint() -> void:
	if stairs_hint_seen or hud.menu_open or entrance_puzzle.visible or elevator_game.visible or arrival_busy() or npc_conversations.dialogue.visible or computer_portal.inside: return
	if not (building_review_mode or orchestrator.entrance_allowed()): return
	var at: Vector3=player.global_position
	if at.y<.35 and at.x>=-2.2 and at.x<=2.9 and at.z>=-.5 and at.z<=1.8:
		stairs_hint_seen=true
		hud.show_navigation_hint(GameHUD.STAIRS_HINT)

func _physics_process(delta: float) -> void:
	if not ready_for_test:
		return
	if player.global_position.y < -8.0:
		if not computer_portal.reset_in_room(): go_location(last_location)
	var near_lift: bool = player.global_position.distance_to(LIFT_GROUND) < LIFT_INTERACTION_RADIUS or player.global_position.distance_to(LIFT_UPPER) < LIFT_INTERACTION_RADIUS
	var zone: String = "purple_room" if computer_portal.inside else ("upstairs" if player.global_position.y>3.0 else ("street" if player.global_position.z>ENTRANCE_POINT.z else "ground"))
	if ending_sequence==null or not ending_sequence.active or not ending_sequence.preview: orchestrator.observe_zone(zone)
	if auto_play_ending and not hud.menu_open and not arrival_busy() and not lift_in_progress and not computer_portal.transitioning and orchestrator.ending_ready():
		ending_sequence.start(false)
	_refresh_progress_hud()
	hud.set_objective(orchestrator.objective())
	# Upstairs (and Mr. P's room) stay silent so his recorded voice reads clearly.
	GameAudio.set_context("ground" if intro!=null and intro.active else "shooter" if elevator_game.visible else "quiet" if player.global_position.y>3.0 or computer_portal.inside else "ground")
	hud.replay_button.disabled = arrival_busy() or lift_in_progress or computer_portal.transitioning
	hud.guide_menu_button.disabled=not can_open_guide()
	hud.guide_button.disabled=not can_open_guide()
	hud.update_location(player.global_position.y > 3.0, near_lift)
	_maybe_show_stairs_hint()
	if not building_review_mode and not hud.menu_open and not orchestrator.ascent_allowed() and player.global_position.distance_to(LIFT_GROUND) < LIFT_INTERACTION_RADIUS:
		hud.prompt_label.text = GameHUD.ELEVATOR_GAME_PROMPT
	match replay_target():
		"entrance": if hud.prompt_label.text.is_empty(): hud.prompt_label.text="F: Play the entrance puzzle again"
		"shooter": hud.prompt_label.text="E: Ride upstairs · F: Play the elevator game again"
	if near_lift and population!=null and population.travel!=null and not population.travel.lift_actor.is_empty():
		hud.prompt_label.text="Elevator in use · Leave the cab clear"
	computer_portal.update_prompts(delta)
	npc_conversations.update(delta)
	if computer_portal.inside: hud.floor_label.text = "Purple Room"
	var computer_prompt: String = computer_portal.context_prompt()
	if not computer_prompt.is_empty(): hud.prompt_label.text = computer_prompt
	var npc_prompt: String = npc_conversations.context_prompt()
	var keypad_available: bool = not building_review_mode and not hud.menu_open and not entrance_puzzle.visible and not elevator_game.visible and not npc_conversations.dialogue.visible and not arrival_busy() and not orchestrator.entrance_allowed()
	var keypad_focused: bool = keypad_available and prefers_keypad(npc_conversations.selected,computer_portal.active_computer)
	var npc_focused: bool = not keypad_focused and prefers_npc(npc_conversations.selected,computer_portal.active_computer)
	if npc_focused and not npc_prompt.is_empty(): hud.prompt_label.text = npc_prompt
	# The same target wins the E action and the single contextual HUD prompt.
	for computer: Dictionary in computer_portal.computers:
		computer.label.hide()
		computer.label.modulate = GameHUD.CYAN if not keypad_focused and not npc_focused and computer==computer_portal.active_computer else GameHUD.WHITE
	for npc: Dictionary in npc_conversations.actors:
		npc.label.hide()
	entrance_keypad.prompt.hide()
	if keypad_focused: hud.prompt_label.text = "Approach the keypad to restore power" if keypad_approach_armed else "Step away, then approach to resume the puzzle"
	if not entrance_keypad.nearby(player,1.8): keypad_approach_armed=true
	if keypad_available and keypad_approach_armed and entrance_keypad.can_approach(player): try_entrance(true)
	if not keypad_focused and not npc_focused and check_in.targets(computer_portal.active_computer): hud.prompt_label.text = "E: Check-In Console"
	if entrance_puzzle.visible or elevator_game.visible or npc_conversations.dialogue.visible or arrival_busy():
		hud.prompt_label.text = ""
	if hud.prompt_label.text.is_empty() and not hud.menu_open and not arrival_busy() and not entrance_puzzle.visible and not elevator_game.visible and not npc_conversations.dialogue.visible:
		if player.sit_state==&"sitting":hud.prompt_label.text="C: Stand up"
		elif player.sit_state==&"" and not player.chairs.nearest().is_empty():hud.prompt_label.text="C: Sit on chair"
	hud.update_extra_hints(not hud.menu_open and not entrance_puzzle.visible and not elevator_game.visible and not npc_conversations.dialogue.visible and not arrival_busy() and not lift_in_progress and not computer_portal.transitioning)
	hud.update_debug(player.global_position)
	hud.bonus_button.disabled=not entrance_puzzle.state.unlocked
	if hud.developer != null and sample_course != null:
		hud.developer.sample_course_button.disabled = not sample_course.available()
		hud.developer.ending_preview_button.disabled=ending_sequence.active or lift_in_progress or computer_portal.transitioning or (classroom_sequence!=null and classroom_sequence.active)
		hud.developer.intro_preview_button.disabled=arrival_busy() or lift_in_progress or computer_portal.transitioning

func _refresh_progress_hud() -> void:
	var revision: int = orchestrator.revision()
	if revision==_hud_progress_revision: return
	hud.set_progress(orchestrator.snapshot())
	_hud_progress_revision=revision

func _open_bonus_puzzles() -> void:
	if not entrance_puzzle.state.unlocked or arrival_busy() or lift_in_progress:return
	set_menu_open(false)
	if not orchestrator.claim("bonus"):return
	player.set_controls_locked(true);entrance_puzzle.open()
