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
			world.try_lift()
		world.hud.set_debug_mode(step.get("debug", false))
		world.set_menu_open(step.get("menu", false))
		await create_timer(step.get("wait", 0.2)).timeout
		await RenderingServer.frame_post_draw
		var result: Dictionary = layout_report()
		if step.has("capture"):
			var filename: String = step["capture"]
			if filename.is_valid_filename() and filename.ends_with(".png"):
				result["capture"] = filename
				result["image_error"] = root.get_texture().get_image().save_png(DIRECTORY + filename)
			else:
				result["error"] = "Invalid capture filename"
		if step.get("resume", false):
			world.set_menu_open(false)
			world.player.set_controls_active(true)
		results.append(result)
	write_report({"ready": true, "results": results})
	busy = false

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
