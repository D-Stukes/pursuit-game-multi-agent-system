extends RefCounted
## Input-driven social turns in one review process; approach positions are fixtures.
const Setup = preload("res://developer/tests/NPCTestPilot.gd")
var host: SceneTree
var world: Node3D
var failures: Array[String] = []
var captures: Array[String] = []
var motions: Array[Dictionary] = []
var prefix: String
func frames(count: int = 4) -> void:
	for _index: int in range(count): await host.physics_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await host.process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await host.process_frame;await frames(2)
func check(ok: bool, message: String) -> bool:
	if not ok: failures.append(message)
	return ok
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = prefix+label+".png"
	if check(host.root.get_texture().get_image().save_png(path)==OK,"Screenshot failed: "+label): captures.append(path)
func run(tree: SceneTree) -> Dictionary:
	host=tree;world=host.world;prefix="res://.godot/playtest/routines-"+str(host.request_id)+"-"
	world.frame_budget_enabled=false;Engine.max_fps=60
	world.npc_conversations.cooldown=999
	if not check(world.npc_conversations.client.provider=="local","Proof requires a local-only review session"): return finish()
	host.root.size=Vector2i(1280,720);host.root.content_scale_size=Vector2i(1280,720)
	for record: Dictionary in world.npc_conversations.actors:
		var actor: CharacterBody3D = record.actor
		var toward: Vector3 = actor.routine.waypoints[0]-actor.global_position
		if not check(Setup.approach(world,record.id,atan2(-toward.z,-toward.x)).is_finite(),"No clear talk approach: "+record.id): return finish()
		world.player.set_controls_active(true);await frames(6);await key(KEY_E)
		if not check(world.npc_conversations.active_npc==record.id and world.npc_conversations.dialogue.visible,"E did not open "+record.id): return finish()
		await capture(record.id+"-conversation")
		world.npc_conversations.dialogue.choices[0].grab_focus();await key(KEY_ENTER);await frames()
		if not check(not world.npc_conversations.dialogue.waiting,"Scripted/local reply not complete: "+record.id): return finish()
		if record.id=="EntranceHost":
			host.root.size=Vector2i(800,600);host.root.content_scale_size=Vector2i(800,600);await frames(6)
			check(host.root.get_visible_rect().encloses(world.npc_conversations.dialogue.panel.get_global_rect()),"Host panel outside 800x600")
			await capture("EntranceHost-800")
			host.root.size=Vector2i(1280,720);host.root.content_scale_size=Vector2i(1280,720);await frames(6)
		var before: Vector3 = actor.global_position
		await key(KEY_ESCAPE);await frames(12)
		world.population.update_budget()
		await capture(record.id+"-walking-a")
		var bones: Array[Transform3D] = []
		for index: int in range(actor.skeleton.get_bone_count()): bones.append(actor.skeleton.get_bone_global_pose(index))
		await frames(12)
		var pose_delta: float = 0
		for index: int in range(bones.size()): pose_delta+=bones[index].origin.distance_to(actor.skeleton.get_bone_global_pose(index).origin)
		check(actor.global_position.distance_to(before)>.25,"No post-conversation movement: "+record.id)
		check(actor.current_clip=="Walk" and pose_delta>.001,"Walking pose did not animate: "+record.id)
		check(absf(actor.global_position.y-float(actor.record.position[1]))<.03,"Feet left floor: "+record.id)
		motions.append({"id":record.id,"start":str(before),"end":str(actor.global_position),"distance":actor.global_position.distance_to(before),"pose_delta":pose_delta,"clip":actor.current_clip})
		await capture(record.id+"-walking-b")
		if record.id=="BuilderCompanion":
			var paused: Vector3 = actor.global_position
			await key(KEY_F3);await frames(12)
			check(actor.global_position.distance_to(paused)<.04,"Settings did not freeze walking")
			await capture("BuilderCompanion-settings-pause");await key(KEY_F3)
	check(world.npc_conversations.requests_started==0,"Routine proof called a provider")
	var state: Dictionary = world.orchestrator.snapshot()
	check(not state.gates.entrance and not state.gates.elevator and state.course.score==0 and state.course.energy==10,"Social proof changed course awards")
	return finish()
func finish() -> Dictionary:
	world.frame_budget_enabled=true;world._apply_frame_budget(host.root.has_focus())
	var proof: Dictionary = {"passed":failures.is_empty(),"failures":failures,"engine_pid":OS.get_process_id(),"provider_calls":world.npc_conversations.requests_started,
		"setup":"collision-probed approach/room positions are fixtures; no earlier gate wins are fabricated",
		"input":"normal E / focused Enter / Escape / F3; post-conversation locomotion uses real physics",
		"captures":captures,"motions":motions,"final":world.orchestrator.snapshot(),"source_hashes":{}}
	for path: String in ["game/Main.gd","game/NPCConversations.gd","game/NPCConversationState.gd","game/characters/AmbientNPC.gd","game/characters/BuildingPopulation.gd","game/characters/NPCRoutineState.gd","assets/characters/population.json","assets/characters/npc-dialogue.json","scenes/characters/AmbientNPC.tscn","developer/tests/NPCTestPilot.gd","developer/tests/NPCRoutineReviewPilot.gd","developer/tests/live_review.gd"]:
		proof.source_hashes[path]=FileAccess.get_sha256("res://"+path)
	var file:=FileAccess.open(prefix+"receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof,"  "));file.close()
	proof.receipt=prefix+"receipt.json"
	return proof
