extends SceneTree
## Walk the newly opened spaces against the actual imported mesh collision.

var world: Node3D
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func walk_to(target: Vector3) -> bool:
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool = false
	for _i in range(300):
		var difference: Vector3 = target - world.player.global_position
		difference.y = 0
		if difference.length() < 0.16:
			arrived = true
			break
		world.player.camera_pivot.rotation.y = atan2(-difference.x, -difference.z)
		await physics_frame
	Input.action_release("walk_forward")
	await frames(12)
	return arrived and world.player.is_on_floor() and absf(world.player.global_position.y-target.y) < 0.12

func run() -> void:
	world = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(12)
	var routes: Array[Dictionary] = [
		{"name": "furnished brown room to larger left area", "points": [Vector3(-.5,.85,-8.35),Vector3(-4.3,.85,-8.35),Vector3(-6,.85,-8.35),Vector3(-6,.85,-7)]},
		{"name": "extended elevator-side hall through exit door", "points": [Vector3(2.95,5.05,-7.2),Vector3(2.95,5.05,-4.3),Vector3(2.95,5.05,-2.3),Vector3(2.95,5.05,-1.3)]},
		{"name": "reception exit through passage into back room", "points": [Vector3(10.9,5.05,-15.7),Vector3(10.9,5.05,-17.1),Vector3(12.2,5.05,-17.1),Vector3(12.2,5.05,-18.7),Vector3(12.2,5.05,-19.8),Vector3(12.85,5.05,-20.3)]}
	]
	for route: Dictionary in routes:
		world.player.teleport_to(route["points"][0])
		await frames(20)
		for i in range(1,route["points"].size()):
			var passed: bool = await walk_to(route["points"][i])
			checks.append({"check":route["name"]+" "+str(i),"pass":passed,"feet":str(world.player.global_position)})
			print("PASS " if passed else "FAIL ",checks.back())
	var failures: int = 0
	for check: Dictionary in checks:
		if not check["pass"]:
			failures += 1
	var file := FileAccess.open("res://.godot/playtest/interior-routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"meshes":world.mesh_count},"  "))
	file.close()
	print("INTERIOR_ROUTES checks=",checks.size()," failures=",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
