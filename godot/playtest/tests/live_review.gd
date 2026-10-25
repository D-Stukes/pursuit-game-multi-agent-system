extends SceneTree
## Local engine review harness. Fixed JSON commands, no OS input or network server.

const DIRECTORY: String = "res://.godot/playtest/"
const COMMAND: String = DIRECTORY + "review-command.json"
var world: Node3D
var busy: bool = true
var elapsed: float = 0.0

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	await reload_scene()
	busy = false
	write_report({"ready": true})

func _process(delta: float) -> bool:
	elapsed += delta
	if busy or elapsed < 0.2:
		return false
	elapsed = 0.0
	if FileAccess.file_exists(COMMAND):
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMMAND))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(COMMAND))
		busy = true
		if request is Dictionary:
			execute(request)
		else:
			write_report({"error": "Expected a JSON object"})
			busy = false
	return false

func reload_scene() -> void:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	for path: String in ["PlaytestHUD.gd", "ExteriorBackdrop.gd", "BuildingPlayer.gd", "BuildingPlaytest.gd"]:
		var resource_path: String = "res://playtest/" + path
		var script: Script = load(resource_path)
		script.source_code = FileAccess.get_file_as_string(resource_path)
		var error: Error = script.reload(true)
		if error != OK:
			push_error("Reload failed: " + path)
	var packed: PackedScene = ResourceLoader.load("res://BuildingPlaytest.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	world = packed.instantiate()
	world.refresh_building_resources = true
	root.add_child(world)
	for _i in range(12):
		await physics_frame
	world.player.set_controls_active(true)

func execute(request: Dictionary) -> void:
	var results: Array[Dictionary] = []
	var steps: Array = request.get("steps", [request])
	for step: Dictionary in steps:
		if step.get("action", "") == "reload":
			await reload_scene()
		if step.has("size"):
			root.size = Vector2i(step["size"][0], step["size"][1])
		if step.has("feet"):
			world.player.teleport_to(Vector3(step["feet"][0], step["feet"][1], step["feet"][2]), step.get("yaw", 0.0))
		if step.has("look"):
			world.player.apply_look(Vector2(step["look"][0], step["look"][1]))
		world.player.set_controls_active(false)
		world.player.camera_pivot.rotation.x = step.get("pitch", world.player.camera_pivot.rotation.x)
		world.player.spring_arm.spring_length = step.get("zoom", world.player.spring_arm.spring_length)
		if step.has("visual_yaw"):
			world.player.visual.rotation.y = step["visual_yaw"]
		if step.has("hint"):
			world.hud.hint_panel.visible = step["hint"]
			if step["hint"]:
				world.hud.hint_timer.start()
		if step.get("lift", false):
			var started: bool = world.try_lift()
			if started and step.get("await_lift", false):
				await world.lift_finished
		world.hud.set_debug_mode(step.get("debug", false))
		world.set_menu_open(step.get("menu", false))
		var walked: bool = true
		if step.has("walk_to"):
			walked = await walk_to(Vector3(step["walk_to"][0], step["walk_to"][1], step["walk_to"][2]))
		var hidden: Array[MeshInstance3D] = []
		if step.get("cutaway", false):
			for mesh: MeshInstance3D in world.get_node("Building").find_children("*", "MeshInstance3D", true, false):
				var box: AABB = mesh.global_transform * mesh.get_aabb()
				if mesh.visible and box.position.y > 8.4:
					hidden.append(mesh)
					mesh.hide()
		var review_camera: Camera3D
		if step.has("camera") and step.has("target"):
			review_camera = Camera3D.new()
			world.add_child(review_camera)
			review_camera.position = Vector3(step["camera"][0], step["camera"][1], step["camera"][2])
			var target := Vector3(step["target"][0], step["target"][1], step["target"][2])
			review_camera.look_at(target, Vector3.FORWARD if step.get("ortho", false) else Vector3.UP)
			review_camera.fov = step.get("fov", 65.0)
			if step.get("ortho", false):
				review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
				review_camera.size = step.get("ortho_size", 55.0)
			review_camera.make_current()
		await create_timer(step.get("wait", 0.2)).timeout
		await RenderingServer.frame_post_draw
		var result: Dictionary = layout_report()
		if step.has("walk_to"):
			result["walk_arrived"] = walked
		if step.has("capture"):
			var filename: String = step["capture"]
			if filename.is_valid_filename() and filename.ends_with(".png"):
				result["capture"] = filename
				result["image_error"] = root.get_texture().get_image().save_png(DIRECTORY + filename)
			else:
				result["error"] = "Invalid capture filename"
		if review_camera:
			review_camera.queue_free()
			world.player.camera.make_current()
		for mesh in hidden:
			mesh.show()
		if step.get("resume", false):
			world.set_menu_open(false)
			world.player.set_controls_active(true)
		results.append(result)
	write_report({"ready": true, "results": results})
	busy = false

func walk_to(target: Vector3) -> bool:
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool = false
	for _i in range(800):
		var delta: Vector3 = target - world.player.global_position
		delta.y = 0
		if delta.length() < .16:
			arrived = true
			break
		world.player.camera_pivot.rotation.y = atan2(-delta.x, -delta.z)
		await physics_frame
	Input.action_release("walk_forward")
	world.player.set_controls_active(false)
	for _i in range(12):
		await physics_frame
	return arrived

func layout_report() -> Dictionary:
	var report := {"viewport": str(root.get_visible_rect()), "hud": str(world.hud.get_global_rect()), "feet": str(world.player.global_position)}
	for key: String in ["hint_panel", "hint_label", "menu_panel", "controls_label"]:
		var control: Control = world.hud.get(key)
		var details := {"rect": str(control.get_global_rect()), "minimum": str(control.get_combined_minimum_size()), "visible": control.is_visible_in_tree()}
		if control is Label:
			details["lines"] = control.get_line_count()
			details["visible_lines"] = control.get_visible_line_count()
		report[key] = details
	return report

func write_report(data: Dictionary) -> void:
	var file := FileAccess.open(DIRECTORY + "review-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("REVIEW_RESULT ", JSON.stringify(data))
