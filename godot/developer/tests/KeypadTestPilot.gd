extends RefCounted
## Tests approach the actual mounted prop instead of a second entrance position.
static func point(world: Node3D) -> Vector3:
	var at: Vector3 = world.entrance_keypad.global_position+Vector3(0,0,.95)
	at.y = world.ENTRANCE_POINT.y+.03
	return at

static func approach(world: Node3D) -> void:
	world.player.teleport_to(point(world))
	var toward: Vector3 = world.entrance_keypad.global_position-world.player.global_position
	world.player.camera_pivot.rotation.y = atan2(-toward.x,-toward.z)
