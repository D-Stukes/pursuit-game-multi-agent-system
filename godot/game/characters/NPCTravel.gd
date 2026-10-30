extends Node
## Authored cross-floor errands. Uses the same elevator anchors and physical floors.
var world: Node3D
var population: Node3D
var trips: Dictionary={}
var cooldowns: Dictionary={"ReceptionA":38.0,"ReceptionB":12.0}
var lift_actor: String=""
var rides_completed: int=0

func unlocked() -> bool:
	return world.orchestrator.gate_passed("entrance") and world.orchestrator.gate_passed("elevator") and not world.building_review_mode

func active(actor: Node3D) -> bool:return trips.has(str(actor.name))

func request(actor: CharacterBody3D) -> bool:
	var id: String=str(actor.name)
	if not unlocked() or id not in cooldowns or not trips.is_empty():return false
	trips[id]={"actor":actor,"home":actor.global_position,"phase":"outbound","path":upper_path(),"index":0,"remaining":0.0,"floor":5.05}
	actor.routine.started=true
	return true

func upper_path() -> Array[Vector3]:
	return [Vector3(7.1,5.05,-5.7),Vector3(7.1,5.05,-7.5),Vector3(1.05,5.05,-7.5),world.UPPER_LIFT_EXIT,world.LIFT_UPPER]

func lower_path() -> Array[Vector3]:
	return [world.LOWER_LIFT_EXIT,Vector3(2.35,.85,-12.1),Vector3(2.35,.85,-9.4),Vector3(2.35,.85,-7.2)]

func update(delta: float, allowed: bool) -> void:
	if not unlocked():
		for trip: Dictionary in trips.values():
			trip.actor.global_position=trip.home
			trip.actor.visible=true;trip.actor.collision_layer=8
			trip.actor.play_clip("Idle_Neutral")
		trips.clear();lift_actor=""
		return
	if not allowed:return
	for actor: CharacterBody3D in population.actors:
		var id: String=str(actor.name)
		if id not in cooldowns:continue
		if not trips.has(id):
			cooldowns[id]-=delta
			if cooldowns[id]<=0 and actor.global_position.distance_to(world.player.global_position)>1.2:request(actor)
			continue
		var trip: Dictionary=trips[id]
		if actor.routine.talking:continue
		if trip.phase=="ride":
			trip.remaining-=delta
			if trip.remaining>0:continue
			var descending: bool=trip.floor>3
			var destination: Vector3=world.LIFT_GROUND if descending else world.LIFT_UPPER
			if destination.distance_to(world.player.global_position)<.8:continue
			actor.global_position=world.LIFT_GROUND if descending else world.LIFT_UPPER
			actor.visible=true;actor.collision_layer=8
			trip.floor=actor.global_position.y;rides_completed+=1;lift_actor=""
			if descending:
				trip.phase="ground_walk";trip.path=lower_path()
			else:
				trip.phase="home";trip.path=[world.UPPER_LIFT_EXIT,Vector3(1.05,5.05,-7.5),Vector3(7.1,5.05,-7.5),Vector3(7.1,5.05,-5.7),trip.home]
			trip.index=0;continue
		if trip.phase=="break":
			actor.play_clip("Interact");trip.remaining-=delta
			if trip.remaining<=0:
				trip.phase="return";trip.path=lower_path();trip.path.reverse();trip.path.append(world.LIFT_GROUND);trip.index=0
			continue
		if trip.index>=trip.path.size():
			if trip.phase in ["outbound","return"]:
				# Let the player finish a ride first; only one NPC reserves the cab.
				if world.lift_in_progress or not lift_actor.is_empty():continue
				lift_actor=id;trip.phase="ride";trip.remaining=1.1
				actor.visible=false;actor.collision_layer=0;actor.velocity=Vector3.ZERO
			elif trip.phase=="ground_walk":trip.phase="break";trip.remaining=7.0
			else:
				actor.play_clip("Idle_Neutral");trips.erase(id);cooldowns[id]=45.0
			continue
		if actor.global_position.distance_to(world.player.global_position)<.75:continue
		var target: Vector3=trip.path[trip.index]
		var difference: Vector3=target-actor.global_position;difference.y=0
		if difference.length()<.12:trip.index+=1;continue
		actor.move_to_target(target,1.25,delta)
