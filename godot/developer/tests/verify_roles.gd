extends SceneTree
const Pilot = preload("res://developer/tests/NPCTestPilot.gd")
var world: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)

func run() -> void:
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	var social: Node3D = world.npc_conversations
	var initial: Dictionary = world.orchestrator.snapshot()
	var roles: Dictionary = {}
	check("five humanoids plus separate Mr P make the selected cast",world.population.actors.size()==5 and social.actors.size()==5 and world.computer_portal.room.mrp!=null)
	for record: Dictionary in social.actors:
		var profile: Dictionary = social.state.data.profiles[record.id]
		roles[profile.role] = int(roles.get(profile.role,0))+1
		check("role matches its reused actor "+record.id,profile.role==record.actor.record.role and not profile.background.is_empty())
	check("one host Builder Manager and two background people",roles=={"entrance_host":1,"builder_companion":1,"program_manager":1,"background":2})
	check("Mr P and Dial a Friend have no social controller",not social.state.data.profiles.has("MrP") and not social.state.data.profiles.has("Helper"))
	for id: String in ["EntranceHost","ProgramManager"]:
		check("clear talk approach "+id,Pilot.approach(world,id).is_finite())
		await frames()
		check("role opens scripted greeting "+id,social.try_talk() and social.active_npc==id and social.state.met_npcs.has(id))
		social._on_topic("entrance" if id=="EntranceHost" else "work")
		await process_frame;await frames()
		check("role reply is authored with no provider "+id,social.last_reply.get("provider")=="scripted" and social.state.memory(id).turn_count==1 and not social.dialogue.waiting)
		social.dialogue.close();await frames()
		check("repeat conversation has its own return greeting "+id,social.try_talk() and social.dialogue.text_label.text==social.state.data.profiles[id].return_greeting)
		social.dialogue.close()
	var memory: RefCounted = load("res://game/NPCConversationState.gd").new()
	for index: int in range(5): memory.remember("EntranceHost","controls",str(index))
	check("scripted history is bounded to two exchanges",memory.memory("EntranceHost").turn_count==5 and memory.memory("EntranceHost").lines==["3","4"] and memory.memory("ProgramManager").turn_count==0)
	check("all authored role conversations spend no model calls",social.requests_started==0)
	check("role dialogue cannot change gates course or arrival",world.orchestrator.snapshot().gates==initial.gates and world.orchestrator.snapshot().course==initial.course and world.orchestrator.snapshot().arrival==initial.arrival)
	world.queue_free();await process_frame
	print("ROLES_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
