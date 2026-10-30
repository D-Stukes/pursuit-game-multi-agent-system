extends "res://developer/tests/verify_playtest.gd"
## Walk the furnished room using normal player movement and actual mesh collision.
func run() -> void:
 world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
 player=world.player
 world.set_building_review_mode(true)
 player.teleport_to(Vector3(-18,5.07,-6.2));await frames(12)
 var initial: Dictionary=world.orchestrator.snapshot()
 player.teleport_to(Vector3(-17,5.07,-5.1));await frames(12)
 await route("wall couch leaves a continuous hallway aisle",[Vector3(-2,5.05,-5.1),Vector3(-2,5.05,-6.2),Vector3(-18,5.05,-6.2)])
 await route("Hallway 2 remains clear",[Vector3(-10,5.05,-6.2),Vector3(-18,5.05,-6.2)])
 await route("commons entry reaches lounge side",[Vector3(-16,5.05,-6.2),Vector3(-16,5.05,-9.8),Vector3(-16,5.05,-12.1)])
 await route("central aisle reaches shared desks",[Vector3(-16,5.05,-14.1),Vector3(-15.2,5.05,-14.1),Vector3(-15.2,5.05,-16.8)])
 player.teleport_to(Vector3(-20.7,5.07,-16.45));await frames(12)
 await route("open west-side quiet booth can be entered and left",[Vector3(-21.6,5.05,-16.45),Vector3(-20.7,5.05,-16.45)])
 player.teleport_to(Vector3(-8,5.07,-9.2));await frames(12)
 await route("kitchen aisle stays accessible from Room 2",[Vector3(-8,5.05,-12),Vector3(-8,5.05,-16.5),Vector3(-8,5.05,-9.2)])
 player.teleport_to(world.approved_layout.anchor("commons_spawn")+Vector3.UP*.02);await frames(12)
 await route("commons review spawn can leave the lounge",[Vector3(-17,5.05,-12.2)])
 check("room exploration grants no game or course progress",world.orchestrator.snapshot().gates==initial.gates and world.orchestrator.snapshot().course==initial.course and world.orchestrator.snapshot().arrival==initial.arrival)
 check("room retains the classroom and live entrance",world.approved_layout.retained.get("classroom")==646 and world.classroom_cast.get_node("RobotRepair").global_position.x< -16 and world.entrance_doors.open)
 var failures: int=checks.filter(func(row: Dictionary):return not row.pass).size()
 print("COMMONS_RESULT checks=",checks.size()," failures=",failures)
 world.queue_free();await process_frame;quit(0 if failures==0 else 1)
