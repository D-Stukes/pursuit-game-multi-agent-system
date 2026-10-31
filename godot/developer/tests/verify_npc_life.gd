extends "res://developer/tests/TestKit.gd"
## Everyday NPC life: places, choices, walking on the baked floor, props and pauses.
const Life = preload("res://game/characters/NPCLife.gd")
var world: Node3D
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame
func straight(from: Vector3, to: Vector3) -> PackedVector3Array:
	return PackedVector3Array([from,to])

func place(id: String, action: String, at: Vector3) -> Dictionary:
	return {"id":id,"area":"upper","action":action,"position":at,"face":at+Vector3.FORWARD,"seconds":[2,2]}

var rider_guarded: bool = false
func check_once_riding(rider: CharacterBody3D) -> void:
	if rider_guarded or rider.routine.phase != "ride": return
	rider.routine.interrupt()
	rider_guarded = not rider.routine.explore() and rider.routine.phase == "ride" and not rider.visible
	var line: String = Array(rider.get_parent().people_summary()).filter(func(text: String): return text.begins_with(str(rider.name)))[0]
	rider_guarded = rider_guarded and line.contains("riding the elevator")

func run_life(life: RefCounted, position: Vector3, seconds: float) -> Vector3:
	var step: float = 1.0/30
	for _i: int in range(int(seconds/step)):
		var decision: Dictionary = life.decide(position,step,true)
		if decision.get("teleport") is Vector3: position = decision.teleport
		if decision.speed > 0:
			var toward: Vector3 = decision.target-position;toward.y = 0
			position += toward.normalized()*minf(toward.length(),decision.speed*step)
	return position

func unit_checks() -> void:
	var actions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/npc-life.json")).actions
	var places: Array[Dictionary] = [place("coffee","coffee",Vector3(0,5,0)),place("desk","laptop",Vector3(6,5,0)),place("far","look",Vector3(30,5,0))]
	var claims: Dictionary = {}
	var open: Callable = func(_area: String): return true
	var life: RefCounted = Life.new("A",{"areas":["upper"],"likes":{"coffee":3,"laptop":1,"look":.2}},places,actions,claims,straight,open)
	life.rng.seed = 7
	check("life starts without a conversation",life.valid and life.started)
	var position: Vector3 = run_life(life,Vector3(3,5,3),4.5)
	check("favourite nearby place is chosen first",life.visits.size()>=1 and life.visits[0]=="coffee",life.visits)
	var holding: bool = false
	for _i: int in range(8):
		var decision: Dictionary = life.decide(position,.1,true)
		holding = holding or decision.prop=="cup"
	check("coffee ends holding a cup",holding)
	position = run_life(life,position,12)
	check("novelty moves on to other places",life.visits.size()>=2 and life.visits.has("desk"),life.visits)
	var other: RefCounted = Life.new("B",{"areas":["upper"],"likes":{"coffee":3,"laptop":1}},places,actions,claims,straight,open)
	life.place = places[0];claims["coffee"]="A"
	other.decide(Vector3.ZERO,.1,true)
	check("a claimed spot holds one person",other.place.get("id","")!="coffee",other.place.get("id",""))
	life.begin_conversation()
	var paused: Dictionary = life.decide(position,.1,true)
	check("talking pauses everyday life",paused.speed==0 and life.talking)
	life.end_conversation()
	check("conversation resumes without a reset",not life.talking and life.conversations==1 and life.started)
	check("explore heads for the farthest place",life.explore() and life.decide(position,.1,true).target.x>20 and life.place.id=="far")
	life.place = places[1];life.phase = "walk";life.path = PackedVector3Array([Vector3.ZERO,Vector3(6,5,0)])
	for _i: int in range(80): life.report_blocked(.1)
	check("a blocked path gives the spot up",life.phase=="choose" and life.avoid.has("desk"))
	var stranger: RefCounted = Life.new("C",{"areas":["street"],"likes":{"coffee":1}},places,actions,{},straight,open)
	check("people only use their own areas",not stranger.valid)
	var unreachable: RefCounted = Life.new("D",{"areas":["upper"],"likes":{"coffee":1}},places,actions,{},func(_a: Vector3,_b: Vector3): return PackedVector3Array(),open)
	unreachable.decide(Vector3(5,5,5),.1,true)
	check("unreachable places are skipped",unreachable.phase=="choose" and unreachable.avoid.has("coffee"))

