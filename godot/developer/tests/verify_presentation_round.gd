extends SceneTree
const Pilot=preload("res://developer/tests/PipeTestPilot.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func frames(count: int=5) -> void:
 for i in range(count):await physics_frame
func run() -> void:
 var prefs: Node=root.get_node("GamePreferences")
 var audio: Node=root.get_node("GameAudio")
 var world: Node3D=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
 check("intro does not interrupt automated or repeat launch",not world.intro.active)
 var puzzle: Control=world.entrance_puzzle
 world.player.teleport_to(Vector3(0,0,8));await frames(5)
 world.orchestrator.claim("entrance");puzzle.open();puzzle._start_puzzle()
 check("code stays hidden until a circuit is verified",puzzle.state.revealed_code().is_empty() and not puzzle.state.enter_code("0000"))
 check("one circuit is enough to reveal a four digit code",Pilot.solve_level(puzzle.state) and puzzle.state.completed() and puzzle.state.revealed_code().length()==4 and puzzle.state.level==0)
 puzzle._sync();await frames(3)
 check("number pad exposes twelve real buttons",puzzle.code_box.visible and puzzle.keypad_buttons.size()==12)
 puzzle.code_input.text="";puzzle._keypad_press("0");puzzle._keypad_press("1");puzzle._keypad_press("⌫")
 check("number pad keeps leading zeros and supports backspace",puzzle.code_input.text=="0")
 puzzle._keypad_press("Clear")
 var code: String=puzzle.state.revealed_code()
 puzzle.code_input.text="0000" if code!="0000" else "1111";puzzle._unlock()
 check("incorrect code cannot grant access or a pellet",not world.orchestrator.entrance_allowed() and int(world.orchestrator.snapshot().reserve_pellets)==0)
 for digit: String in code:puzzle._keypad_press(digit)
 # Clear the previous wrong entry, then use the same on-screen digit actions.
 puzzle._keypad_press("Clear")
 for digit: String in code:puzzle._keypad_press(digit)
 puzzle._unlock();await frames(3)
 check("correct keypad entry unlocks actual doors",world.orchestrator.entrance_allowed() and world.entrance_doors.open)
 check("unlock awards one reserve without overfilling energy",int(world.orchestrator.snapshot().reserve_pellets)==1 and int(world.orchestrator.snapshot().course.energy)==10)
 var celebrations: int=puzzle.celebration_count;puzzle._unlock();world._on_entrance_unlocked()
 check("repeat unlock cannot farm rewards or effects",int(world.orchestrator.snapshot().reserve_pellets)==1 and puzzle.celebration_count==celebrations)
 check("first unlock offers optional bonuses",puzzle.next_button.visible)
 for i in range(1,4):
  puzzle._next_level();await frames(3)
  check("optional circuit has a distinct theme "+str(i),puzzle.state.level==i and puzzle.tiles[0].palette==i and puzzle.state.revealed_code()==code and world.orchestrator.entrance_allowed())
  check("optional circuit remains solvable "+str(i),Pilot.solve_level(puzzle.state));puzzle._sync()
 check("bonus completion awards no extra pellet",int(world.orchestrator.snapshot().reserve_pellets)==1)
 puzzle.close();world.set_menu_open(true);world.hud._show_page("Help & objective");await frames(3)
 check("replay and bonus controls are available in help",world.hud.replay_button.visible and world.hud.bonus_button.visible and not world.hud.bonus_button.disabled)
 world.set_menu_open(false)
 var gates: Dictionary=world.orchestrator.snapshot().gates
 var motion: bool=prefs.reduced_motion;prefs.reduced_motion=true
 check("intro locks movement and owns one modal",world.intro.start() and world.player.controls_locked and world.orchestrator.snapshot().interaction=="intro")
 check("reduced motion shows static text",world.intro.static_text)
 for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
  world.intro.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);world.intro.size=resolution;await frames(4);await process_frame
  var bounds:=Rect2(Vector2.ZERO,resolution)
  check("intro buttons fit "+str(resolution),bounds.encloses(world.intro.skip_button.get_global_rect()) and bounds.encloses(world.intro.static_button.get_global_rect()))
  check("intro offers only Skip and the motion toggle "+str(resolution),world.intro.find_children("*","Button",true,false).size()==2)
  check("static intro paragraph fits its reading window "+str(resolution),world.intro.window.get_global_rect().encloses(world.intro.paragraph.get_global_rect()))

 world.intro.finish(false);await frames(3)
 check("intro restores play without granting gates",not world.intro.active and not world.player.controls_locked and world.orchestrator.snapshot().gates==gates)
 world._open_bonus_puzzles();await frames(3)
 check("bonus puzzles can be reopened from help",puzzle.visible and world.orchestrator.snapshot().interaction=="bonus")
 puzzle.close()

 prefs.reduced_motion=motion
 check("full energy cannot spend a reserve",not world.orchestrator.use_reserve_pellet() and int(world.orchestrator.snapshot().reserve_pellets)==1)
 # Arrange a course energy deficit; exercise only the public reserve-use action.
 world.orchestrator._state._stage=5;world.orchestrator._state._course.energy=9
 check("reserve restores exactly one energy",world.orchestrator.use_reserve_pellet() and int(world.orchestrator.snapshot().course.energy)==10 and int(world.orchestrator.snapshot().reserve_pellets)==0)
 check("consumed reserve cannot be used twice",not world.orchestrator.use_reserve_pellet())
 audio.set_context("shooter");check("shooter uses its own soundtrack",audio.active_track=="discovery")
 audio.set_context("upstairs");check("upstairs uses the saved selectable track",audio.active_track==audio.upstairs_track)
 audio.set_context("ground");check("ground floor keeps Hymn",audio.active_track=="hymn")
 check("three upstairs choices are real imported music",audio.UPSTAIRS_TRACKS.size()==3 and audio.UPSTAIRS_TRACKS.all(func(id: String):return ResourceLoader.exists("res://assets/audio/"+id+"-scott-buckley.mp3")))
 world.queue_free();await process_frame
 print("PRESENTATION_RESULT checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
