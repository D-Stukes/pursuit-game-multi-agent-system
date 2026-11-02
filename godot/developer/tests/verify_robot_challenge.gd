extends "res://developer/tests/TestKit.gd"
## The robot challenge: H opens it only at the robot, the hidden-parts hunt and
## the agent-team puzzle gate correctly, and finishing it powers the robot on.
var world: Node3D

func _initialize() -> void: call_deferred("run")

func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame

func run() -> void:
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	if world.intro != null and world.intro.active: world.intro.finish()
	await frames(4)
	var robot: Node3D = world.classroom_cast.get_node_or_null("RobotRepair")
	check("the classroom robot exists", robot != null)
	check("the robot can assemble and power on", robot != null and robot.has_method("assemble_and_power"))

	# Proximity: the challenge is reachable at the robot, not across the room.
	world.player.global_position = Vector3(0, 5.05, -2.0);await frames()
	check("not near the robot elsewhere in the classroom", not world.near_robot())
	check("the challenge can't open away from the robot", not world.can_open_challenge())
	var front := robot.global_position + Vector3(1.9, 0, 0)
	world.player.global_position = Vector3(front.x, 5.05, front.z);await frames()
	check("standing at the robot counts as near", world.near_robot())

	# Drive the overlay directly through its three beats.
	var ch: Control = world.challenge
	ch.open();await frames()
	check("the challenge room opens on beat 1", ch.visible and ch.beat == 1)
	check("six parts are hidden to find", ch.part_buttons.size() == 6)
	var go: Button = ch.stage.get_node_or_null("Continue")
	check("you can't build until every part is found", go != null and go.disabled)
	for btn: Button in ch.part_buttons:
		btn.pressed.emit()
	await frames()
	check("recovering all parts enables the build step", ch.found.size() == 6 and not go.disabled)

	ch._build_beat2a();await frames()
	check("beat 2 asks for an agent team", ch.beat == 2)
	var sink := Label.new()
	ch.picked = {"vision": true}
	ch._submit_team(sink)
	check("one agent is rejected", ch.beat == 2 and not sink.text.is_empty())
	ch.picked = {"vision": true, "planner": true}
	ch._submit_team(sink)
	check("a team with no Builder agent is rejected", ch.beat == 2)
	ch.picked = {"builder": true, "vision": true}
	ch._submit_team(sink);await frames()
	check("two agents including the Builder advance to the prompt", ch.get("chosen_prompt") == -1 and ch.beat == 2)

	# Beat 2b lives in the same beat index; test the prompt gate.
	var ok_index: int = -1
	for i in range(ch.PROMPTS.size()):
		if ch.PROMPTS[i].ok: ok_index = i
	ch.chosen_prompt = 0   # a weak prompt
	var sink2 := Label.new()
	ch._submit_prompt(sink2)
	check("a weak prompt is sent back with a reason", ch.beat == 2 and not sink2.text.is_empty())
	ch.chosen_prompt = ok_index
	ch._submit_prompt(sink2);await frames()
	check("the strong prompt launches the build", ch.beat == 3)

	# The payoff fires after a short beat and powers the robot on.
	var waited: float = 0.0
	while not world.challenge_solved and waited < 4.0:
		await physics_frame;waited += 1.0 / 60.0
	check("finishing marks the challenge solved", world.challenge_solved, waited)
	check("the robot is assembling / powered on", robot.assembled)
	check("the overlay closed after success", not ch.visible)
	check("the challenge won't reopen once solved", not world.can_open_challenge())

	world.queue_free();await process_frame
	print("ROBOT_CHALLENGE_RESULT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
