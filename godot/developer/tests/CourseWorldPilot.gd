extends RefCounted
## Earlier gates/arrival are explicit fixtures; course UI uses real input later.
const Event = preload("res://game/SessionEvent.gd")
const Pipes = preload("res://developer/tests/PipeTestPilot.gd")

static func prepare_arrival(world: Node3D) -> void:
	Pipes.solve_all(world.entrance_puzzle.state)
	world.entrance_puzzle.state.enter_code(world.entrance_puzzle.state.revealed_code())
	world._on_entrance_unlocked()
	world.elevator_game.state.start()
	while not world.elevator_game.state.completed():
		if world.elevator_game.state.phase=="between": world.elevator_game.state.between_waves=0
		for enemy: Dictionary in world.elevator_game.state.enemies: world.elevator_game.state.shots.append(enemy.at)
		world.elevator_game.state.step(.001,Vector2.ZERO,false)
	world._on_shooter_won()
	var c: RefCounted = world.orchestrator
	c.observe_zone("upstairs");c.claim("check_in")
	world.check_in.state.start_photo("Sample tester");world.check_in.state.take_photo();world.check_in.state.confirm()
	assert(c.submit(c.new_event(Event.Kind.CHECK_IN_CONFIRMED)).accepted)
	c.release("check_in");c.claim("classroom")
	for beat: String in world.classroom_sequence.state.BEATS: world.classroom_sequence.state.record(beat)
	assert(c.submit(c.new_event(Event.Kind.CLASSROOM_INTRODUCED)).accepted)
	c.release("classroom")

static func approach_computer(world: Node3D) -> Vector3:
	var player: CharacterBody3D = world.player
	var source: Dictionary = world.computer_portal.computers.filter(func(c: Dictionary):return c.id.ends_with("Facilitator laptop"))[0]
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new();capsule.radius=player.RADIUS;capsule.height=player.HEIGHT-.06
	for radius: float in [.85,1.15,1.5,1.7]:
		for index: int in range(24):
			var angle: float = TAU*index/24.0
			var feet := Vector3(source.point.x+cos(angle)*radius,float(source.floor)+.025,source.point.z+sin(angle)*radius)
			var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.2,feet-Vector3.UP*.2,1))
			if floor_hit.is_empty() or absf(floor_hit.position.y-float(source.floor))>.04: continue
			var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*(player.HEIGHT*.5+.04));query.collision_mask=1|8
			if not space.intersect_shape(query).is_empty(): continue
			player.teleport_to(feet)
			var toward: Vector3 = source.point-feet
			player.camera_pivot.rotation.y = atan2(-toward.x,-toward.z)
			if world.computer_portal.reachable_computer().get("id","")==source.id: return feet
	return Vector3.INF
