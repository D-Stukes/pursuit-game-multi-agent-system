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

func blocked(label: String, target: Vector3, axis: int, boundary: float, maximum: bool) -> void:
	world.player.set_controls_active(true)
	var direction: Vector3 = target-world.player.global_position
	world.player.camera_pivot.rotation.y = atan2(-direction.x,-direction.z)
	Input.action_press("walk_forward")
	await frames(100)
	Input.action_release("walk_forward")
	await frames(10)
	var coordinate: float = world.player.global_position[axis]
	check(label,(coordinate<boundary if maximum else coordinate>boundary) and world.player.is_on_floor(),world.player.global_position)

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
	var desk: MeshInstance3D = layout.root.get_node("Ground check-in desk body")
	var desk_bounds: AABB = desk.global_transform*desk.get_aabb()
	check("ground check-in desk matches requested marker and floor",absf(desk_bounds.get_center().x-.62)<.001 and absf(desk_bounds.get_center().z-.40)<.001 and absf(desk_bounds.position.y-.006)<.001)
	check("all requested source meshes resolve",layout.missing.is_empty())
	check("all original classroom props reused",layout.retained.get("classroom")==646)
	check("bank assemblies reused except four rebuilt floor plates",layout.retained.get("bank")==235 and layout.retained.get("bank_trim")==3)
	check("classroom matches large left room floor area",absf(layout.CLASSROOM.get_area()-layout.GROUND_LEFT.get_area())<.1)
	var protected_ok: bool = true
	for mesh: MeshInstance3D in world.get_node("Building").find_children("*","MeshInstance3D",true,false):
		if layout.original_transforms.has(String(mesh.name)):
			protected_ok = protected_ok and mesh.global_transform.is_equal_approx(layout.original_transforms[String(mesh.name)])
	check("ground core and banks keep source world transforms",protected_ok)
	var bottom_rails_ok: bool = layout.retained.get("door_trim")==2
	for mesh: MeshInstance3D in world.get_node("Building").find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("layout_source_kind","")!="door_trim": continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		bottom_rails_ok = bottom_rails_ok and bounds.position.z>4.7 and bounds.end.z<6.3
	check("street door bottom rails remain at their hinges",bottom_rails_ok)
	var classroom_bin_inside: bool = true
	for mesh: MeshInstance3D in world.get_node("Building").find_children("*","MeshInstance3D",true,false):
		if layout.key(String(mesh.name)) not in [layout.key("Classroom | Classroom bin"),layout.key("Classroom | Bin lid")]: continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		classroom_bin_inside = classroom_bin_inside and layout.CLASSROOM.encloses(Rect2(bounds.position.x,-bounds.end.z,bounds.size.x,bounds.size.z))
	check("classroom bin stays inside classroom clear of reception door",classroom_bin_inside)
	var bin_clear: bool = true
	for bin_mesh: MeshInstance3D in world.get_node("Building").find_children("*","MeshInstance3D",true,false):
		if layout.key(String(bin_mesh.name))!=layout.key("Classroom | Classroom bin"): continue
		var bin_bounds: AABB = bin_mesh.global_transform*bin_mesh.get_aabb()
		bin_clear = absf(bin_bounds.position.y-(layout.FLOOR+.008))<.003
		for other: MeshInstance3D in world.get_node("Building").find_children("*","MeshInstance3D",true,false):
			if other==bin_mesh or layout.key(String(other.name))==layout.key("Classroom | Bin lid") or other.get_meta("layout_source_kind","")!="classroom": continue
			var overlap: AABB = bin_bounds.intersection(other.global_transform*other.get_aabb())
			bin_clear = bin_clear and not (overlap.size.x>.002 and overlap.size.y>.002 and overlap.size.z>.002)
	check("bin rests on classroom floor clear of chairs and desks",bin_clear)
	for room: Rect2 in layout.SMALL_ROOMS:
		check("hall room stays reception-side of Hallway 1 end",room.position.x>=-6.2)
	var no_room_labels: bool = true
	for label: Label3D in world.get_node("Building").find_children("*","Label3D",true,false):
		no_room_labels = no_room_labels and not label.text.begins_with("ROOM")
	check("no generic ROOM labels",no_room_labels)
	var bathroom_join_closed: bool = true
	for x: float in [-2.41,-2.37,-2.33]:
		var join_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(x,10.95,6.5),p(x,11.4,6.5),1))
		bathroom_join_closed = bathroom_join_closed and not join_hit.is_empty()
	check("bathroom shaft join has no see-through slit",bathroom_join_closed)
	# Compare actual runtime mesh top faces at every sill, not only floor height.
	var meshes: Array[Node] = world.get_node("Building").find_children("*","MeshInstance3D",true,false)
	var reception_clear: bool = true
	for node: Node in meshes:
		var furnishing := node as MeshInstance3D
		if furnishing.get_meta("layout_source_kind","")!="reception": continue
		var bounds: AABB = furnishing.global_transform*furnishing.get_aabb()
		for wall: MeshInstance3D in layout.root.find_children("*","MeshInstance3D",true,false):
			if not (String(wall.name).contains("wall") or String(wall.name).begins_with("Reception front")): continue
			var overlap: AABB = bounds.intersection(wall.global_transform*wall.get_aabb())
			if overlap.size.x>.025 and overlap.size.y>.025 and overlap.size.z>.025:
				reception_clear = false
				print("RECEPTION_INTERSECTION ",furnishing.name," / ",wall.name," ",overlap)
	check("reception furniture clears solid walls and jambs",reception_clear)
	for node: Node in meshes:
		var sill := node as MeshInstance3D
		if not String(sill.name).replace("_"," ").ends_with("flush threshold"): continue
		var sill_box: AABB = sill.global_transform*sill.get_aabb()
		var clear: bool = true
		for other_node: Node in meshes:
			var other := other_node as MeshInstance3D
			if other==sill: continue
			var bounds: AABB = other.global_transform*other.get_aabb()
			if absf(bounds.end.y-sill_box.end.y)>.00001: continue
			var overlap: AABB = bounds.intersection(sill_box)
			if overlap.size.x>.00001 and overlap.size.z>.00001:
				clear = false
				print("SILL_OVERLAP ",sill.name," / ",other.name," ",overlap)
		check("metal sill has no coplanar floor "+String(sill.name),clear)
	for x: float in [-3.3,-2.3,2.3,3.3]:
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(x,-5.2,1.5),p(x,-4.6,1.5),1))
		check("street entrance sidelight closes facade "+str(x),not hit.is_empty())
	for height: float in [2.73,3.2,3.7,4.95]:
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(0,-5.2,height),p(0,-4.5,height),1))
		check("street entrance header closes facade "+str(height),not hit.is_empty())
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
	for side: float in [-1,1]:
		var corner_closed: bool = true
		var floor_joined: bool = true
		for depth: float in [-4.6,-4.4,-4.25]:
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(side*3.0,depth,1.5),p(side*3.7,depth,1.5),1))
			corner_closed = corner_closed and not hit.is_empty()
		for depth: float in [-4.64,-4.55,-4.42,-4.37]:
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(side*2.39,depth,.3),p(side*2.39,depth,-.1),1))
			floor_joined = floor_joined and not hit.is_empty() and absf(hit["position"].y)<.015
		check("entrance corner reveal closed "+str(side),corner_closed)
		check("entrance floor threshold joined "+str(side),floor_joined)
	var reception_panel_clear: bool = true
	for panel: MeshInstance3D in layout.root.find_children("Reception front sill*","MeshInstance3D",true,false):
		for jamb: MeshInstance3D in layout.root.find_children("Reception front jamb*","MeshInstance3D",true,false):
			var overlap: AABB = (panel.global_transform*panel.get_aabb()).intersection(jamb.global_transform*jamb.get_aabb())
			reception_panel_clear = reception_panel_clear and not (overlap.size.x>.00001 and overlap.size.y>.00001 and overlap.size.z>.00001)
	check("reception sill faces do not overlap jambs",reception_panel_clear)
	var frames_by_door: Dictionary = {}
	var bakery_posts: Array[MeshInstance3D] = []
	var bakery_rails: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in layout.root.find_children("*","MeshInstance3D",true,false):
		var label: String = mesh.get_meta("layout_label","")
		if label=="Bakery window jamb": bakery_posts.append(mesh)
		if label=="Bakery window rail": bakery_rails.append(mesh)
		var part: String = mesh.get_meta("door_piece","")
		if part.ends_with(" jamb") or part.ends_with(" head") or part.ends_with(" threshold"):
			var door: String = part.rsplit(" ",true,1)[0]
			if not frames_by_door.has(door): frames_by_door[door]=[]
			frames_by_door[door].append(mesh)
	var door_trim_clear: bool = not frames_by_door.is_empty()
	for door: String in frames_by_door:
		var parts: Array = frames_by_door[door]
		for i in range(parts.size()):
			for j in range(i+1,parts.size()):
				var overlap: AABB = (parts[i].global_transform*parts[i].get_aabb()).intersection(parts[j].global_transform*parts[j].get_aabb())
				door_trim_clear = door_trim_clear and not (overlap.size.x>.00001 and overlap.size.y>.00001 and overlap.size.z>.00001)
	check("closed door frame corners have no overlapping faces",door_trim_clear)
	var bakery_trim_clear: bool = bakery_posts.size()==2 and bakery_rails.size()==2
	for post: MeshInstance3D in bakery_posts:
		for rail: MeshInstance3D in bakery_rails:
			var overlap: AABB = (post.global_transform*post.get_aabb()).intersection(rail.global_transform*rail.get_aabb())
			bakery_trim_clear = bakery_trim_clear and not (overlap.size.x>.00001 and overlap.size.y>.00001 and overlap.size.z>.00001)
	check("bakery window rails meet jambs without overlapping faces",bakery_trim_clear)
	var shaft_side_closed: bool = true
	for x: float in [-2.1,-1.4,-.7,-.1]:
		for height: float in [5.4,6.5,8.5]:
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(x,10.7,height),p(x,11.3,height),1))
			shaft_side_closed = shaft_side_closed and not hit.is_empty() and hit["position"].z> -11.15
	check("upper cab steel side concealed by shaft wall",shaft_side_closed)
	var old_stub_clear: bool = true
	for depth: float in [10.5,10.7,10.85]:
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(.26,depth,6.4),p(-.3,depth,6.4),1))
		old_stub_clear = old_stub_clear and hit.is_empty()
	check("old upper pier projection removed from hall",old_stub_clear)
	var outer_door: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p(-5.8,8.35,2.1),p(-6.5,8.35,2.1),1))
	check("existing farther ground door stays closed",not outer_door.is_empty())
	if "--static-only" in OS.get_cmdline_user_args():
		await finish(); return
	if not await route("ground check-in approach",[p(0,-3,0),p(.62,-1.5,0)]):
		await finish(); return
	await blocked("small check-in desk blocks passage through its front",p(.62,.1,0),2,.65,false)
	if not await route("check-in desk right ramp bypass",[p(.62,-3,0),p(2.35,-3,0),p(2.35,4.8,.85),p(2.35,-3,0),p(0,-3,0),p(0,-6.7,0)]):
		await finish(); return
	if not await route("left street door approach",[p(-9.39,-6.7,0),p(-9.39,-5.62,0)]):
		await finish(); return
	await blocked("left street glazed door remains locked",p(-9.39,-3.8,0),2,4.75,false)
	if not await route("right street door approach",[p(-9.39,-6.7,0),p(9.39,-6.7,0),p(9.39,-5.62,0)]):
		await finish(); return
	await blocked("right street glazed door remains locked",p(9.39,-3.8,0),2,4.75,false)
	if not await route("return to Pursuit entrance",[p(9.39,-6.7,0),p(0,-6.7,0)]):
		await finish(); return
	if not await route("ground entrance/ramp",[p(0,-3,0),p(2.35,-3,0),p(2.35,4.8,.85),p(2.35,5.7,.85)]):
		await finish(); return
	if not await route("near brown-room door approach",[p(-.5,5.7,.85),p(-.5,8.27,.85),p(-2.6,8.27,.85)]):
		await finish(); return
	await blocked("near brown-room door remains locked",p(-4,8.27,.85),0,-3.15,false)
	if not await route("bakery window approach",[p(-.5,8.27,.85),p(-.5,5.7,.85),p(2.35,5.7,.85),p(2.35,8.35,.85)]):
		await finish(); return
	await blocked("fixed bakery window blocks character",p(5,8.35,.85),0,3.2,true)
	if not await route("return to brown L",[p(2.35,8.35,.85),p(2.35,5.7,.85)]):
		await finish(); return
	if not await route("ground brown L and lift",[p(-.5,5.7,.85),p(-.5,8.35,.85),p(-2.6,8.35,.85),p(-.5,8.35,.85),p(-.5,5.7,.85),p(2.35,5.7,.85),p(2.35,12.1,.85),world.LIFT_GROUND]):
		await finish(); return
	var started: bool = world.try_lift()
	check("actual character takes elevator up",started)
	if not started: await finish(); return
	await world.lift_finished
	await frames(15)
	check("upper arrival stops at requested short walk-out",world.player.global_position.distance_to(world.UPPER_LIFT_EXIT)<.1)
	if not await route("arrival to opposite door approach",[p(2.7,12.1)]):
		await finish(); return
	await blocked("opposite locked door blocks character",p(6,12.1),0,4.83,true)
	if not await route("landing end window approach",[p(2.7,12.1),p(2.7,16.1)]):
		await finish(); return
	await blocked("landing window prevents entry beside last lift",p(2.7,17.3),2,-16.72,false)
	if not await route("return to elevator arrival",[p(2.7,16.1),p(2.7,12.1)]):
		await finish(); return
	world.player.camera_pivot.rotation.y = -PI/2
	world.player.apply_look(Vector2(PI/(2*world.player.SENSITIVITY),0))
	var flat_forward: Vector3 = -world.player.camera_pivot.global_basis.z
	flat_forward.y = 0
	check("player right turn faces reception",flat_forward.normalized().dot(Vector3.BACK)>.999)
	if not await route("reception and direct classroom",[p(2.7,7.9),p(2.7,7.35),p(.38,7.35),p(.38,6.15),p(.38,4.8),p(.38,1.23),p(-8.1,1.23),p(.38,1.23),p(.38,4.8),p(.38,6.15),p(.38,7.35),p(2.7,7.35),p(2.7,7.9)]):
		await finish(); return
	if not await route("locked reception side door approach",[p(2.7,7.35),p(4.5,7.35),p(4.5,7.9)]):
		await finish(); return
	await blocked("reception side room remains locked",p(7.5,7.9),0,5.19,true)
	if not await route("return from locked reception side room",[p(4.5,7.9),p(4.5,7.35),p(2.7,7.35),p(.38,7.35),p(.38,6.2)]):
		await finish(); return
	if not await route("first locked hall room approach",[p(-2.55,6.2)]):
		await finish(); return
	await blocked("hall room 2 remains locked",p(-2.55,8),2,-7.0,false)
	if not await route("second locked hall room approach",[p(-2.55,6.2),p(-5.05,6.2)]):
		await finish(); return
	await blocked("hall room 1 remains locked",p(-5.05,8),2,-7.0,false)
	if not await route("return from locked hall rooms",[p(-5.05,6.2)]):
		await finish(); return
	if not await route("unpartitioned open area and full length Hallway 2",[p(-8,6.2),p(-12,14),p(-20,14),p(-20,6.2),p(-20,-3.4),p(-20,6.2),p(-8,6.2),p(.38,6.2),p(.38,7.35),p(2.7,7.35),p(2.7,9.45)]):
		await finish(); return
	if not await route("bathroom 1 approach",[p(-5.35,9.45),p(-5.35,10.3)]):
		await finish(); return
	await blocked("bathroom 1 remains locked",p(-5.35,12.2),2,-11.2,false)
	if not await route("bathroom 2 approach",[p(-5.35,9.45),p(-3.5,9.45),p(-3.5,10.3)]):
		await finish(); return
	await blocked("bathroom 2 remains locked",p(-3.5,12.2),2,-11.2,false)
	if not await route("bathrooms return to lift",[p(-3.5,9.45),p(2.7,9.45),p(2.7,12.1),world.LIFT_UPPER]):
		await finish(); return
	started=world.try_lift()
	check("actual character takes elevator down",started)
	if started:
		await world.lift_finished
		await frames(15)
		check("ground return height",absf(world.player.global_position.y-.85)<.1)
	await finish()
