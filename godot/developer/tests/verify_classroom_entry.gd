extends "res://developer/tests/TestKit.gd"
## The stand-up cutscene is off: walking into the classroom after check-in completes the step,
## Mr. P's greeting plays, and the classroom computers wait until the talking is done.
const GatePilot = preload("res://developer/tests/verify_check_in.gd")
const Event = preload("res://game/SessionEvent.gd")
var world: Node3D
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await physics_frame

## Stand where a classroom computer is in reach and selected (same approach as the portal suite).
func stand_at_computer() -> bool:
	var portal: Node = world.computer_portal
	var player: CharacterBody3D = world.player
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new();capsule.radius = player.RADIUS;capsule.height = player.HEIGHT-.06
	for computer: Dictionary in portal.computers:
		if absf(float(computer.floor)-5.05) > .3: continue
		if computer.point.z < -3.4 or computer.point.x < -14.5 or computer.point.x > 2.8: continue
		for radius: float in [.85,1.15,1.5]:
			for i: int in range(24):
				var angle: float = TAU*i/24.0
				var feet := Vector3(computer.point.x+cos(angle)*radius,float(computer.floor)+.025,computer.point.z+sin(angle)*radius)
				var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.2,feet-Vector3.UP*.2,1))
				if floor_hit.is_empty() or absf(floor_hit.position.y-float(computer.floor))>.04: continue
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule;query.collision_mask = 1|8
				query.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*(player.HEIGHT*.5+.04))
				if not space.intersect_shape(query).is_empty(): continue
				player.global_position = feet
				var toward: Vector3 = computer.point-feet
				player.camera_pivot.rotation.y = atan2(-toward.x,-toward.z)
				if not portal.reachable_computer().is_empty(): return true
	return false

func run() -> void:
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	if world.intro != null and world.intro.active: world.intro.finish()
	var sequence: Node = world.classroom_sequence
	var orchestrator: RefCounted = world.orchestrator
	check("the stand-up cutscene is switched off in play",not sequence.stand_up_enabled)
	GatePilot.solve_gates(world);world.go_location(1);await frames()
	orchestrator.claim("check_in");world.check_in.state.start_photo("Entry Fixture");world.check_in.state.take_photo();world.check_in.state.confirm()
	orchestrator.submit(orchestrator.new_event(Event.Kind.CHECK_IN_CONFIRMED));orchestrator.release("check_in")
	var course: Dictionary = orchestrator.snapshot().course
	check("checked in and heading to the classroom",orchestrator.checked_in() and orchestrator.snapshot().stage == "classroom_pending")
	sequence.requested_from_reception();await frames(4)
	check("Continue to classroom points the way instead of playing a cutscene",not sequence.active and world.hud.hint_panel.visible and world.hud.hint_label.text.contains("double doors"))
	world.player.teleport_to(Vector3(.38,5.05,-2.6));await frames(10)
	check("walking in completes the classroom step without a cutscene",orchestrator.snapshot().stage == "mr_p_pending" and orchestrator.snapshot().arrival.classroom_complete and not sequence.active)
	check("the player keeps control and the normal camera",not world.player.controls_locked and world.player.camera.current)
	check("no course progress is awarded",orchestrator.snapshot().course == course)
	var greeter: Node = world.classroom_cast.get_node("ClassroomMrP")
	check("Mr. P's classroom greeting still plays",greeter.greeted)
	check("the classroom computers wait while he is talking",world.classroom_greeting_busy())
	check("a classroom computer is in reach",await stand_at_computer())
	check("it can't be used yet",not world.computer_portal.try_use() and not world.computer_portal.transitioning)
	world.computer_portal.refresh_remaining = 0;world.computer_portal.update_prompts(.2)
	check("the prompt says to wait for the talking",world.computer_portal.context_prompt() == "Wait until they finish talking")
	check("the lock lasts at least both recordings",greeter.talk_limit() >= greeter.voice.stream.get_length()+greeter.pm_voice.stream.get_length())
	var waited: float = 0
	while world.classroom_greeting_busy() and waited < greeter.talk_limit()+2:
		await physics_frame;waited += 1.0/60
	check("the talking ends (or its time cap passes)",not world.classroom_greeting_busy(),waited)
	world.computer_portal.refresh_remaining = 0;world.computer_portal.update_prompts(.2)
	check("then the computer works",world.computer_portal.context_prompt() == "E: use computer" and world.computer_portal.try_use())
	world.queue_free();await process_frame
	print("CLASSROOM_ENTRY_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
