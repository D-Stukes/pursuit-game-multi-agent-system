extends SceneTree
## Regressions for current entrance guidance and background interruption.
var world: Node3D
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func frames(count: int=5) -> void:
 for i in range(count):await physics_frame
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func run() -> void:
 root.set_disable_input(true)
 var prefs: Node=root.get_node("GamePreferences")
 prefs.settings_path="res://.godot/focus-review-prefs.cfg";prefs.reduced_motion=false
 var dialogue: RefCounted=load("res://game/NPCConversationState.gd").new()
 var host: String=dialogue.local_reply("EntranceHost","entrance")
 check("host describes automatic approach and one required circuit",host.contains("Approach") and host.contains("one pipe circuit") and host.contains("four-digit") and host.contains("optional"))
 var observation: Dictionary={"stage":"entrance","zone":"street","challenge":{"kind":"pipe","phase":"code","ports":[]}}
 var objective: String=dialogue.local_reply("BuilderCompanion","next",observation)
 check("Builder objective makes bonuses optional",objective.contains("first pipe circuit") and objective.contains("four-digit") and objective.contains("optional") and not objective.contains("Press E"))
 var hint: String=dialogue.local_reply("BuilderCompanion","hint",observation)
 check("Builder code hint requires only the verified entry circuit",hint.contains("required circuit") and hint.contains("four-digit") and not hint.contains("All four"))
 world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
 var before: Dictionary=world.orchestrator.snapshot()
 check("intro starts",world.intro.start())
 world.intro.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await frames()
 world.intro.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 var elapsed: float=world.intro.elapsed;var pose: Transform3D=world.intro.camera.global_transform
 await frames(20)
 check("background intro holds time and camera",is_equal_approx(world.intro.elapsed,elapsed) and world.intro.camera.global_transform.is_equal_approx(pose))
 world.intro.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await frames(10)
 check("foreground intro continues",world.intro.elapsed>elapsed)
 world.intro.elapsed=41.9;world.intro.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await frames(20)
 check("unfocused intro cannot finish unseen",world.intro.active and is_equal_approx(world.intro.elapsed,41.9))
 world.intro.finish(false);await frames()
 var game: Control=world.elevator_game
 game.open();game.state.start();game._sync()
 game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 var ship: Vector2=game.state.ship;var shields: int=game.state.shields
 await frames(30)
 check("focus loss pauses shooter and preserves ship and shields",game.state.paused and game.state.ship==ship and game.state.shields==shields and game.center_title.text=="FLIGHT PAUSED")
 game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await frames(10)
 check("returning does not silently resume shooter",game.state.paused)
 game.toggle_pause();check("explicit Resume continues shooter",not game.state.paused)
 game.state.phase="between";game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check("focus loss also pauses wave transition",game.state.paused)
 game.close();game.state.paused=false;game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check("hidden shooter ignores focus loss",not game.state.paused)
 check("review earns no gates or course progress",world.orchestrator.snapshot().gates==before.gates and world.orchestrator.snapshot().course==before.course)
 print("FOCUS_GUIDANCE_RESULT checks=",checks," failures=",failures)
 world.queue_free();await process_frame;quit(1 if failures else 0)
