extends SceneTree
## Check the actual six-sided room, floor, camera space and retained Mr P rig.
var checks: int = 0
var failures: int = 0
var room: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ",label," ",detail)

func frames(count: int) -> void:
	for _i in range(count): await physics_frame

func walk_to(target: Vector3) -> bool:
	player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool = false
	for _i in range(180):
		var delta: Vector3 = target-player.global_position
		delta.y = 0
		if delta.length() < .16:
			arrived = true
			break
		player.camera_pivot.rotation.y = atan2(-delta.x,-delta.z)
		await physics_frame
	Input.action_release("walk_forward")
	await frames(6)
	return arrived and player.is_on_floor()

func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	room = load("res://scenes/PurpleRoom.tscn").instantiate()
	holder.add_child(room)
	check("room rests inactive until used", not room.visible and room.mrp.process_mode == Node.PROCESS_MODE_DISABLED)
	room.set_active(true)
	player = load("res://game/BuildingPlayer.gd").new()
	holder.add_child(player)
	player.teleport_to(room.spawn.global_position)
	await frames(15)
	check("compact room has six enclosure walls", room.get_node("Shell").get_children().filter(func(n: Node):return str(n.name).begins_with("Wall")).size() == 6)
	check("six preview question boards match the reference layout", room.panels.size() == 6)
	check("Mr P keeps the original13-joint rig and Idle clip", room.mrp.skeleton.get_bone_count() == 13 and room.mrp.animation.current_animation == "Idle")
	check("player arrives supported on floor", player.is_on_floor() and absf(player.global_position.y)<.1, player.global_position)
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	for i: int in range(18):
		var angle: float = TAU*i/18.0
		var radial := Vector3(cos(angle),0,sin(angle))
		var floor_point: Vector3 = radial*3.5
		var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*.2,floor_point-Vector3.UP*.3,1))
		check("hex floor is continuous at sector "+str(i),not floor_hit.is_empty() and absf(floor_hit.position.y)<.002)
		for y: float in [.03,1.2,3.76]:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,y,0),radial*6+Vector3.UP*y,1))
			check("enclosure closes sector "+str(i)+" at "+str(y),not hit.is_empty() and Vector2(hit.position.x,hit.position.z).length()<4.75)
	var roof_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1,3.5,1),Vector3(1,4.2,1),1))
	check("room has a physical ceiling",not roof_hit.is_empty() and absf(roof_hit.position.y-3.8)<.002)
	var camera_local: Vector3 = room.to_local(player.camera.global_position)
	check("third-person camera is below ceiling and above floor",camera_local.y>.1 and camera_local.y<3.7,camera_local)
	for i: int in range(6):
		var normal := Vector3(sin(TAU*i/6.0),0,cos(TAU*i/6.0))
		check("camera stays inside wall plane "+str(i),normal.dot(camera_local)<3.97)
	for target: Vector3 in [Vector3(1.8,0,.8),Vector3(1.5,0,-2),Vector3(-.2,0,-2.2),Vector3(2.6,0,.7),Vector3(0,0,1)]:
		check("player can walk around Mr P to "+str(target),await walk_to(target),player.global_position)
	player.teleport_to(room.spawn.global_position)
	await frames(10)
	var query := PhysicsRayQueryParameters3D.create(Vector3(-1.7,1.3,1),Vector3(-1.7,1.3,-1.5),8)
	check("Mr P has personal-space collision",not space.intersect_ray(query).is_empty())
	check("idle room work can be suspended",room.mrp.animation.is_playing())
	room.set_active(false)
	var before: float = room.mrp.animation.current_animation_position
	await frames(6)
	check("inactive room hides models and pauses the rig",not room.visible and is_equal_approx(before,room.mrp.animation.current_animation_position))
	print("PURPLE_ROOM_RESULT checks=",checks," failures=",failures)
	holder.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
