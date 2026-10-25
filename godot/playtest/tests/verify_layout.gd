extends SceneTree
## Continuous real-character route. Only the initial spawn is teleported.
var world: Node3D
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count): await physics_frame

func p(x: float, depth: float, height: float = 5.05) -> Vector3:
	return Vector3(x,height,-depth)

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check":label,"pass":passed,"detail":str(detail)})
	print("PASS " if passed else "FAIL ", label, " ",detail)

func walk(label: String, target: Vector3) -> bool:
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool = false
	for _i in range(750):
		var delta: Vector3 = target-world.player.global_position
		delta.y = 0
		if delta.length() < .16:
			arrived = true
			break
		world.player.camera_pivot.rotation.y = atan2(-delta.x,-delta.z)
		await physics_frame
	Input.action_release("walk_forward")
	await frames(10)
	var level: bool = absf(world.player.global_position.y-target.y)<.12 and world.player.is_on_floor()
	check(label, arrived and level,world.player.global_position)
	return arrived and level

func route(label: String, points: Array[Vector3]) -> bool:
	for i in range(points.size()):
		if not await walk(label+" "+str(i),points[i]): return false
	return true

func finish() -> void:
	var failures: int = 0
	for result in checks:
		if not result["pass"]: failures+=1
	var file := FileAccess.open("res://.godot/playtest/approved-layout-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"meshes":world.mesh_count,"triangles":world.collision_triangles},"  "))
	file.close()
	print("APPROVED_LAYOUT_CHECKS ",checks.size()," failures=",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func run() -> void:
	world = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(20)
	var layout: RefCounted = world.approved_layout
	check("all requested source meshes resolve",layout.missing.is_empty())
	check("all original classroom props reused",layout.retained.get("classroom")==646)
	check("both original bank assemblies reused",layout.retained.get("bank")==242)
	check("classroom matches large left room floor area",absf(layout.CLASSROOM.get_area()-layout.GROUND_LEFT.get_area())<.1)
	var protected_ok: bool = true
	for mesh: MeshInstance3D in world.get_node("Building").find_children("*","MeshInstance3D",true,false):
		if layout.original_transforms.has(String(mesh.name)):
			protected_ok = protected_ok and mesh.global_transform.is_equal_approx(layout.original_transforms[String(mesh.name)])
	check("ground core and banks keep source world transforms",protected_ok)
	for room: Rect2 in layout.SMALL_ROOMS:
		check("hall room stays reception-side of Hallway 1 end",room.position.x>=-6.2)
	# Capsules can bridge a narrow trench: inspect the actual floor through each
	# threshold as well as walking across it, and test the space behind cab 2.
	for edge_x: float in [-6.2,3.28]:
		var continuous: bool = true
		for i in range(15):
			var x: float = edge_x-.35+i*.05
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(x,8.35,1.2),p(x,8.35,.5),1))
			if hit.is_empty() or hit["position"].y<=.83:
				print("GROUND_FLOOR_GAP x=",x," hit=",hit)
			continuous = continuous and not hit.is_empty() and hit["position"].y>.83
		check("continuous ground doorway floor "+str(edge_x),continuous)
	if not await route("ground entrance/ramp",[p(0,-3,0),p(2.35,-3,0),p(2.35,4.8,.85),p(2.35,5.7,.85)]):
		await finish(); return
	if not await route("ground brown room and larger left room",[p(-.5,5.7,.85),p(-.5,8.35,.85),p(-4.3,8.35,.85),p(-7,8.35,.85),p(-7,6.8,.85),p(-10,6.8,.85),p(-16,8.35,.85),p(-10,6.8,.85),p(-7,6.8,.85),p(-7,8.35,.85),p(-4.8,8.35,.85),p(-4.8,14,.85),p(-4.8,8.35,.85),p(-.5,8.35,.85),p(-.5,5.7,.85),p(2.35,5.7,.85)]):
		await finish(); return
	if not await route("ground rear bank edge",[p(-.5,5.7,.85),p(-.5,8.35,.85),p(-4.8,8.35,.85),p(-4.8,16.35,.85),p(-1.2,16.35,.85),p(-1.2,17.0,.85),p(-1.2,16.35,.85),p(-4.8,16.35,.85),p(-4.8,8.35,.85),p(-.5,8.35,.85),p(-.5,5.7,.85),p(2.35,5.7,.85)]):
		await finish(); return
	if not await route("ground right room and lift",[p(2.35,8.35,.85),p(5,8.35,.85),p(13,8.35,.85),p(13,-3.4,.85),p(4.2,5.5,.85),p(4.2,16.9,.85),p(13,16.9,.85),p(13,8.35,.85),p(5,8.35,.85),p(2.35,8.35,.85),p(2.35,12.1,.85),world.LIFT_GROUND]):
		await finish(); return
	var started: bool = world.try_lift()
	check("actual character takes elevator up",started)
	if not started: await finish(); return
	await world.lift_finished
	await frames(15)
	check("upper arrival remains aligned",world.player.global_position.distance_to(p(2.7,12.1))<.1)
	world.player.apply_look(Vector2(PI/(2*world.player.SENSITIVITY),0))
	var flat_forward: Vector3 = -world.player.camera_pivot.global_basis.z
	flat_forward.y = 0
	check("player right turn faces reception",flat_forward.normalized().dot(Vector3.BACK)>.999)
	if not await route("reception and direct classroom",[p(2.7,7.9),p(2.7,7.35),p(.38,7.35),p(.38,6.15),p(.38,4.8),p(.38,1.23),p(-8.1,1.23),p(.38,1.23),p(.38,4.8),p(.38,6.15),p(.38,7.35),p(2.7,7.35),p(2.7,7.9)]):
		await finish(); return
	if not await route("separate room to front boundary",[p(2.7,7.35),p(4.5,7.35),p(4.5,7.9),p(7.5,7.9),p(12,7.9),p(12,1),p(12,-3.4),p(17,-3.4),p(12,-3.4),p(12,7.9),p(5.65,7.9)]):
		await finish(); return
	if not await route("additional room between classroom and separate room",[p(5.65,6.2),p(5.65,4.5),p(5.65,-3.4),p(5.65,4.5),p(5.65,6.2),p(7.5,7.9),p(4.5,7.9),p(4.5,7.35),p(2.7,7.35),p(.38,7.35),p(.38,6.2)]):
		await finish(); return
	if not await route("two rooms near reception",[p(-2.55,6.2),p(-2.55,8.0),p(-2.55,6.2),p(-5.05,6.2),p(-5.05,8.0),p(-5.05,6.2)]):
		await finish(); return
	if not await route("unpartitioned open area and full length Hallway 2",[p(-8,6.2),p(-12,14),p(-20,14),p(-20,6.2),p(-20,-3.4),p(-20,6.2),p(-8,6.2),p(.38,6.2),p(.38,7.35),p(2.7,7.35),p(2.7,9.45)]):
		await finish(); return
	if not await route("short Hallway 1 and both bathrooms",[p(-5.35,9.45),p(-5.35,12.2),p(-5.35,9.45),p(-3.5,9.45),p(-3.5,12.2),p(-3.5,9.45),p(2.7,9.45),p(2.7,12.1),world.LIFT_UPPER]):
		await finish(); return
	started=world.try_lift()
	check("actual character takes elevator down",started)
	if started:
		await world.lift_finished
		await frames(15)
		check("ground return height",absf(world.player.global_position.y-.85)<.1)
	await finish()
