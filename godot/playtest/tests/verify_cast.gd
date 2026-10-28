extends SceneTree
## Inspect actual skin bindings and CPU-skinned vertices in the building scene.
var checks: int = 0
var failures: int = 0
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label, " ", detail)

func skin_bounds(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for surface: int in range(mesh.mesh.get_surface_count()):
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = joints.size() / vertices.size()
		for vertex: int in range(vertices.size()):
			var position := Vector3.ZERO
			for influence: int in range(influences):
				var at: int = vertex * influences + influence
				if weights[at] < .00001: continue
				var bind: int = joints[at]
				var bone: int = mesh.skin.get_bind_bone(bind)
				if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(bind))
				position += (skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vertices[vertex]) * weights[at]
			position = skeleton.to_global(position)
			if first:
				bounds = AABB(position, Vector3.ZERO)
				first = false
			else: bounds = bounds.expand(position)
	return bounds

func run() -> void:
	world = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	for _i in range(8): await physics_frame
	check("building with classroom cast ready", world.ready_for_test and world.classroom_cast != null)
	var room: Node3D = world.computer_portal.room
	room.set_active(true)
	var mrp: Node3D = room.mrp
	var robot: Node3D = world.classroom_cast.get_node("RobotRepair")
	check("MrP retains13-bone skeleton", mrp.skeleton.get_bone_count() == 13)
	check("MrP named clips remain available", mrp.animation.has_animation("Idle") and mrp.animation.has_animation("Welcome") and mrp.animation.has_animation("Guide"))
	check("MrP is idling in the purple room", mrp.animation.is_playing() and mrp.animation.current_animation == "Idle")
	check("robot retains17-bone skeleton", robot.skeleton.get_bone_count() == 17)
	check("robot keeps seven separate skinned modules", robot.parts.size() == 7)
	check("robot is face-up", robot.get_node("Model").global_basis.z.normalized().dot(Vector3.UP) > .999)
	var bounds_by_part: Dictionary = {}
	for id: String in robot.parts:
		var mesh: MeshInstance3D = robot.parts[id]
		check("robot skin attached "+id, mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == robot.skeleton)
		var actual: AABB = skin_bounds(mesh, robot.skeleton)
		bounds_by_part[id] = actual
		check("robot part rests on repair surface "+id, absf(actual.position.y - 5.863) < .008, actual)
		check("robot part fits repair tabletop "+id, actual.position.x >= -14.925 and actual.end.x <= -13.175 and actual.position.z >= .4 and actual.end.z <= 3.2, actual)
	var ids: Array = bounds_by_part.keys()
	for i: int in range(ids.size()):
		for j: int in range(i+1,ids.size()):
			check("dismantled modules separated "+ids[i]+" "+ids[j], not bounds_by_part[ids[i]].intersects(bounds_by_part[ids[j]]))
	var mrp_bounds := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in mrp.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		check("MrP skin attached "+str(mesh.name), mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == mrp.skeleton)
		var box: AABB = skin_bounds(mesh, mrp.skeleton)
		mrp_bounds = box if first else mrp_bounds.merge(box)
		first = false
	check("MrP fits below purple room ceiling", mrp_bounds.position.y > room.global_position.y and mrp_bounds.end.y < room.global_position.y+room.HEIGHT, mrp_bounds)
	var head: int = robot.skeleton.find_bone("head")
	var before: Transform3D = robot.skeleton.get_bone_global_pose(head)
	var before_mesh: AABB = skin_bounds(robot.parts.head,robot.skeleton)
	robot.skeleton.set_bone_pose_rotation(head, Quaternion(Vector3.UP,.12))
	robot.skeleton.force_update_all_bone_transforms()
	check("dismantled robot remains poseable", not before.is_equal_approx(robot.skeleton.get_bone_global_pose(head)))
	check("robot rig moves actual weighted head vertices", not before_mesh.is_equal_approx(skin_bounds(robot.parts.head,robot.skeleton)))
	print("CAST_RESULT checks=", checks, " failures=", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
