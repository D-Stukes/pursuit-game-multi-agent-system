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

func street_ray(start: Vector3, end: Vector3) -> Dictionary:
	var offset := Vector3(0, 0, world.ExteriorBackdrop.FRONT_EXTENSION)
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start + offset, end + offset, 1))

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
	check("full building loaded", world.mesh_count > 1500 and world.approved_layout.retained.get("classroom") == 646, world.mesh_count)
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
	player.teleport_to(Vector3(-1.25, 0, 0.3))
	await frames(20)
	check("walk up actual stair treads", await walk_to(Vector3(-1.25, 0.85, -3.0)), player.global_position)
	check("walk down actual stair treads", await walk_to(Vector3(-1.25, 0, 0.3)), player.global_position)
	Input.action_press("run")
	check("run up actual stair treads", await walk_to(Vector3(-1.25, 0.85, -3.0)), player.global_position)
	check("run down actual stair treads", await walk_to(Vector3(-1.25, 0, 0.3)), player.global_position)
	Input.action_release("run")
	world.go_location(0)
	await frames(20)
	# Turn before the foot of the railing rather than trying to cross through it.
	# The route proof must earn entry before traversing the new physical gate.
	var puzzle: Control = world.entrance_puzzle
	for step: int in [0, 1, 2]:
		puzzle._choose(step)
	puzzle._check_order()
	puzzle.code_input.text = puzzle.state.revealed_code()
	puzzle._unlock()
	check("entrance puzzle permits route proof", puzzle.state.unlocked)
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
	check("lift transition locks controls", world.lift_in_progress and player.controls_locked)
	check("lift ignores repeated activation", not world.try_lift())
	world.set_menu_open(true)
	world.set_menu_open(false)
	check("closing menu cannot unlock moving lift", player.controls_locked)
	await world.lift_finished
	await frames(30)
	check("upper lift floor", player.is_on_floor() and absf(player.global_position.y - 5.05) < 0.15, player.global_position)
	check("upper lift walk-out stops just outside jamb", player.global_position.distance_to(world.UPPER_LIFT_EXIT) < .05, player.global_position)
	var arrival_forward: Vector3 = -player.camera_pivot.global_basis.z
	arrival_forward.y = 0
	check("lift arrival faces opposite room", arrival_forward.normalized().dot(Vector3.RIGHT) > .999)
	# Turn through the real controller rather than choosing a fresh proof pose.
	player.apply_look(Vector2(PI / (2.0 * player.SENSITIVITY), 0))
	var reception_direction: Vector3 = world.LOCATIONS[1] - player.global_position
	reception_direction.y = 0
	var turned_forward: Vector3 = -player.camera_pivot.global_basis.z
	turned_forward.y = 0
	check("actual right turn faces reception approach", turned_forward.normalized().dot(reception_direction.normalized()) > .9)
	await frames(3)
	var door_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.7, 6.1, -12.1), Vector3(5.5, 6.1, -12.1), 1))
	check("other-room opaque door blocks path opposite cab", not door_hit.is_empty() and door_hit["position"].x > 4.8 and door_hit["position"].x < 5.1)
	var sightline: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.5, Vector3(2.7, 6.55, -7.9), 1))
	check("reception visible along landing after right turn", sightline.is_empty())
	var double_entry_clear: bool = true
	for x: float in [-.7, 0.0, .6, 1.2, 1.4]:
		var entry_ray := PhysicsRayQueryParameters3D.create(Vector3(x,6.3,-5.7),Vector3(x,6.3,-5.1),1)
		double_entry_clear = double_entry_clear and world.get_world_3d().direct_space_state.intersect_ray(entry_ray).is_empty()
	check("both halves of shared classroom double entry are clear",double_entry_clear)
	var hallway_column: MeshInstance3D
	for mesh: MeshInstance3D in world.get_node("Building").find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).replace("_", " ") == "Arrival round white column":
			hallway_column = mesh
	check("white cylinder is left in cross-hall between elevator and reception", hallway_column != null and hallway_column.global_position.z > -11.2 and hallway_column.global_position.z < -8.8 and hallway_column.global_position.x < 0)
	var ground_floor: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-.95, 3, -12.1), Vector3(-.95, 0, -12.1), 1))
	var upper_floor: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-.95, 7, -12.1), Vector3(-.95, 4, -12.1), 1))
	check("lift floors remain vertically aligned", not ground_floor.is_empty() and not upper_floor.is_empty() and absf(upper_floor["position"].y - ground_floor["position"].y - 4.2) < .02)
	var upper_route: Array[Vector3] = [Vector3(2.7, 5.05, -12.1), Vector3(2.7, 5.05, -9.45), Vector3(2.7, 5.05, -7.9)]
	for i in range(upper_route.size()):
		var arrived: bool = await walk_to(upper_route[i], 240)
		check("lift/reception route " + str(i), arrived, player.global_position)
		if not arrived:
			break
	var classroom_route: Array[Vector3] = [Vector3(2.7,5.05,-7.35), Vector3(.38,5.05,-7.35),
		Vector3(.38,5.05,-6.15), Vector3(.38,5.05,-4.8), Vector3(.38,5.05,-1.23), Vector3(-8.1,5.05,-1.23)]
	for i in range(classroom_route.size()):
		var arrived: bool = await walk_to(classroom_route[i], 240)
		check("reception/classroom doorway route " + str(i), arrived, player.global_position)
		if not arrived:
			break
	# The camera must stop in front of a real facade, not inside or behind it.
	player.teleport_to(world.LIFT_UPPER)
	await frames(20)
	check("lift returns to ground floor", world.try_lift())
	await world.lift_finished
	await frames(15)
	check("return lift lands and unlocks", player.is_on_floor() and absf(player.global_position.y - 0.85) < 0.15 and not player.controls_locked)
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
		limit["feet"] += Vector3(0, 0, world.ExteriorBackdrop.FRONT_EXTENSION)
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
	# Approved H: joined central neighbors, two clear vertical roads, and continuous
	# outer building screens instead of empty horizontal road extensions.
	var space := world.get_world_3d().direct_space_state
	var backdrop: Node3D = world.get_node("ExteriorBackdrop")
	for x: float in [-42.0, -3.0, 25.0, 50.0]:
		var hit: Dictionary = street_ray(Vector3(x, 2, 23), Vector3(x, 2, 40))
		check("opposite frontage closer across road " + str(x), not hit.is_empty() and hit["position"].z < 27.0)
	for x: float in [-25.0, 40.5]:
		var hit: Dictionary = street_ray(Vector3(x, 2, 7), Vector3(x, 2, -5))
		check("near-side neighbor retained " + str(x), not hit.is_empty())
	for x: float in [-56.0, 68.0]:
		var hit: Dictionary = street_ray(Vector3(x, 2, -75), Vector3(x, 2, 110))
		check("H side road clear along its length " + str(x), hit.is_empty())
	for z: float in [9.0, 12.0, 15.5, 19.0, 22.0]:
		for side: int in [-1, 1]:
			var hit: Dictionary = street_ray(Vector3(6, 2, z), Vector3(6 + side * 115, 2, z))
			check("outer buildings mask horizontal road end " + str(side) + "/" + str(z), not hit.is_empty())
	for z: float in [-74.0, -56.0, -20.0, 16.0, 52.0, 106.0]:
		for side: int in [-1, 1]:
			var start := Vector3(-56 if side < 0 else 68, 2, z)
			var hit: Dictionary = street_ray(start, start + Vector3(side * 40, 0, 0))
			check("outer row remains joined " + str(side) + "/" + str(z), not hit.is_empty())
	var crossbar: MeshInstance3D = backdrop.get_node("FrontRoad")
	var road_bounds: AABB = crossbar.transform * crossbar.mesh.get_aabb()
	check("H crossbar stops at side-road centers", is_equal_approx(road_bounds.position.x, -56.0) and is_equal_approx(road_bounds.end.x, 68.0))
	var trees := backdrop.find_children("StreetTree*", "Node3D", false, false)
	check("modest city tree count", trees.size() >= 6 and trees.size() <= 12, trees.size())
	check("opposite frontage has small gardens and markers", backdrop.find_children("PocketGarden*", "Node3D", false, false).size() == 2 and backdrop.find_children("StreetMarker*", "Node3D", false, false).size() == 4)
	var decoration_clear: bool = true
	for tree: Node3D in trees:
		decoration_clear = decoration_clear and (tree.position.z > 22.5 or tree.position.x < -63.0 or tree.position.x > 75.0)
	check("planting stays off roads and playable sidewalk", decoration_clear)
	var box_resources: Dictionary = {}
	var sphere_resources: Dictionary = {}
	var tape_shaders: Dictionary = {}
	for item: Node3D in backdrop.find_children("*", "Node3D", true, false):
		var resource: Mesh
		if item is MeshInstance3D:
			resource = item.mesh
		elif item is MultiMeshInstance3D:
			resource = item.multimesh.mesh
		if resource is BoxMesh:
			box_resources[resource.get_instance_id()] = true
		elif resource is SphereMesh:
			sphere_resources[resource.get_instance_id()] = true
		if item is MeshInstance3D and item.material_override is ShaderMaterial:
			tape_shaders[item.material_override.shader.get_instance_id()] = true
	check("scenery boxes reuse resources", box_resources.size() < 100, box_resources.size())
	check("tree shrub and cloud spheres are shared", sphere_resources.size() == 3, sphere_resources.size())
	check("tape boundaries share one shader", tape_shaders.size() == 1)
	check("flat road avoids casting shadows", crossbar.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check("building shadow casting retained", backdrop.get_node("NearLeftNeighbor/Shell").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
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
