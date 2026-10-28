extends SceneTree
## Test the exported street and real held movement against both review limits.
var checks: int = 0
var failures: int = 0
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 5) -> void:
	for _i in range(count): await physics_frame

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ",label)

func cast(a: Vector3,b: Vector3,layer: int = 1) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,layer))

func run() -> void:
	world = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var limits: Dictionary = world.approved_layout.manifest.street_review_limits
	var player: CharacterBody3D = world.player
	world.set_building_review_mode(true)
	for side: int in [-1,1]:
		var x: float = float(limits.min_x if side<0 else limits.max_x)
		for depth: float in [5.1,6.55,15.0,23.0,24.15]:
			check("continuous invisible limit "+str(side)+" at "+str(depth),not cast(Vector3(x-side,2.3,depth),Vector3(x+side,2.3,depth),4).is_empty())
		for depth: float in [6.55,15.0,23.0]:
			player.teleport_to(Vector3(x-side*1.6,.03 if depth!=15.0 else -.17,depth),-PI/2 if side>0 else PI/2)
			await frames(12)
			player.set_controls_active(true)
			Input.action_press("walk_forward")
			Input.action_press("run")
			await frames(60)
			Input.action_release("walk_forward")
			Input.action_release("run")
			var inside: bool = player.global_position.x<x-.20 if side>0 else player.global_position.x>x+.20
			check("held run stays inside "+str(side)+" at "+str(depth),inside and player.is_on_floor())
		check("distant street has closed building backdrop "+str(side),not cast(Vector3(side*107,2.0,15),Vector3(side*110,2.0,15)).is_empty())
		for y: float in [-35,5]:
			var p:=Vector3(side*61,1,-y)
			var hit: Dictionary = cast(p,p-Vector3.UP*2)
			check("side street road continues "+str(side)+" at "+str(y),not hit.is_empty() and absf(hit.position.y+.20)<.03)
	var model: Node3D = world.get_node("Building")
	check("barricades are in shared exported model",not model.find_children("Review_barricade_board*","MeshInstance3D",true,false).is_empty())
	check("review bypass leaves street limits active",world.building_review_mode and world.entrance_gate.collision_layer==0 and world.find_children("StreetReviewBoundary*","StaticBody3D",true,false).size()==2)
	print("STREET_RESULT checks=",checks," failures=",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
