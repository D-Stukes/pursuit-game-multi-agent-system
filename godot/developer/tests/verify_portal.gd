extends SceneTree
## Real input, all device bodies, opaque teleport, source-specific return and reset.
var checks: int = 0
var failures: int = 0
var world: Node3D
var player: CharacterBody3D
var portal: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ",label," ",detail)

func frames(count: int) -> void:
	for _i in range(count): await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func approach(computer: Dictionary) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = player.RADIUS
	capsule.height = player.HEIGHT-.06
	for radius: float in [.85,1.15,1.5,1.7]:
		for i: int in range(24):
			var angle: float = TAU*i/24.0
			var feet := Vector3(computer.point.x+cos(angle)*radius,float(computer.floor)+.025,computer.point.z+sin(angle)*radius)
			var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.2,feet-Vector3.UP*.2,1))
			if floor_hit.is_empty() or absf(floor_hit.position.y-float(computer.floor))>.04: continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*(player.HEIGHT*.5+.04))
			query.collision_mask = 1|8
			if not space.intersect_shape(query).is_empty(): continue
			player.global_position = feet
			var toward: Vector3 = computer.point-feet
			player.camera_pivot.rotation.y = atan2(-toward.x,-toward.z)
			var selected: Dictionary = portal.reachable_computer()
			if not selected.is_empty() and selected.id == computer.id: return feet
	return Vector3.INF

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	player = world.player
	player.set_controls_active(false)
	portal = world.computer_portal
	# Developer review retains every computer's art-preview route, including the
	# reception display whose normal game interaction is now check-in.
	world.set_building_review_mode(true)
	await frames(2)
	check("all17 computers register once",portal.computers.size()==17)
	check("room is offstage and inactive before use",not portal.inside and not portal.room.visible and portal.room.global_position==Vector3(32,5.058,-48))
	var origins: Dictionary = {}
	var ids: Array[String] = []
	for computer: Dictionary in portal.computers:
		ids.append(computer.id)
		check("computer world label stays hidden "+computer.id,not computer.label.visible)
		var point: Vector3 = approach(computer)
		check("device has a clear reachable approach "+computer.id,point.is_finite(),point)
		if point.is_finite(): origins[computer.id] = point
	check("bases, stands, TV and projector have no duplicate prompts",ids.all(func(id: String):return not id.to_lower().contains("stand") and not id.to_lower().contains("base") and not id.to_lower().contains("tv") and not id.to_lower().contains("projection")))
	player.teleport_to(Vector3(0,0,6.7))
	await frames(5)
	check("distant use cannot teleport",not portal.try_use() and not portal.transitioning)
	var source: Dictionary = portal.computers.filter(func(c: Dictionary):return c.id.ends_with("Facilitator laptop"))[0]
	if not origins.has(source.id):
		check("primary round trip has an accessible source",false)
		print("PORTAL_RESULT checks=",checks," failures=",failures)
		quit(1); return
	player.teleport_to(Vector3(source.point.x,.85,source.point.z))
	await frames(4)
	check("computer cannot be used through another floor",not portal.try_use())
	player.teleport_to(origins[source.id],1.13)
	player.camera_pivot.rotation.x = -.38
	await frames(15)
	portal.update_prompts(1)
	check("nearest accessible computer is selected",portal.active_computer.get("id","")==source.id)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1
	obstacle.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.25,1.5,.25)
	collision.shape = box
	obstacle.add_child(collision)
	world.add_child(obstacle)
	obstacle.global_position = (player.global_position+Vector3.UP*1.25+source.point)*.5
	player.set_controls_locked(true)
	await frames(3)
	check("a blocking surface prevents using that computer",portal.reachable_computer().get("id","")!=source.id)
	obstacle.queue_free()
	await frames(3)
	player.set_controls_locked(false)
	world.set_menu_open(true)
	check("Settings blocks computer use",not portal.try_use())
	world.set_menu_open(false)
	var departure: Vector3 = player.global_position
	var departure_zoom: float = player.spring_arm.spring_length
	await key(KEY_E)
	check("E starts the computer transition",portal.transitioning and player.controls_locked and world.hud.travel_overlay.visible)
	check("repeated use is rejected during fade",not portal.try_use())
	world.go_location(1)
	check("developer travel cannot interrupt the fade",player.global_position.distance_to(departure)<.002)
	Input.action_press("walk_forward")
	await frames(3)
	Input.action_release("walk_forward")
	check("held movement cannot move the player during fade",player.global_position.distance_to(departure)<.002)
	while not portal.inside and portal.transitioning: await process_frame
	check("teleport is hidden behind an opaque fade",portal.inside and world.hud.travel_overlay.color.a>.99)
	if portal.transitioning: await portal.transition_finished
	await frames(5)
	check("player arrives on the purple-room floor",player.is_on_floor() and player.global_position.distance_to(portal.room.spawn.global_position)<.12,player.global_position)
	check("arrival restores movement and hides the fade",not player.controls_locked and not world.hud.travel_overlay.visible)
	check("room, Mr P and room lighting are active",portal.room.visible and portal.room.mrp.process_mode!=Node.PROCESS_MODE_DISABLED and player.camera.environment==portal.room.room_environment)
	check("Mr P exists once and has moved out of the classroom",world.classroom_cast.get_node_or_null("MrP")==null and world.find_children("MrP","Node3D",true,false).size()==1)
	check("purple-room location is shown",world.hud.floor_label.text=="Purple Room")
	check("bypass and room grant no entrance completion",not world.entrance_puzzle.state.solved and not world.entrance_puzzle.state.unlocked)
	check("offsite ambient NPC processing pauses",world.population.active_count==0)
	player.change_zoom(1.2)
	check("player can change zoom while exploring the room",not is_equal_approx(player.spring_arm.spring_length,departure_zoom))
	player.teleport_to(portal.room.return_point.global_position+Vector3(0,0,.3))
	await frames(8)
	portal.update_prompts(1)
	check("exit is clearly labelled and usable",portal.room.return_prompt.text=="Return to computer" and portal.context_prompt()=="E: return to computer")
	await key(KEY_E)
	if portal.transitioning: await portal.transition_finished
	await frames(5)
	check("return restores the originating computer position",player.global_position.distance_to(departure)<.05,player.global_position)
	check("return restores original view, zoom and environment",absf(player.camera_pivot.rotation.y-1.13)<.001 and absf(player.camera_pivot.rotation.x+.38)<.001 and absf(player.spring_arm.spring_length-departure_zoom)<.001 and player.camera.environment==null)
	check("unused room is hidden and suspended again",not portal.inside and not portal.room.visible and portal.room.mrp.process_mode==Node.PROCESS_MODE_DISABLED)
	var second: Dictionary = portal.computers.filter(func(c: Dictionary):return c.id=="Reception_monitor")[0]
	player.teleport_to(origins[second.id])
	# Restore the device-facing view used to find this approach. A nearby NPC
	# is now a second valid E target when the player looks the other way.
	var toward_monitor: Vector3 = second.point-player.global_position
	player.camera_pivot.rotation.y = atan2(-toward_monitor.x,-toward_monitor.z)
	await frames(10)
	var second_departure: Vector3 = player.global_position
	await key(KEY_E)
	if portal.transitioning: await portal.transition_finished
	check("another computer can enter the same room",portal.inside)
	player.teleport_to(portal.room.global_position+Vector3(1.5,.03,-2))
	await frames(5)
	await key(KEY_R)
	await frames(5)
	check("R safely resets within the purple room",portal.inside and player.global_position.distance_to(portal.room.spawn.global_position)<.12)
	player.teleport_to(portal.room.return_point.global_position)
	await frames(6)
	await key(KEY_E)
	if portal.transitioning: await portal.transition_finished
	await frames(5)
	check("return also restores a reception computer origin",not portal.inside and player.global_position.distance_to(second_departure)<.05)
	await key(KEY_E)
	if portal.transitioning: await portal.transition_finished
	check("computer remains reusable after repeated returns",portal.inside)
	player.change_zoom(-.5)
	world.go_location(2)
	await frames(5)
	check("developer travel safely leaves the room",not portal.inside and not portal.room.visible and player.camera.environment==null and player.global_position.distance_to(world.LOCATIONS[2])<.12)
	check("room zoom does not leak into developer travel",is_equal_approx(player.spring_arm.spring_length,departure_zoom))
	print("PORTAL_RESULT checks=",checks," failures=",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
