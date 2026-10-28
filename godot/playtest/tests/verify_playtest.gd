extends SceneTree
## Integration checks run against the real imported model and physics world.

var checks: Array[Dictionary] = []
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check": label, "pass": passed, "detail": str(detail)})
	print("PASS " if passed else "FAIL ", label, " ", detail)

func walk_to(target: Vector3, max_frames: int = 300) -> bool:
	player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool = false
	for _i in range(max_frames):
		var delta: Vector3 = target - player.global_position
		delta.y = 0.0
		if delta.length() < 0.16:
			arrived = true
			break
		player.camera_pivot.rotation.y = atan2(-delta.x, -delta.z)
		await physics_frame
	Input.action_release("walk_forward")
	await frames(12)
	return arrived and absf(player.global_position.y - target.y) < 0.22

func run() -> void:
	world = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	check("world ready", world.ready_for_test)
	if not world.ready_for_test:
		quit(1);return
	player = world.player
	check("source classroom props retained", world.approved_layout.retained.get("classroom") == 646)
	check("shared export has full environment", world.mesh_count > 4000 and world.collision_triangles > 10000)
	check("manifest anchors match actual export", world.approved_layout.missing.is_empty())
	check("licensed avatar loaded", player.avatar_loaded)
	check("human scale avatar", absf(player.avatar_height-1.72)<.01)
	check("idle and walk clips available", player.animation_player.has_animation("idle") and player.animation_player.has_animation("walk"))
	check("camera excludes avatar layer", player.spring_arm.collision_mask == 1 and player.collision_layer == 2)
	for i in range(3):
		world.go_location(i);await frames(45)
		check("floor at "+world.LOCATION_NAMES[i], player.is_on_floor() and absf(player.global_position.y-world.LOCATIONS[i].y)<.15, player.global_position)
	player.apply_look(Vector2(0,1000000))
	check("pitch lower bound",is_equal_approx(player.camera_pivot.rotation.x,player.MIN_PITCH))
	player.apply_look(Vector2(0,-1000000))
	check("pitch upper bound",is_equal_approx(player.camera_pivot.rotation.x,player.MAX_PITCH))
	world.go_location(0);await frames(20)
	player.set_controls_active(false)
	var stopped:Vector3=player.global_position
	Input.action_press("walk_forward");await frames(20);Input.action_release("walk_forward")
	check("inactive controls stop walking",player.global_position.distance_to(stopped)<.05)
	check("stationary avatar idles",player.current_animation==&"idle")
	var puzzle:Control=world.entrance_puzzle
	for step:int in [0,1,2]:puzzle._choose(step)
	puzzle._check_order();puzzle.code_input.text=puzzle.state.revealed_code();puzzle._unlock()
	check("puzzle earned entry",puzzle.state.unlocked)
	var ground_route:Array[Vector3]=[Vector3(0,0,3),Vector3(2.35,0,3),Vector3(2.35,.85,-4.8),Vector3(2.35,.85,-6.6),Vector3(2.35,.85,-9.4),Vector3(1.05,.85,-12.1),world.LIFT_GROUND]
	await route("street ramp elevator",ground_route)
	Input.action_press("walk_back");player.set_controls_active(true);await frames(12)
	check("actual movement animates avatar",player.current_animation==&"walk" and player.animation_player.is_playing())
	Input.action_release("walk_back")
	player.teleport_to(world.LIFT_GROUND);await frames(20)
	var started:bool=world.try_lift()
	check("lift activates from lower cab",started)
	check("lift locks controls",world.lift_in_progress and player.controls_locked)
	check("lift ignores repeated activation",not world.try_lift())
	if started:await world.lift_finished
	await frames(20)
	check("lift exits on upper floor",player.is_on_floor() and player.global_position.distance_to(world.UPPER_LIFT_EXIT)<.07,player.global_position)
	check("lift arrival faces opposite room",Vector3(-player.camera_pivot.global_basis.z.x,0,-player.camera_pivot.global_basis.z.z).normalized().dot(Vector3.RIGHT)>.99)
	player.apply_look(Vector2(PI/(2*player.SENSITIVITY),0))
	check("right turn faces reception",Vector3(-player.camera_pivot.global_basis.z.x,0,-player.camera_pivot.global_basis.z.z).normalized().dot(Vector3.BACK)>.99)
	await route("actual right-turn approach to reception",[Vector3(1.05,5.05,-10),world.approved_layout.anchor("reception_entry"),world.LOCATIONS[1]])
	await route("direct classroom double doors",[Vector3(.38,5.05,-6.4),world.approved_layout.anchor("classroom_door"),Vector3(.38,5.05,-4.4)])
	# Isolated branches still cross each real door on foot; no teleport through it.
	player.teleport_to(Vector3(4.4,5.06,-7.8));await frames(15)
	await route("separate room doorway",[Vector3(6.2,5.05,-7.8),Vector3(8,5.05,-5.8),Vector3(8,5.05,-2)])
	player.teleport_to(Vector3(1.05,5.06,-7));await frames(15)
	await route("Hallway2 to open indoor area",[Vector3(1.05,5.05,-6.2),Vector3(-2,5.05,-6.2),Vector3(-10,5.05,-6.2),Vector3(-18,5.05,-6.2),world.approved_layout.anchor("commons_entry"),world.approved_layout.anchor("commons_spawn")])
	for center:float in [-5.05,-2.55]:
		player.teleport_to(Vector3(center,5.06,-6.2));await frames(15)
		await route("Hallway2 small room "+str(center),[Vector3(center,5.05,-7.8)])
	player.teleport_to(Vector3(1.05,5.06,-10));await frames(15)
	await route("Hallway1 ends at bathrooms",[Vector3(1.05,5.05,-10.65),Vector3(-3.3,5.05,-10.65),Vector3(-5.38,5.05,-10.6)])
	player.teleport_to(world.UPPER_LIFT_EXIT);await frames(20)
	started=world.try_lift();check("return lift activates from arrival position",started)
	if started:await world.lift_finished
	await frames(20)
	check("return lift lands and unlocks",player.is_on_floor() and absf(player.global_position.y-.85)<.15 and not player.controls_locked,player.global_position)
	player.teleport_to(Vector3(-1.25,0,.3));await frames(20)
	check("walk up original stairs",await walk_to(Vector3(-1.25,.85,-3)),player.global_position)
	check("walk down original stairs",await walk_to(Vector3(-1.25,0,.3)),player.global_position)
	Input.action_press("run")
	check("run up original stairs",await walk_to(Vector3(-1.25,.85,-3)),player.global_position)
	check("run down original stairs",await walk_to(Vector3(-1.25,0,.3)),player.global_position)
	Input.action_release("run")
	# Camera collision uses the real façade after source promotion.
	player.teleport_to(Vector3(4,0,5.8),PI);await frames(30)
	check("camera retracts at facade",player.spring_arm.get_hit_length()<2,player.spring_arm.get_hit_length())
	var failures:int=0
	for result:Dictionary in checks:
		if not result.pass:failures+=1
	var file:=FileAccess.open("res://.godot/playtest/verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	print("PLAYTEST_RESULT checks=",checks.size()," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)

func route(label:String,points:Array[Vector3])->void:
	for i in range(points.size()):
		var arrived:bool=await walk_to(points[i],420)
		check(label+" "+str(i),arrived,player.global_position)
		if not arrived:break
