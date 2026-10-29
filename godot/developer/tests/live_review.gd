extends SceneTree
## Local engine review harness. Fixed JSON commands, no OS input or network server.

const DIRECTORY: String = "res://.godot/playtest/"
const COMMAND: String = DIRECTORY + "review-command.json"
const CANCEL: String = DIRECTORY + "review-cancel"
var world: Node3D
var busy: bool = true
var elapsed: float = 0.0
var session_id: String
var request_id: String = ""
var scene_generation: int = 0
var loaded_sources: Dictionary = {}

func _initialize() -> void:
	session_id = "%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	call_deferred("start")

func start() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	# Old commands must never run in a newly opened review session.
	for path: String in [COMMAND,CANCEL]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	write_report({"ready":false,"busy":true,"starting":true})
	if not await reload_scene():
		busy = false
		write_report({"ready":false,"error":"Scene reload failed"})
		return
	loaded_sources = source_hashes()
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
			request_id = str(request.get("request_id",""))
			var steps: Variant = request.get("steps",[request])
			if request.get("session_id","") != session_id or request_id.is_empty():
				write_report({"ready":true,"error":"Stale or unidentified review request; use the launcher command client."})
				busy = false
			elif not steps is Array or steps.is_empty() or steps.size()>32 or steps.any(func(step: Variant):return not step is Dictionary):
				write_report({"ready":true,"error":"Expected 1 to 32 review step objects."})
				busy = false
			else:
				write_report({"ready":false,"busy":true})
				execute(request)
		else:
			write_report({"error": "Expected a JSON object"})
			busy = false
	return false

func reload_scene() -> bool:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	# Reset play state while retaining the process and its imported resource cache.
	# Partial hot-reloading only four scripts used to leave other code stale.
	var packed: PackedScene = load("res://Main.tscn")
	world = packed.instantiate()
	if world.get_script() == null:
		return false
	root.add_child(world)
	for _i in range(12):
		await physics_frame
	world.player.set_controls_active(true)
	scene_generation += 1
	return world.ready_for_test

func source_hashes() -> Dictionary:
	var paths: Array[String] = ["res://Main.tscn","res://project.godot","res://icon.svg","res://developer/DeveloperTools.gd","res://developer/tests/live_review.gd","res://developer/tests/CourseReviewPilot.gd","res://developer/tests/CourseWorldPilot.gd","res://developer/tests/NPCRoutineReviewPilot.gd","res://developer/tests/NPCTestPilot.gd"]
	paths.append("res://developer/tests/ProgressHUDReviewPilot.gd")
	var directories: Array[String] = ["res://game","res://scenes","res://assets","res://developer/course"]
	while not directories.is_empty():
		var folder: String = directories.pop_back()
		for child: String in DirAccess.get_directories_at(folder):
			if not child.begins_with("."): directories.append(folder+"/"+child)
		for child: String in DirAccess.get_files_at(folder):
			if child.get_extension() in ["gd","tscn","json","glb","png","jpg","ogg","wav","svg"]: paths.append(folder+"/"+child)
	paths.sort()
	var hashes: Dictionary = {}
	for path: String in paths: hashes[path] = FileAccess.get_sha256(path)
	return hashes

func changed_sources() -> Array[String]:
	var current: Dictionary = source_hashes()
	var changed: Array[String] = []
	for path: String in current:
		if current[path] != loaded_sources.get(path,""): changed.append(path)
	for path: String in loaded_sources:
		if not current.has(path): changed.append(path)
	return changed

func execute(request: Dictionary) -> void:
	var results: Array[Dictionary] = []
	var steps: Array = request.get("steps", [request])
	var changed: Array[String] = changed_sources()
	if not changed.is_empty() and steps.any(func(step: Dictionary):return step.get("action","")!="status"):
		write_report({"ready":true,"changed_sources":changed,"error":"Loaded source or assets changed. Save/import and restart the play instance; keep the editor open. This session was left running."})
		busy = false
		return
	for step: Dictionary in steps:
		if step.get("action","") == "status":
			var status: Dictionary = layout_report()
			status["changed_sources"] = changed
			results.append(status)
			continue
		if FileAccess.file_exists(CANCEL):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CANCEL))
			world.player.set_controls_active(true)
			write_report({"ready":true,"cancelled":true,"results":results})
			busy = false
			return
		if step.get("action", "") in ["reset","reload"]:
			if not await reload_scene():
				write_report({"ready":false,"error":"Scene reload failed"})
				busy = false
				return
		if step.get("action","") in ["course_playthrough","npc_routines","progress_hud"]:
			# Explicit fixture request: reset play in this process, never the editor.
			if not await reload_scene():
				write_report({"ready":false,"error":"Course fixture reset failed"});busy=false;return
			var pilot_path: String = "res://developer/tests/NPCRoutineReviewPilot.gd" if step.action=="npc_routines" else "res://developer/tests/CourseReviewPilot.gd"
			if step.action=="progress_hud": pilot_path="res://developer/tests/ProgressHUDReviewPilot.gd"
			var pilot: RefCounted = load(pilot_path).new()
			var proof: Dictionary = await pilot.run(self)
			results.append({str(step.action):proof})
			continue
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
			# Handling E may open the encounter rather than starting a ride.
			if started and world.lift_in_progress and step.get("await_lift", false):
				await world.lift_finished
		world.hud.set_debug_mode(step.get("debug", false))
		world.set_menu_open(step.get("menu", false),step.get("debug", false))
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
		if not walked:
			world.player.set_controls_active(true)
			var cancelled: bool = FileAccess.file_exists(CANCEL)
			if cancelled: DirAccess.remove_absolute(ProjectSettings.globalize_path(CANCEL))
			write_report({"ready":true,"cancelled":cancelled,"stopped_on_failed_walk":not cancelled,"results":results})
			busy = false
			return
	write_report({"ready": true, "results": results})
	busy = false

func walk_to(target: Vector3) -> bool:
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	var arrived: bool = false
	for _i in range(800):
		if FileAccess.file_exists(CANCEL): break
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
	return arrived and absf(world.player.global_position.y-target.y)<.12 and world.player.is_on_floor()

func layout_report() -> Dictionary:
	var report := {"viewport": str(root.get_visible_rect()), "hud": str(world.hud.get_global_rect()), "feet": str(world.player.global_position)}
	report["progress"] = world.orchestrator.snapshot()
	report["frame"] = Engine.get_process_frames()
	report["keypad"] = {"mounted":world.entrance_keypad.mounted,"position":str(world.entrance_keypad.global_position),"status":world.entrance_keypad.status.text}
	for key: String in ["hint_panel", "hint_label", "menu_panel", "controls_label"]:
		var control: Control = world.hud.get(key)
		var details := {"rect": str(control.get_global_rect()), "minimum": str(control.get_combined_minimum_size()), "visible": control.is_visible_in_tree()}
		if control is Label:
			details["lines"] = control.get_line_count()
			details["visible_lines"] = control.get_visible_line_count()
		report[key] = details
	return report

func write_report(data: Dictionary) -> void:
	data["engine_pid"] = OS.get_process_id()
	data["session_id"] = session_id
	data["request_id"] = request_id
	data["scene_generation"] = scene_generation
	data["busy"] = data.get("busy",false)
	data["source_fingerprint"] = JSON.stringify(loaded_sources).sha256_text()
	var file := FileAccess.open(DIRECTORY + "review-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("REVIEW_RESULT ", JSON.stringify(data))
