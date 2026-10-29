extends SceneTree
const Pilot = preload("res://developer/tests/NPCTestPilot.gd")
const Routine = preload("res://game/characters/NPCRoutineState.gd")
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
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)
func run() -> void:
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	var social: Node3D = world.npc_conversations
	# Avoid timed public chatter while each individual route is being measured.
	social.cooldown=999
	var initial: Dictionary = world.orchestrator.snapshot()
	check("untouched actors have no active route",world.population.actors.all(func(actor: CharacterBody3D):return actor.routine.valid and not actor.routine.started and actor.distance_walked==0))
	for record: Dictionary in social.actors:
		var actor: CharacterBody3D = record.actor
		check("idle walk run wave and interaction retained "+record.id,["Idle_Neutral","Walk","Run","Wave","Interact"].all(func(clip: String):return actor.animation.has_animation(clip)))
		check("actual clear approach "+record.id,Pilot.approach(world,record.id).is_finite())
		await frames();await key(KEY_E)
		check("E pauses this actor for conversation "+record.id,social.active_npc==record.id and actor.routine.talking)
		var position_before: Vector3 = actor.global_position
		var others: Array[Vector3] = []
		for person: CharacterBody3D in world.population.actors: others.append(person.global_position)
		await frames(12)
		check("talking actor stays still "+record.id,actor.global_position.distance_to(position_before)<.005)
		var still: bool = true
		for index: int in range(others.size()): still=still and world.population.actors[index].global_position.distance_to(others[index])<.005
		check("conversation pauses every nearby routine "+record.id,still)
		await key(KEY_ESCAPE)
		check("Escape activates its own route "+record.id,actor.routine.started and actor.routine.conversations==1 and not actor.routine.talking and not world.player.controls_locked)
		world.go_location(1 if actor.global_position.y>4 else 0)
		await frames(110)
		check("authored first waypoint reached by physics "+record.id,actor.routine.arrivals>=1 and actor.distance_walked>.7,{"feet":actor.global_position,"distance":actor.distance_walked,"blocked":actor.blocked})
		check("feet stay on their supported floor "+record.id,absf(actor.global_position.y-float(actor.record.position[1]))<.03 and actor.supported_floor(actor.global_position))
		check("repeat conversation uses moving actor location "+record.id,Pilot.approach(world,record.id).is_finite())
		await frames();await key(KEY_E);await key(KEY_ESCAPE)
		check("every conversation resumes without clearing route "+record.id,actor.routine.conversations==2 and actor.routine.started)
	# Test a real obstruction across the Builder's authored segment.
	world.go_location(0);await frames()
	var builder: CharacterBody3D = world.population.get_node("StreetWestA")
	builder.global_position=Vector3(-3.2,0,6.7)
	builder.routine=Routine.new(builder.record.routine,builder.global_position);builder.routine.end_conversation()
	var wall:=StaticBody3D.new();wall.collision_layer=1;wall.position=Vector3(-3.75,1,6.7)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.15,2,1.2);collision.shape=box;wall.add_child(collision);world.add_child(wall)
	await frames(90)
	check("obstacle stops movement without teleporting or completing",builder.blocked and builder.global_position.x> -3.6 and builder.routine.arrivals==0,builder.global_position)
	var paused: Vector3 = builder.global_position
	world.set_menu_open(true);await frames(20)
	check("Settings freezes route and restores input ownership",builder.global_position.distance_to(paused)<.001 and world.player.controls_locked and world.orchestrator.snapshot().interaction=="menu")
	world.set_menu_open(false);wall.queue_free();await frames(100)
	check("cleared obstruction resumes the same route",builder.routine.arrivals>=1 and builder.global_position.x< -4,builder.global_position)
	check("unsupported floor is rejected",not builder.supported_floor(builder.global_position+Vector3.UP*20))
	paused=builder.global_position;world.go_location(1);await frames(25)
	check("other floor pauses movement without a reset",builder.global_position.distance_to(paused)<.03 and builder.routine.started)
	check("scripted movement uses no provider calls",social.requests_started==0)
	var final: Dictionary = world.orchestrator.snapshot()
	check("routines cannot award gates course or arrival",final.gates==initial.gates and final.course==initial.course and final.arrival==initial.arrival)
	world.queue_free();await process_frame
	print("ROUTINES_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
