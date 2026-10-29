extends SceneTree
## Verify imported actors, world placement, collision and bounded animation work.
var checks: int = 0
var failures: int = 0
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ", label, " ", detail)

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for _i in range(10): await physics_frame
	var population: Node3D = world.population
	population.timer.stop()
	check("population ready in the real building", population.ready_for_test)
	check("sixteen ambient actors use four shared source scenes", population.actors.size() == 16 and population.resources.size() == 4)
	var areas: Dictionary = {}
	var meshes_by_model: Dictionary = {}
	for actor: StaticBody3D in population.actors:
		areas[actor.record.area] = int(areas.get(actor.record.area,0)) + 1
		check("retained skinned rig "+str(actor.name), actor.skeleton.get_bone_count() == 62 and actor.animation.has_animation("Idle_Neutral"))
		check("uniform human scale "+str(actor.name), is_equal_approx(actor.model.scale.x, actor.model.scale.y) and absf(actor.bind_bounds.size.y*actor.model.scale.y-float(actor.record.height)) < .001)
		var ground := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.1, actor.global_position-Vector3.UP*.1, 1)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ground)
		check("feet rest on expected floor "+str(actor.name), not hit.is_empty() and absf(hit.position.y-actor.global_position.y)<.002 and absf(actor.global_position.y-float(actor.record.position[1]))<.08, actor.global_position)
		var capsule := CapsuleShape3D.new()
		capsule.radius = .18
		capsule.height = float(actor.record.height)-.16
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform.origin = actor.global_position+Vector3.UP*(float(actor.record.height)*.5+.02)
		query.collision_mask = 1
		var overlaps: Array[Dictionary] = world.get_world_3d().direct_space_state.intersect_shape(query)
		check("body clears retained walls and furniture "+str(actor.name), overlaps.is_empty(), overlaps.size())
		check("one static capsule on dedicated layer "+str(actor.name), actor.collision_layer == 8 and actor.get_node("PersonalSpace").shape is CapsuleShape3D and actor.get_children().filter(func(n: Node): return n is CollisionShape3D).size() == 1)
		var mesh_list: Array[Node] = actor.model.find_children("*", "MeshInstance3D", true, false)
		var skin_ok: bool = true
		var budget_ok: bool = true
		for mesh: MeshInstance3D in mesh_list:
			skin_ok = skin_ok and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == actor.skeleton
			if mesh.name == &"Pistol":
				check("optional weapon is hidden "+str(actor.name), not mesh.visible)
			else:
				budget_ok = budget_ok and mesh.visibility_range_end == 32.0 and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		check("skins attached "+str(actor.name), skin_ok)
		check("bounded visibility and shadows "+str(actor.name), budget_ok)
		var id: String = actor.record.model
		if meshes_by_model.has(id):
			check("instances share mesh resources "+str(actor.name), meshes_by_model[id] == mesh_list[0].mesh)
		else: meshes_by_model[id] = mesh_list[0].mesh
	check("population covers street, both floors, classroom, commons and a room", areas == {"street":4,"ground":2,"reception":2,"classroom":4,"commons":3,"hall_room":1}, areas)
	check("player collides with people but camera ignores them", (world.player.collision_mask & 8) == 8 and world.player.spring_arm.collision_mask == 1)
	# Exercise animation selection through actual camera and floor changes.
	world.player.teleport_to(Vector3(0,.02,6.7),0)
	for _i in range(4): await physics_frame
	population.update_budget()
	check("street idle work is capped", population.active_count > 0 and population.active_count <= 8, population.active_count)
	var upstairs_disabled: bool = true
	for actor: StaticBody3D in population.actors:
		if actor.global_position.y > 4: upstairs_disabled = upstairs_disabled and actor.model.process_mode == Node.PROCESS_MODE_DISABLED
	check("other floor has no idle processing", upstairs_disabled)
	world.player.teleport_to(Vector3(-8,5.07,-12),-PI/2)
	for _i in range(4): await physics_frame
	population.update_budget()
	check("nearby visible upstairs actors animate", population.active_count > 0 and population.active_count <= 8, population.active_count)
	var moving: StaticBody3D
	for actor: StaticBody3D in population.actors:
		if actor.animation_active: moving = actor; break
	if moving != null:
		var before: float = moving.animation.current_animation_position
		for _i in range(12): await physics_frame
		check("active idle time advances", not is_equal_approx(before,moving.animation.current_animation_position))
	else: check("active idle time advances", false)
	world.player.teleport_to(Vector3(0,40,0),0)
	for _i in range(3): await physics_frame
	population.update_budget()
	check("all distant skeletons and animations pause", population.active_count == 0 and population.actors.all(func(a: StaticBody3D): return a.model.process_mode == Node.PROCESS_MODE_DISABLED))
	var stopped: float = moving.animation.current_animation_position if moving != null else 0.0
	for _i in range(12): await physics_frame
	check("paused animation time stays fixed", moving != null and is_equal_approx(stopped,moving.animation.current_animation_position))
	print("POPULATION_RESULT checks=",checks," failures=",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
