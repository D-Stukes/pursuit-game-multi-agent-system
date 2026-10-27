extends SceneTree
## Physical interfaces of the exact shared export, separate from route/input tests.
var world:Node3D
var checks:int=0
var failures:int=0
func _initialize()->void:
	call_deferred("run")
func check(label:String,ok:bool,detail:Variant="")->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label," ",detail)
func cast(a:Vector3,b:Vector3)->Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func point(p:Array)->Vector3:
	return Vector3(float(p[0]),float(p[2]),-float(p[1]))
func run()->void:
	world=load("res://BuildingPlaytest.tscn").instantiate();root.add_child(world)
	for _i in range(8):await physics_frame
	check("shared assembly loaded",world.ready_for_test and world.mesh_count>4000)
	var manifest:Dictionary=world.approved_layout.manifest
	var building:Node3D=world.get_node("Building")
	for module:Dictionary in manifest.modules:
		var found:Array[Node]=building.find_children(module.id+"_ROOT","Node3D",true,false)
		check("module origin "+module.id,found.size()==1 and found[0].global_position.distance_to(point(module.origin))<.001)
	for id:String in manifest.anchors:
		var pos:Vector3=world.approved_layout.anchor(id)
		var hit:Dictionary=cast(pos+Vector3.UP*.25,pos-Vector3.UP*.2)
		check("walkable support at "+id,not hit.is_empty() and absf(hit.position.y-pos.y)<.1)
	for portal:Dictionary in manifest.portals:
		var center:Vector3=world.approved_layout.anchor(portal.anchor)
		var normal:Vector3=Vector3.FORWARD if portal.id in ["larger","hall"] else Vector3.RIGHT
		var tangent:Vector3=Vector3.RIGHT if normal==Vector3.FORWARD else Vector3.FORWARD
		for height:float in [.5,1.6,2.2]:
			var clear:bool=true
			for offset:float in [-.25,0,.25]:
				var p:Vector3=center+Vector3.UP*height+tangent*offset
				clear=clear and cast(p-normal*.3,p+normal*.3).is_empty()
			check("doorway "+portal.id+" clear at "+str(height),clear)
	# The outer restroom corridor must not silently connect to commons.
	check("outer corridor separated from commons",not cast(Vector3(-10,6.4,-9.1),Vector3(-10,6.4,-7.3)).is_empty())
	var lower:Dictionary=cast(world.LIFT_GROUND+Vector3.UP*.4,world.LIFT_GROUND-Vector3.UP*.2)
	var upper:Dictionary=cast(world.LIFT_UPPER+Vector3.UP*.4,world.LIFT_UPPER-Vector3.UP*.2)
	check("aligned cab floors retain 4.2m offset",not lower.is_empty() and not upper.is_empty() and absf(upper.position.y-lower.position.y-4.2)<.02)
	# Solid floor and photographic landmarks are part of the actual imported model.
	for prefix:String in ["Opposite_roof_pavilion","Kitchen_charcoal_backing","Reception_egg_chair_shell","Reception_neon_orbit","Donation_rack_bar"]:
		check("photo landmark "+prefix,not building.find_children(prefix+"*","MeshInstance3D",true,false).is_empty())
	print("LAYOUT_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
