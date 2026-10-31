extends SceneTree
## Everyday NPC life: places, choices, walking on the baked floor, props and pauses.
const Life = preload("res://game/characters/NPCLife.gd")
var world: Node3D
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame
func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label," ",detail)

func straight(from: Vector3, to: Vector3) -> PackedVector3Array:
	return PackedVector3Array([from,to])

func place(id: String, action: String, at: Vector3) -> Dictionary:
	return {"id":id,"area":"upper","action":action,"position":at,"face":at+Vector3.FORWARD,"seconds":[2,2]}

func run_life(life: RefCounted, position: Vector3, seconds: float) -> Vector3:
	var step: float = 1.0/30
	for _i: int in range(int(seconds/step)):
		var decision: Dictionary = life.decide(position,step,true)
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

func run() -> void:
	unit_checks()
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
		var home: Vector3 = Vector3(-3.2,0,6.7) if record.area=="street" else Vector3(1.6,5.05,-12.1)
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
	var mover: CharacterBody3D = upper[0]
	world.set_menu_open(true);var frozen: Vector3 = mover.global_position;await frames(120)
	check("Settings freezes everyday life",mover.global_position.distance_to(frozen)<.01)
	world.set_menu_open(false);await frames(4)
	Engine.time_scale = 1
	var after: Dictionary = world.orchestrator.snapshot()
	check("everyday life never touches gates or course",after.gates==initial.gates and after.course==initial.course and after.skipped==initial.skipped)
	check("everyday life makes no provider requests",social.requests_started==0)
	var errand: Array[Vector3] = population.travel.routed(Vector3(-7.9,5.05,-11.3),population.travel.upper_path())
	check("errands from the kitchen route around walls first",errand.size()>population.travel.upper_path().size()+1 and errand.all(func(point: Vector3): return absf(point.y-5.05)<.01))
	check("Developer Tools lists every everyday person",population.people_summary().size()==4)
	check("reasons are readable for the developer view",lives.all(func(actor: CharacterBody3D): return not str(actor.routine.reason).is_empty()))
	world.queue_free();await process_frame
	print("NPC_LIFE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
