extends RefCounted
## Find a collision-free test approach using the actual actor and world physics.
static func approach(world: Node3D, id: String, bearing: float = 0) -> Vector3:
	var player: CharacterBody3D=world.player
	var social: Node3D=world.npc_conversations
	var records: Array=social.actors.filter(func(record: Dictionary):return record.id==id)
	if records.is_empty(): return Vector3.INF
	var actor: Node3D=records[0].actor
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new()
	capsule.radius=player.RADIUS;capsule.height=player.HEIGHT-.06
	for radius: float in [1.0,1.3,1.6,1.9]:
		for i: int in range(24):
			var angle: float=bearing+TAU*i/24
			var feet: Vector3=actor.global_position+Vector3(cos(angle)*radius,.02,sin(angle)*radius)
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*(player.HEIGHT*.5+.04))
			query.collision_mask=1|8
			if not space.intersect_shape(query).is_empty(): continue
			player.global_position=feet
			var toward: Vector3=actor.global_position-feet
			player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)
			var selected: Dictionary=social.reachable_npc()
			if not selected.is_empty() and selected.id==id: return feet
	return Vector3.INF