func lift_checks() -> void:
	var actions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/npc-life.json")).actions
	var places: Array[Dictionary] = [place("upstairs","coffee",Vector3(4,5.05,0))]
	places[0].area = "upper"
	var points: Dictionary = {"lower":{"cab":Vector3(-1,0,0),"exit":Vector3(1,0,0),"wait":Vector3(1.5,0,-.7)},"upper":{"cab":Vector3(-1,5.05,0),"exit":Vector3(1,5.05,0),"wait":Vector3(1.5,5.05,-.7)}}
	var cab: Dictionary = {"holder":""}
	var reserve: Callable = func(who: String): if cab.holder in ["",who]: cab.holder = who; return cab.holder == who
	var release: Callable = func(who: String): if cab.holder == who: cab.holder = ""
	var clear: Dictionary = {"ok":false}
	var life: RefCounted = Life.new("R",{"areas":["upper","ground"],"likes":{"coffee":1}},places,actions,{},straight,func(_a: String): return true)
	life.use_lift(points,reserve,release,func(_f: String): return clear.ok)
	var position: Vector3 = Vector3(3,0,0)
	var hidden: bool = false
	var teleported: Vector3 = Vector3.INF
	for _i: int in range(200):
		var decision: Dictionary = life.decide(position,.05,true)
		if decision.has("hidden"): hidden = decision.hidden
		if decision.get("teleport") is Vector3: position = decision.teleport;teleported = decision.teleport
		if decision.speed > 0:
			var toward: Vector3 = decision.target-position;toward.y = 0
			position += toward.normalized()*minf(toward.length(),decision.speed*.05)
	check("an upstairs place sends a downstairs person to wait beside the elevator",life.riding_to=="upper" and life.rides==0 and cab.holder=="R" and hidden)
	check("the rider stays in the cab while the exit is blocked",life.phase=="ride" and teleported==points.lower.cab)
	clear.ok = true
	position = run_life(life,position,8)
	check("the rider steps out upstairs and walks to the place",life.rides==1 and cab.holder=="" and life.visits.has("upstairs") and absf(position.y-5.05)<.01,[life.phase,position])
	var second: RefCounted = Life.new("S",{"areas":["upper","ground"],"likes":{"coffee":1}},places,actions,{},straight,func(_a: String): return true)
	second.use_lift(points,reserve,release,func(_f: String): return true)
	cab.holder = "someone"
	run_life(second,Vector3(3,0,0),40)
	check("a busy cab makes others wait, then give up",cab.holder=="someone" and second.rides==0 and second.reason.contains("elevator"),second.reason)

func greeting_checks() -> void:
	var actions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/npc-life.json")).actions
	var places: Array[Dictionary] = [place("desk","laptop",Vector3(0,5,0))]
	places[0].seconds = [6,6]
	var life: RefCounted = Life.new("G",{"areas":["upper"],"likes":{"laptop":1}},places,actions,{},straight,func(_a: String): return true)
	check("no wave while walking",not life.greet(1.0))
	run_life(life,Vector3(0,5,0),.5)
	var left: float = life.remaining
	check("a standing person waves on first meeting",life.greet(1.0) and life.decide(Vector3(0,5,0),.1,true).animation=="Wave")
	run_life(life,Vector3(0,5,0),1.0)
	check("the wave pauses the action, then it carries on",life.wave_remaining==0 and absf(life.remaining-(left-.1))<.15 and life.decide(Vector3(0,5,0),.1,true).animation!="Wave",[left,life.remaining])
	check("they wave only once",not life.greet(1.0))

