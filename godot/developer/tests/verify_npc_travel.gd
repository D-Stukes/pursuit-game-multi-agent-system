extends SceneTree
## Physical authored routes, elevator ownership and pause behavior.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(label: String, passed: bool) -> void:
 checks+=1
 if not passed:failures+=1
 print("PASS " if passed else "FAIL ",label)
func run() -> void:
 var world: Node3D=load("res://Main.tscn").instantiate();root.add_child(world)
 for i in range(15):await physics_frame
 world.population.set_physics_process(false)
 var travel: Node=world.population.travel
 var target: String="ReceptionA" if OS.get_cmdline_user_args().has("--guide") else "ReceptionB"
 var actor: CharacterBody3D=world.population.get_node(target)
 check("errands wait for both gates",not travel.request(actor))
 world.orchestrator.skip_gate("entrance");world.orchestrator.skip_gate("elevator")
 world.player.teleport_to(Vector3(-18,5.05,0))
 travel.cooldowns.ReceptionA=999;travel.cooldowns.ReceptionB=999
 var home: Vector3=actor.global_position
 check("independent developer bypass unlocks errands",travel.request(actor))
 check("only one NPC reserves an errand",not travel.request(world.population.get_node("ReceptionB" if target=="ReceptionA" else "ReceptionA")))
 var stopped: Vector3=actor.global_position
 travel.update(10,false)
 check("modal pause freezes travel",actor.global_position==stopped and travel.trips[target].index==0)
 var visited_ground: bool=false
 var reserved: bool=false
 for i in range(2300):
  travel.update(.05,true);await physics_frame
  if not travel.lift_actor.is_empty() and not reserved:
   reserved=true
   check("NPC cab reservation blocks a competing player ride",not world.try_lift())
  if actor.global_position.y<1 and actor.visible:
   visited_ground=true
   check_floor(actor)
  if travel.trips.is_empty():break
 check("NPC walks and rides to the ground floor",visited_ground)
 check("NPC completes both elevator rides and returns home",travel.rides_completed==2 and travel.trips.is_empty() and actor.global_position.distance_to(home)<.15)
 check("arriving actor retains collision and visibility",actor.visible and actor.collision_layer==8)
 check("travel never grants earned puzzle wins",not world.orchestrator.snapshot().gates.entrance and not world.orchestrator.snapshot().gates.elevator)
 travel.request(actor)
 for i in range(900):
  travel.update(.05,true);await physics_frame
  if not travel.lift_actor.is_empty():break
 check("second errand reaches the cab reservation",not travel.lift_actor.is_empty())
 world.set_building_review_mode(true);travel.update(.05,true)
 check("review mode clears hidden riders and cab reservations",travel.trips.is_empty() and travel.lift_actor.is_empty() and actor.visible and actor.collision_layer==8 and actor.global_position.distance_to(home)<.15)
 check("travel makes no provider requests",world.npc_conversations.requests_started==0)
 world.queue_free();await process_frame
 print("NPC_TRAVEL_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
func check_floor(actor: CharacterBody3D) -> void:
 # Fail once if any part of the ground-floor route loses support.
 if actor.get_meta("checked_support_failure",false):return
 if not actor.supported_floor(actor.global_position):
  actor.set_meta("checked_support_failure",true);check("cross-floor movement retains floor support",false)
