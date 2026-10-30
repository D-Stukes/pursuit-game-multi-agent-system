extends "res://developer/tests/verify_playtest.gd"
## Player-facing guidance and real stair movement on the saved building.
func run() -> void:
 world=load("res://Main.tscn").instantiate();world.include_population=false;root.add_child(world);await frames(12)
 player=world.player
 check("conversation exits with Thanks",world.npc_conversations.dialogue.close_button.text=="Thanks [Esc]")
 player.teleport_to(Vector3(-1.25,0,.7));await frames(12)
 check("stairs help waits until entry is allowed",not world.stairs_hint_seen)
 world.set_building_review_mode(true);await frames(12)
 check("first stairs approach explains movement and alternate ramp",world.stairs_hint_seen and world.hud.hint_panel.visible and world.hud.hint_label.text.contains("Walk forward") and world.hud.hint_label.text.contains("ramp on the right"))
 world.hud.set_objective("Win the elevator shooter")
 check("stairs instructions also remain in objective help",world.hud._objective_help().contains("Walk forward to climb the stairs"))
 check("walk up stairs with normal movement",await walk_to(Vector3(-1.25,.85,-3)),player.global_position)
 check("walk down stairs with normal movement",await walk_to(Vector3(-1.25,0,.3)),player.global_position)
 world.hud.hint_panel.hide();world.hud.hint_timer.stop();await frames(5)
 check("stairs hint does not repeat on return",not world.hud.hint_panel.visible)
 var building: Node3D=world.get_node("Building")
 for id: String in ["Classroom_entry_sign","Commons_entry_sign","Reception_sign"]:
  check("room sign exists "+id,building.find_child(id,true,false)!=null)
 var plants: Array[Node]=building.find_children("Classroom | Planter*","MeshInstance3D",true,false)
 var aisle_clear: bool=plants.size()==2
 for plant: MeshInstance3D in plants:
  var bounds: AABB=plant.global_transform*plant.get_aabb()
  aisle_clear=aisle_clear and bounds.end.x< -16.3
 check("classroom plants remain in rear corners outside aisle",aisle_clear)
 player.teleport_to(Vector3(-13.5,5.07,-3.21));await frames(12)
 await route("classroom rear aisle stays clear",[Vector3(-1.5,5.05,-3.21)])
 var failures: int=checks.filter(func(row: Dictionary):return not row.pass).size()
 print("CLARITY_RESULT checks=",checks.size()," failures=",failures)
 world.queue_free();await process_frame;quit(0 if failures==0 else 1)
