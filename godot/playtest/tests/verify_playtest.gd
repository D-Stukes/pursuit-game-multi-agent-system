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
	var packed: PackedScene = load("res://BuildingPlaytest.tscn")
	world = packed.instantiate()
	root.add_child(world)
	await frames(5)
	if not world.ready_for_test:
		check("world ready", false)
		quit(1)
		return
	player = world.player
	check("licensed avatar loaded", player.avatar_loaded)
	check("avatar human-scale height", absf(player.avatar_height - 1.72) < 0.01, player.avatar_height)
	check("avatar idle and walk clips", player.animation_player != null and player.animation_player.has_animation("idle") and player.animation_player.has_animation("walk"))
	var avatar: Node3D = player.visual.get_node_or_null("QuaterniusCharacter")
	check("Quaternius casual avatar selected", avatar != null)
	var skeleton: Skeleton3D = avatar.find_children("*", "Skeleton3D", true, false)[0] if avatar else null
	check("humanoid rig and skinned body parts", skeleton != null and skeleton.get_bone_count() == 62 and avatar.find_children("*", "MeshInstance3D", true, false).size() == 4)
	check("full building loaded", world.mesh_count == 2160, world.mesh_count)
	check("static building collision", world.collision_triangles > 10000, world.collision_triangles)
	check("camera excludes player layer", player.spring_arm.collision_mask == 1 and player.collision_layer == 2)
	for i in range(3):
		world.go_location(i)
		await frames(45)
		check("floor at " + world.LOCATION_NAMES[i], player.is_on_floor() and absf(player.global_position.y - world.LOCATIONS[i].y) < 0.15, player.global_position)
	player.apply_look(Vector2(0, 1000000))
	check("pitch lower bound", is_equal_approx(player.camera_pivot.rotation.x, player.MIN_PITCH))
	player.apply_look(Vector2(0, -1000000))
	check("pitch upper bound", is_equal_approx(player.camera_pivot.rotation.x, player.MAX_PITCH))
	player.change_zoom(-100)
	check("zoom lower bound", is_equal_approx(player.spring_arm.spring_length, player.MIN_ZOOM))
	player.change_zoom(100)
	check("zoom upper bound", is_equal_approx(player.spring_arm.spring_length, player.MAX_ZOOM))
	player.spring_arm.spring_length = 3.0
	world.go_location(0)
	await frames(30)
	player.set_controls_active(false)
	var stationary: Vector3 = player.global_position
	Input.action_press("walk_forward")
	await frames(25)
	Input.action_release("walk_forward")
	check("release stops walking", player.global_position.distance_to(stationary) < 0.05)
	check("stationary avatar idles", player.current_animation == &"idle", player.current_animation)
	# Turn before the foot of the railing rather than trying to cross through it.
	var route: Array[Vector3] = [Vector3(0, 0, 3.0), Vector3(2.35, 0, 3.0),
		Vector3(2.35, 0.85, -4.8), Vector3(2.35, 0.85, -12.1), world.LIFT_GROUND]
	for i in range(route.size()):
		var arrived: bool = await walk_to(route[i], 300)
		check("entrance/ramp/lift route " + str(i), arrived, player.global_position)
		if not arrived:
			break
	player.set_controls_active(true)
	var idle_bones: Array[Transform3D] = []
	if skeleton:
		for bone in range(skeleton.get_bone_count()):
			idle_bones.append(skeleton.get_bone_global_pose(bone))
	Input.action_press("walk_back")
	await frames(12)
	check("moving avatar walks", player.current_animation == &"walk", player.current_animation)
	var pose_change: float = 0.0
	if skeleton:
		for bone in range(skeleton.get_bone_count()):
			pose_change += skeleton.get_bone_global_pose(bone).origin.distance_to(idle_bones[bone].origin)
	check("walking animates the skeleton", pose_change > 0.1, pose_change)
	Input.action_release("walk_back")
	player.teleport_to(world.LIFT_GROUND)
	await frames(20)
	check("lift to second floor", world.try_lift())
	await frames(30)
	check("upper lift floor", player.is_on_floor() and absf(player.global_position.y - 5.05) < 0.15, player.global_position)
	var upper_route: Array[Vector3] = [Vector3(2.5, 5.05, -12.1), Vector3(3.3, 5.05, -12.8), Vector3(8.3, 5.05, -12.8)]
	for i in range(upper_route.size()):
		var arrived: bool = await walk_to(upper_route[i], 240)
		check("lift/reception route " + str(i), arrived, player.global_position)
		if not arrived:
			break
	var classroom_route: Array[Vector3] = [Vector3(11.9, 5.05, -12.92), Vector3(12.1, 5.05, -9.72),
		Vector3(13.3, 5.05, -9.72), Vector3(14.5, 5.05, -9.72), Vector3(15.4, 5.05, -9.72),
		Vector3(18.56, 5.05, -9.72), Vector3(18.56, 5.05, -7), Vector3(18.56, 5.05, -2)]
	for i in range(classroom_route.size()):
		var arrived: bool = await walk_to(classroom_route[i], 240)
		check("reception/classroom doorway route " + str(i), arrived, player.global_position)
		if not arrived:
			break
	# The camera must stop in front of a real facade, not inside or behind it.
	player.teleport_to(Vector3(4.0, 0, 5.8), PI)
	await frames(30)
	check("camera retracts at facade", player.spring_arm.get_hit_length() < 2.0, player.spring_arm.get_hit_length())
	check("close camera hides avatar obstruction", not player.visual.visible)
	var ray := PhysicsRayQueryParameters3D.create(player.camera_pivot.global_position, player.camera.global_position, 1)
	check("camera view segment clear", world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), player.camera.global_position)
	# Driving directly into a facade must not pass through the building.
	player.camera_pivot.rotation.y = 0.0
	player.set_controls_active(true)
	Input.action_press("walk_forward")
	await frames(100)
	Input.action_release("walk_forward")
	check("player blocked by facade", player.global_position.z > 4.75, player.global_position)
	world.go_location(0)
	await frames(10)
	check("avatar returns at normal camera distance", player.visual.visible)
	# Drive into each new boundary, rather than only inspecting its shape settings.
	var limits: Array[Dictionary] = [
		{"name": "left", "feet": Vector3(-10.5, 0, 6.7), "yaw": PI / 2.0},
		{"name": "right", "feet": Vector3(10.5, 0, 6.7), "yaw": -PI / 2.0},
		{"name": "street", "feet": Vector3(0, 0, 7.0), "yaw": PI},
		{"name": "left return", "feet": Vector3(-10.7, 0, 5.8), "yaw": 0.0}
	]
	for limit in limits:
		player.teleport_to(limit["feet"], limit["yaw"])
		await frames(12)
		player.set_controls_active(true)
		Input.action_press("walk_forward")
		await frames(90)
		Input.action_release("walk_forward")
		await frames(12)
		var stayed_inside: bool = player.is_on_floor() and absf(player.global_position.x) < 11.8 and player.global_position.z < 8.35
		if limit["name"] == "left return":
			stayed_inside = stayed_inside and player.global_position.z > 5.1
		check("sidewalk boundary blocks " + limit["name"], stayed_inside, player.global_position)
		player.spring_arm.spring_length = player.MAX_ZOOM
		for yaw: float in [0.0, PI / 2.0, PI, -PI / 2.0]:
			player.camera_pivot.rotation.y = yaw
			await frames(3)
			var boundary_ray := PhysicsRayQueryParameters3D.create(player.camera_pivot.global_position, player.camera.global_position, 1)
			check("boundary camera view clear " + limit["name"] + " " + str(yaw), world.get_world_3d().direct_space_state.intersect_ray(boundary_ray).is_empty())
		player.teleport_to(limit["feet"], limit["yaw"])
		await frames(12)
		Input.action_press("walk_forward")
		Input.action_press("run")
		await frames(70)
		Input.action_release("walk_forward")
		Input.action_release("run")
		await frames(12)
		var run_stayed_inside: bool = player.is_on_floor() and absf(player.global_position.x) < 11.8 and player.global_position.z < 8.35
		if limit["name"] == "left return":
			run_stayed_inside = run_stayed_inside and player.global_position.z > 5.1
		check("running blocked by tape " + limit["name"], run_stayed_inside, player.global_position)
	# The visible shell and its box collider have identical dimensions. These rays
	# check eye-height street coverage without opening another rendering window.
	for x: float in [-10.5, 10.5]:
		for direction: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
			var eye := Vector3(x, 2.0, 6.7)
			var coverage_ray := PhysicsRayQueryParameters3D.create(eye, eye + direction.normalized() * 150, 1)
			check("street view meets buildings " + str(x) + " " + str(direction), not world.get_world_3d().direct_space_state.intersect_ray(coverage_ray).is_empty())
	for gap_x: float in [-45.75, -16.25, 10.25, 39.75]:
		var seam_ray := PhysicsRayQueryParameters3D.create(Vector3(gap_x, 4.5, 15), Vector3(gap_x, 4.5, 50), 1)
		check("adjoining facades close seam " + str(gap_x), not world.get_world_3d().direct_space_state.intersect_ray(seam_ray).is_empty())
	var failures: int = 0
	for result in checks:
		if not result["pass"]:
			failures += 1
	var report := {"checks": checks, "failures": failures, "meshes": world.mesh_count, "triangles": world.collision_triangles}
	DirAccess.make_dir_recursive_absolute("res://.godot/playtest")
	var output := FileAccess.open("res://.godot/playtest/verification.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("PLAYTEST_RESULT checks=", checks.size(), " failures=", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