func face(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to-from
	return atan2(-d.x,-d.z)

func run() -> void:
	unit_checks()
	lift_checks()
	greeting_checks()
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	var population: Node3D = world.population
	var social: Node3D = world.npc_conversations
	social.cooldown = 999
	var initial: Dictionary = world.orchestrator.snapshot()
	var lives: Array[CharacterBody3D] = []
	for actor: CharacterBody3D in population.actors:
		if population.life_actor(actor): lives.append(actor)
	check("four everyday people; the Program Manager keeps its authored loop",lives.size()==4 and not population.life_actor(population.get_node("ClassroomTeaching")))
	var map: RID = world.get_world_3d().navigation_map
	var reachable: bool = true
	var snapped: bool = true
	for record: Dictionary in population.life_places:
		snapped = snapped and NavigationServer3D.map_get_closest_point(map,record.position).distance_to(record.position) < .2
		var home: Vector3 = {"street":Vector3(-3.2,0,6.7),"ground":Vector3(1.6,.85,-12.8),"upper":Vector3(1.6,5.05,-12.1)}[record.area]
		var route: PackedVector3Array = population.plan_path(home,record.position)
		reachable = reachable and not route.is_empty() and Life._flat(route[route.size()-1]-record.position) < .35
	check("every place stands on the baked floor",snapped)
	check("every place is reachable within its area",reachable)
	var keypad: Vector3 = world.entrance_keypad.global_position
	check("street places keep clear of the entrance keypad",population.life_places.all(func(record: Dictionary): return record.area!="street" or Life._flat(record.position-keypad)>1.5))
	world.player.teleport_to(Vector3(5,0,11))
	Engine.time_scale = 3
	await frames(600)
	check("street people start at their usual spots",lives.filter(func(actor: CharacterBody3D): return actor.global_position.y<3).all(func(actor: CharacterBody3D): return actor.routine.visits.size()>=1 and actor.routine.visits[0]==actor.routine.profile.home),lives.map(func(actor: CharacterBody3D): return actor.routine.visits))
	var street: Array[CharacterBody3D] = lives.filter(func(actor: CharacterBody3D): return actor.global_position.y < 3)
	check("street people walk and visit places without being spoken to",street.size()==2 and street.all(func(actor: CharacterBody3D): return actor.distance_walked>1 and actor.routine.arrivals>=1),street.map(func(actor: CharacterBody3D): return [actor.name,actor.distance_walked,actor.routine.visits]))
	check("feet stay on the street",street.all(func(actor: CharacterBody3D): return absf(actor.global_position.y)<.2))
	var upper: Array[CharacterBody3D] = lives.filter(func(actor: CharacterBody3D): return actor.global_position.y > 3)
	var parked: Array = upper.map(func(actor: CharacterBody3D): return actor.global_position)
	check("other floor waits while the player is away",upper.size()==2 and upper.all(func(actor: CharacterBody3D): return actor.distance_walked==0))
	world.player.teleport_to(Vector3(1.05,5.05,-7.6));await frames(1200)
	check("upstairs people roam several places once the player arrives",upper.all(func(actor: CharacterBody3D): return actor.routine.visits.size()>=2 and actor.distance_walked>3),upper.map(func(actor: CharacterBody3D): return [actor.name,actor.routine.visits]))
	check("upstairs feet stay on the upper floor",upper.all(func(actor: CharacterBody3D): return absf(actor.global_position.y-5.05)<.2))
	var spots: Array = lives.map(func(actor: CharacterBody3D): return actor.routine.place.get("id",""))
	check("no two people hold the same spot",spots.filter(func(id: String): return id!="").size()==Array(spots.filter(func(id: String): return id!="")).reduce(func(seen: Array,id: String): return seen if id in seen else seen+[id],[]).size(),spots)
	var rider: CharacterBody3D = upper[0]
	rider.routine.profile = rider.routine.profile.duplicate(true);rider.routine.profile.likes = {"snack":5}
	rider.routine.interrupt()
	var hid_in_cab: bool = false
	# Long enough for a retry if someone standing in a doorway makes them give up once.
	for _i: int in range(6000):
		await physics_frame
		if not rider.visible:
			# Leave the floor once the ride starts: the trip must finish without the player watching.
			if not hid_in_cab: world.player.teleport_to(Vector3(0,0,6.7))
			hid_in_cab = true
			check_once_riding(rider)
		if rider.routine.visits.size()>0 and rider.routine.visits[-1]=="ground_vending" and rider.routine.phase=="act": break
	check("a reception person rides down while the player is on another floor",hid_in_cab and rider.routine.rides>=1 and population.lift_actor.is_empty(),[rider.routine.phase,rider.routine.reason,rider.global_position])
	check("explore and interrupt cannot strand a rider",rider_guarded)
	check("they walk the ramp down to the vending machines",rider.routine.visits.has("ground_vending") and absf(rider.global_position.y)<.15 and rider.visible and rider.collision_layer==8,rider.global_position)
	# The player's own elevator waits while a person holds the cab.
	world.orchestrator.skip_gate("entrance");world.orchestrator.skip_gate("elevator")
	world.player.teleport_to(world.LOWER_LIFT_EXIT+Vector3(-.4,0,0));await frames(4)
	population.lift_actor = "SomeoneRiding"
	check("the player's elevator waits while someone rides",not world.try_lift())
	population.lift_actor = ""
	check("the player's elevator works once the cab is free",world.try_lift())
	while world.lift_in_progress: await physics_frame
	world.player.teleport_to(Vector3(1.05,5.05,-7.6));await frames(4)
	# Noticing: a standing person in front of the player turns their head, waves once; behind them, nothing.
	# People often face a desk or wall, so wait for someone standing with a clear, walkable spot in front.
	var watcher: CharacterBody3D = null
	var front: Vector3 = Vector3.INF
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for _i: int in range(2400):
		for person: CharacterBody3D in upper:
			if person.routine.phase!="act" or person.routine.remaining<3 or person.routine.greeted: continue
			var eyes: Vector3 = person.global_position+Vector3.UP*1.55
			for degrees: float in [0,30,-30,60,-60]:
				for reach: float in [2.0,1.6,2.6]:
					var spot: Vector3 = person.global_position+person.global_basis.z.rotated(Vector3.UP,deg_to_rad(degrees))*reach
					if space.intersect_ray(PhysicsRayQueryParameters3D.create(eyes,spot+Vector3.UP*1.55,1)).is_empty() and Life._flat(NavigationServer3D.map_get_closest_point(map,spot)-spot)<.15:
						front = spot;break
				if front.is_finite(): break
			if front.is_finite(): watcher = person;break
		if watcher != null: break
		await physics_frame
	check("found a clear spot in front of a standing person",front.is_finite())
	world.player.teleport_to(front,face(front,watcher.global_position));await frames(2)
	var waved: bool = false
	# Modifier output exists only during the skeleton update, so sample the head there.
	var sampled: Dictionary = {"head":Vector3.ZERO}
	var head: int = watcher.skeleton.find_bone("Head")
	var sample: Callable = func(): sampled.head = (watcher.skeleton.global_transform*watcher.skeleton.get_bone_global_pose(head)).basis.z.normalized()
	watcher.skeleton.skeleton_updated.connect(sample)
	for _i: int in range(40):
		await physics_frame
		waved = waved or watcher.current_clip=="Wave"
	watcher.skeleton.skeleton_updated.disconnect(sample)
	var head_forward: Vector3 = sampled.head
	var to_player: Vector3 = (world.player.global_position-watcher.global_position);to_player.y=0
	check("a person notices the player in front of them",watcher.attention is Vector3 and watcher.look.influence>.5)
	var body_forward: Vector3 = watcher.global_basis.z
	var head_dot: float = Vector3(head_forward.x,0,head_forward.z).normalized().dot(to_player.normalized())
	# Within about 70 degrees the head looks straight at the player; beyond that it turns as far as it can.
	check("their head turns toward the player",head_dot>.9 or head_dot>body_forward.dot(to_player.normalized())+.3,{"head":head_forward,"body":body_forward,"to_player":to_player.normalized(),"influence":watcher.look.influence,"animating":watcher.animation_active,"clip":watcher.current_clip,"phase":watcher.routine.phase})
	check("they wave on first meeting",waved and watcher.routine.greeted)
	var behind: Vector3 = watcher.global_position-watcher.global_basis.z*2.2
	watcher.routine.wave_remaining = 0
	world.player.teleport_to(behind,face(behind,watcher.global_position));await frames(3)
	check("nobody notices a player behind them",watcher.attention==null)
	world.player.teleport_to(Vector3(0,0,6.7));await frames(3)
	check("nobody notices a player on another floor",watcher.attention==null)
	# Passing: a walker stops for a player facing them, but steps around one who is not.
	var walker: CharacterBody3D = null
	world.player.teleport_to(Vector3(1.05,5.05,-7.6));await frames(2)
	for _i: int in range(1800):
		for person: CharacterBody3D in upper:
			if person.routine.phase=="walk" and person.routine.index<person.routine.path.size() and person.visible:
				var ahead: Vector3 = person.routine.path[person.routine.index]
				if Life._flat(ahead-person.global_position)>1.4: walker=person
		if walker!=null: break
		await physics_frame
	var ahead_point: Vector3 = walker.global_position+(walker.routine.path[walker.routine.index]-walker.global_position).normalized()*.6
	ahead_point.y = walker.global_position.y
	world.player.teleport_to(ahead_point,face(ahead_point,walker.global_position));await frames(2)
	var walked: float = walker.distance_walked;await frames(30)
	check("a walker stops for a player facing them",walker.distance_walked-walked<.05,walker.distance_walked-walked)
	world.player.teleport_to(world.player.global_position-Vector3.UP*.08,face(walker.global_position,ahead_point));await frames(2)
	walked = walker.distance_walked;await frames(60)
	check("a walker steps around a player looking away",walker.distance_walked-walked>.3,walker.distance_walked-walked)
	var mover: CharacterBody3D = upper[1]
	world.set_menu_open(true);var frozen: Vector3 = mover.global_position;await frames(120)
	check("Settings freezes everyday life",mover.global_position.distance_to(frozen)<.01)
	world.set_menu_open(false);await frames(4)
	Engine.time_scale = 1
	var after: Dictionary = world.orchestrator.snapshot()
	check("everyday life never touches gates or course",after.gates==initial.gates and after.course==initial.course and after.skipped==initial.skipped)
	check("everyday life makes no provider requests",social.requests_started==0)
	check("Developer Tools lists every everyday person",population.people_summary().size()==4)
	check("reasons are readable for the developer view",lives.all(func(actor: CharacterBody3D): return not str(actor.routine.reason).is_empty()))
	world.queue_free();await process_frame
	print("NPC_LIFE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
