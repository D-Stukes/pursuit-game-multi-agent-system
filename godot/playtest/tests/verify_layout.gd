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
	# Shell closure regressions found by independent photo/code review. Test the
	# actual imported surfaces, rather than inferring closure from room bounds.
	for probe:Array in [
		["landing service pocket",Vector3(2.6,6.6,-9.3),Vector3(2.6,6.6,-11.5)],
		["commons rear corner",Vector3(-22.6,6.6,-7.8),Vector3(-22.6,6.6,-8.5)],
		["outer return south end",Vector3(-4.75,6.6,-3),Vector3(-4.75,6.6,-2)],
		["classroom west pocket",Vector3(5.2,6.6,0),Vector3(4.2,6.6,0)],
		["classroom far corner",Vector3(24.75,6.6,-5),Vector3(24.75,6.6,-6)],
		["rear service closure",Vector3(20,6.6,-10.7),Vector3(20,6.6,-11.3)]
	]:
		check("sealed "+probe[0],not cast(probe[1],probe[2]).is_empty())
	check("straight passage sightline into commons",cast(Vector3(2,6.6,-2.5),Vector3(-6.2,6.6,1.87)).is_empty())
	# Sample facade joints and the formerly open window-head band at eye level
	# and above it. The entrance below its transom is the sole intended opening.
	var leaks:int=0
	for i in range(191):
		var x:float=-22.75+i*.25
		for h:float in [1.5,3.5,4.8,6.6,8.8,9.0,10.0,13.2,14.0,17.4]:
			if absf(x)<1.71 and h<2.7:continue
			if cast(Vector3(x,h,5.2),Vector3(x,h,4.4)).is_empty():leaks+=1
	check("continuous occupied facade across sampled bays and heads",leaks==0,leaks)
	for y:float in [5.85,8.04]:
		check("landing end window sealed at "+str(y),not cast(Vector3(-22.7,6.7,-y),Vector3(-23.3,6.7,-y)).is_empty())
	for x:float in [-20.5,-19.6,-17.0,-14.5]:
		var support:Dictionary=cast(Vector3(x,5.3,-5.5),Vector3(x,4.8,-5.5))
		check("no pit beside cab at "+str(x),not support.is_empty())
	check("upper bank closed above lintel",not cast(Vector3(-17,8.4,-6.1),Vector3(-17,8.4,-5.3)).is_empty())
	check("right turn has straight reception approach",cast(Vector3(-15.5,6.6,-6.7),Vector3(-4.2,6.6,-6.7)).is_empty())
	print("LAYOUT_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
