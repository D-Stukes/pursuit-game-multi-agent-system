extends SceneTree
## Real player-triggered help, changing observations and bounded session memory.
const Pilot = preload("res://developer/tests/NPCTestPilot.gd")
const Pipes = preload("res://developer/tests/PipeTestPilot.gd")
var checks: int=0
var failures: int=0
var world: Node3D
var social: Node3D

func _initialize() -> void: call_deferred("run")
func frames(count: int=4) -> void:
	for _i: int in range(count): await physics_frame
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func key(code: Key) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	Input.parse_input_event(e);await process_frame;await frames(2)
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame;await frames(2)
func choose(index: int) -> void:
	social.dialogue.choices[index].grab_focus();await process_frame;await key(KEY_ENTER);await process_frame;await frames()

func run() -> void:
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	social=world.npc_conversations
	check("one Builder reuses a retained population actor",social.actors.size()==3 and world.population.actors.size()==16)
	check("no work runs before player contact",social.pending.is_empty() and social.requests_started==0 and social.state.memories.is_empty())
	check("Builder has a collision-free street approach",Pilot.approach(world,"BuilderCompanion")!=Vector3.INF)
	await frames();await key(KEY_E)
	check("E opens scripted Builder greeting",social.dialogue.visible and social.active_npc=="BuilderCompanion" and not social.dialogue.status.visible and social.last_reply.is_empty())
	check("greeting is free and marks contact only",social.requests_started==0 and social.state.memory("BuilderCompanion").turn_count==0 and social.state.met_npcs.has("BuilderCompanion"))
	check("Builder offers useful help choices",social.dialogue.choices[0].text.contains("next") and social.dialogue.choices[1].text.contains("hint") and social.dialogue.choices[2].text.contains("steps"))
	var pipe: RefCounted=world.entrance_puzzle.state
	var before: Array=pipe.masks.duplicate()
	var observation: Dictionary=world.orchestrator.builder_world_snapshot()
	check("snapshot contains current authored hint",observation.stage=="entrance" and observation.challenge.level==1 and observation.challenge.row>0)
	observation.challenge.ports.clear()
	check("snapshot cannot mutate game rules",not world.orchestrator.builder_world_snapshot().challenge.ports.is_empty() and pipe.masks==before)
	check("snapshot contains no door code or authored solution",not JSON.stringify(world.orchestrator.builder_world_snapshot()).contains("digits") and not world.orchestrator.builder_world_snapshot().challenge.has("code"))
	await choose(1)
	check("local help uses actual board observation without provider labels",social.last_reply.get("provider")=="local" and not social.last_reply.get("fallback",true) and not social.dialogue.status.visible and social.dialogue.text_label.text.contains("Board 1") and social.dialogue.text_label.text.contains("row "))
	check("help changes no board or rewards",pipe.masks==before and pipe.rewards.is_empty() and not pipe.unlocked and world.orchestrator.snapshot().course.energy==10 and world.orchestrator.snapshot().course.score==0)
	await choose(2);await choose(0)
	var memory: Dictionary=social.state.memory("BuilderCompanion")
	check("only two exchanges are retained",memory.turn_count==3 and memory.topics==["steps","next"] and memory.lines.size()==2)
	check("explicit explanation preference survives",memory.facts.style=="steps" and memory.facts.hints_given==2)
	memory.lines.clear();memory.facts.style="other"
	check("memory reads are copies",social.state.memory("BuilderCompanion").lines.size()==2 and social.state.memory("BuilderCompanion").facts.style=="steps")
	check("Builder cannot see another NPC history",social.state.memory("ReceptionA").turn_count==0 and social.state.memory("ReceptionB").turn_count==0)
	for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);world.hud.size=resolution;await frames()
		check("help UI fits "+str(resolution),Rect2(Vector2.ZERO,resolution).encloses(social.dialogue.panel.get_global_rect()) and social.dialogue.panel.get_global_rect().encloses(social.dialogue.close_button.get_global_rect()))
	await key(KEY_ESCAPE)
	check("closing restores movement and ends ownership",not social.dialogue.visible and not world.player.controls_locked and world.orchestrator.snapshot().interaction.is_empty())
	await key(KEY_E)
	check("return greeting remembers contact without a model call",social.dialogue.text_label.text.begins_with("Welcome back") and social.requests_started==0)
	social._on_topic("hint");social.dialogue.close();await process_frame;await frames()
	check("close discards deferred result without memory",social.state.memory("BuilderCompanion").turn_count==3 and social.pending.is_empty())
	social.try_talk();social._on_topic("hint")
	var old_index: int=pipe.hint_index()
	for _i: int in range(4):
		pipe.rotate_tile(old_index)
		if pipe.hint_index()!=old_index: break
	await process_frame;await frames()
	check("changed observations invalidate stale help",social.pending.is_empty() and social.dialogue.status.text.contains("state changed") and social.state.memory("BuilderCompanion").turn_count==3)
	social.dialogue.close();pipe.reset_level()
	for level: int in range(4):
		social.try_talk();await choose(1)
		check("same help code handles board "+str(level+1),social.dialogue.text_label.text.contains("Board "+str(level+1)))
		social.dialogue.close();check("independent pilot verifies board "+str(level+1),Pipes.solve_level(pipe))
		if level<3: pipe.next_level()
	social.try_talk();await choose(1)
	check("completed circuits still require player code entry",social.dialogue.text_label.text.contains("code shown") and not pipe.unlocked)
	social.dialogue.close();pipe.enter_code(pipe.revealed_code());world._on_entrance_unlocked()
	social.try_talk();await choose(1)
	check("help follows verified elevator objective",world.orchestrator.builder_world_snapshot().stage=="elevator" and social.dialogue.text_label.text.contains("Launch flight"))
	social.dialogue.close()
	world.elevator_game.state.start();world.elevator_game.state.wave=2;world.elevator_game.state.cleared=8;world.elevator_game.state.shields=1
	social.try_talk();await choose(1)
	check("held-out shooter progress uses same help code",social.dialogue.text_label.text.contains("Wave 2") and social.dialogue.text_label.text.contains("8 of 18") and social.dialogue.text_label.text.contains("1 shields"))
	check("social help still cannot complete flight",not world.orchestrator.snapshot().gates.elevator and world.orchestrator.snapshot().course.score==0)
	social.dialogue.close()
	world.elevator_game.state.phase="won";world.elevator_game.state.wave=3;world.elevator_game.state.cleared=18
	world._on_shooter_won();social.try_talk();await choose(0)
	check("verified win does not claim upstairs arrival",world.orchestrator.builder_world_snapshot().challenge.kind=="travel" and social.dialogue.text_label.text.contains("press E") and not social.dialogue.text_label.text.contains("reached upstairs"))
	social.dialogue.close();await key(KEY_R);await frames()
	Pilot.approach(world,"BuilderCompanion");await frames();social.try_talk();await choose(1)
	check("reset to street preserves useful ride guidance",social.dialogue.text_label.text.contains("press E") and world.orchestrator.snapshot().gates.elevator)
	social.dialogue.close();world.go_location(1);await frames()
	var upstairs: Dictionary=world.orchestrator.builder_world_snapshot()
	check("physical arrival ends travel guidance",upstairs.zone=="upstairs" and upstairs.challenge.kind=="none" and social.state.local_reply("BuilderCompanion","hint",upstairs).contains("not connected yet"))
	world.go_location(0);await frames();Pilot.approach(world,"BuilderCompanion");await frames();social.try_talk()
	social._on_topic("next");await key(KEY_F3);await process_frame
	check("developer menu cancels and keeps ownership",world.hud.menu_open and social.pending.is_empty() and not social.dialogue.visible and world.player.controls_locked)
	check("only explicit configured help can use provider",social.requests_started==0 and social.last_usage.is_empty())
	print("BUILDER_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame;quit(0 if failures==0 else 1)
