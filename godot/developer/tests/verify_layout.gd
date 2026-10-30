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
	world=load("res://Main.tscn").instantiate();root.add_child(world)
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
	for z: float in [-.24,1.0,2.2]:
		check("extended robot area has walkable floor "+str(z),not cast(Vector3(-16.2,5.3,z),Vector3(-16.2,4.9,z)).is_empty())
	check("plant no longer blocks the central aisle",cast(Vector3(-9.62,5.4,.34),Vector3(-8.5,5.4,.34)).is_empty())
	for portal:Dictionary in manifest.portals:
		var center:Vector3=world.approved_layout.anchor(portal.anchor)
		var normal:Vector3=point(portal.normal)
		var tangent:Vector3=normal.cross(Vector3.UP).normalized()
		if portal.kind=="door":
			var prefix:String=portal.mesh_prefix
			check("physical frame retained "+portal.id,building.find_children(prefix+"_jamb*","MeshInstance3D",true,false).size()==2 and building.find_children(prefix+"_head","MeshInstance3D",true,false).size()==1)
			var leaf_pattern:String=prefix+("_closed_leaf*" if portal.closed else "_open_leaf_glass*")
			check("visible leaf retained "+portal.id,not building.find_children(leaf_pattern,"MeshInstance3D",true,false).is_empty())
		if portal.closed:
			check("closed blueprint door "+portal.id,not cast(center+Vector3.UP*1.2-normal*.3,center+Vector3.UP*1.2+normal*.3).is_empty())
			continue
		for height:float in [.5,1.6,2.2]:
			var clear:bool=true
			for offset:float in [-.25,0,.25]:
				var p:Vector3=center+Vector3.UP*height+tangent*offset
				clear=clear and cast(p-normal*.3,p+normal*.3).is_empty()
			check("doorway "+portal.id+" clear at "+str(height),clear)
	# Original ramp hallway: straight forward, with both right-facing cab doors
	# on its left. These probes are specified from the approved blueprint.
	for depth:float in [6.6,8.0,9.4,10.8,12.1,15.7]:
		var hit:Dictionary=cast(Vector3(2.35,1.1,-depth),Vector3(2.35,.6,-depth))
		check("original hallway floor "+str(depth),not hit.is_empty() and absf(hit.position.y-.85)<.03)
	check("ramp hallway continues forward",cast(Vector3(2.35,2.35,-6.6),Vector3(2.35,2.35,-15.7)).is_empty())
	check("original lower bank coordinate",world.LIFT_GROUND.is_equal_approx(Vector3(-.95,.85,-12.1)))
	check("original upper bank coordinate",world.LIFT_UPPER.is_equal_approx(Vector3(-.95,5.05,-12.1)))
	for level:float in [.85,5.05]:
		for depth:float in [12.1,15.1]:
			check("right-facing cab opening "+str(level)+" "+str(depth),cast(Vector3(.5,level+1.2,-depth),Vector3(-.5,level+1.2,-depth)).is_empty())
	var lower:Dictionary=cast(world.LIFT_GROUND+Vector3.UP*.4,world.LIFT_GROUND-Vector3.UP*.2)
	var upper:Dictionary=cast(world.LIFT_UPPER+Vector3.UP*.4,world.LIFT_UPPER-Vector3.UP*.2)
	check("aligned cab floors retain 4.2m offset",not lower.is_empty() and not upper.is_empty() and absf(upper.position.y-lower.position.y-4.2)<.02)
	check("right-turn view reaches reception",cast(Vector3(1.05,6.6,-12.1),Vector3(1.05,6.6,-7.5)).is_empty())
	check("opposite white door stays closed",not cast(Vector3(1.05,6.6,-12.1),Vector3(5.2,6.6,-12.1)).is_empty())
	check("Hallway1 ends beside bathrooms",not cast(Vector3(-5.9,6.6,-10),Vector3(-6.5,6.6,-10)).is_empty())
	check("Hallway2 joins open area without wall or door",cast(Vector3(-18,6.6,-6.2),Vector3(-18,6.6,-12)).is_empty())
	# The approved wall couch occupies the strip at Y=4.1; measure the
	# continuous walking aisle beyond it and verify seating remains solid.
	check("wall couch retains physical collision",not cast(Vector3(-14.5,5.55,-4.1),Vector3(-1.5,5.55,-4.1)).is_empty())
	for depth:float in [5.1,5.7,6.5]:
		for height:float in [.5,1.6,2.2]:
			check("widened Hallway2 clear "+str(depth)+" "+str(height),cast(Vector3(-14.5,5.05+height,-depth),Vector3(-1.5,5.05+height,-depth)).is_empty())
	check("reception central floor stays open across width",cast(Vector3(-.5,6.6,-5.8),Vector3(6.7,6.6,-5.8)).is_empty())
	check("reception central floor has added depth",cast(Vector3(1.05,6.6,-4.5),Vector3(1.05,6.6,-8.2)).is_empty())
	# Review regressions: raised tenant floors must reach their actual walls,
	# and adjacent small-room walls must not leave a full-height see-through slit.
	for feet:Vector3 in [Vector3(4.5,.85,2.8),Vector3(4.5,.85,-1.6),Vector3(10.5,.85,-8),Vector3(-21,.85,4.3),Vector3(-21,.85,-16.5),Vector3(-22.8,.85,-8),Vector3(-4.6,.85,-4.7),Vector3(-5,.85,2)]:
		var support:Dictionary=cast(feet+Vector3.UP*.25,feet-Vector3.UP*.25)
		check("raised wing floor reaches perimeter "+str(feet),not support.is_empty() and absf(support.position.y-.85)<.03)
	for height:float in [.5,1.6,2.2]:
		check("no slit between hallway rooms "+str(height),not cast(Vector3(-3.8,5.05+height,-6.6),Vector3(-3.8,5.05+height,-9.3)).is_empty())
	var end_window:Array[Node]=building.find_children("Landing_end_window_glass*","MeshInstance3D",true,false)
	check("landing end window is on exterior plane",end_window.size()==1 and absf(end_window[0].global_position.z+17.4)<.001)
	check("island plinth closes floor support gap",not cast(Vector3(-9.72,5.09,-13),Vector3(-9.22,5.09,-13)).is_empty())
	for prefix: String in ["Commons_couch_main_foot","Commons_armchair_one_foot"]:
		var feet: Array[Node]=building.find_children(prefix+"*","MeshInstance3D",true,false)
		var grounded: bool=feet.size()==4
		for foot: MeshInstance3D in feet:
			var box: AABB=foot.global_transform*foot.get_aabb()
			var center: Vector3=box.get_center()
			grounded=grounded and absf(box.position.y-5.05)<.015 and not cast(center-Vector3.RIGHT*.08,center+Vector3.RIGHT*.08).is_empty()
		check("new lounge furniture feet reach the floor "+prefix,grounded)
	for access:Dictionary in manifest.locked_access:
		var door_center:Vector3=world.approved_layout.anchor(access.anchor)
		var normal:Vector3=point(access.normal)
		for height:float in [.5,1.2,2.1]:
			check("locked access "+access.id+" "+str(height),not cast(door_center+Vector3.UP*height-normal*.6,door_center+Vector3.UP*height+normal*.6).is_empty())
	for level:float in [.85,5.05]:
		for height:float in [.5,1.5,2.2]:
			check("sealed bank interstitial "+str(level)+" "+str(height),not cast(Vector3(-3,level+height,-13.59),Vector3(-1,level+height,-13.59)).is_empty())
	var bench:Array[Node]=building.find_children("Landing_bench","MeshInstance3D",true,false)
	check("bench against opposite wall",bench.size()==1 and absf(bench[0].global_position.x-4.665)<.01 and absf(bench[0].global_position.z+15.52)<.01)
	var counter:Dictionary=cast(Vector3(-7.6,5.6,-9.49),Vector3(-6.7,5.6,-9.49))
	check("kitchen reaches confirmed marker",not counter.is_empty() and absf(counter.position.x+7.22)<.04)
	for prefix:String in ["Opposite_roof_pavilion","Kitchen_charcoal_backing","Reception_egg_chair_shell","Reception_neon_orbit","Commons_clothes_rack_bar"]:
		check("photo finish landmark "+prefix,not building.find_children(prefix+"*","MeshInstance3D",true,false).is_empty())
	for x:float in [-2.45,-1.0,.10]:
		for depth:float in [11.05,13.5,16.5]:
			check("no unsupported bank-end floor "+str(x)+" "+str(depth),not cast(Vector3(x,5.3,-depth),Vector3(x,4.8,-depth)).is_empty())
	# Sample facade joints and the formerly open window-head band at eye level
	# and above it. The entrance below its transom is the sole intended opening.
	var leaks:int=0
	for i in range(191):
		var x:float=-22.75+i*.25
		for h:float in [1.5,3.5,4.8,6.6,8.8,9.0,10.0,13.2,14.0,17.4]:
			if absf(x)<1.71 and h<2.7:continue
			if cast(Vector3(x,h,5.2),Vector3(x,h,4.4)).is_empty():leaks+=1
	check("continuous occupied facade across sampled bays and heads",leaks==0,leaks)
	print("LAYOUT_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
