extends "res://developer/tests/EndingReviewPilot.gd"
## Continuous player-input route. No progress fixtures, developer travel or teleports.
const Pipes=preload("res://developer/tests/PipeTestPilot.gd")
var held: Dictionary={}
var passes: Array[Dictionary]=[]
var current: Dictionary={}
var checkpoints: Array[Dictionary]=[]
var target_computer: Dictionary={}

func hold(code: Key, down: bool) -> void:
	if held.get(code,false)==down: return
	held[code]=down
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
	Input.parse_input_event(event)

func cancelled() -> bool:
	return FileAccess.file_exists(host.CANCEL)

func checkpoint(label: String) -> void:
	checkpoints.append({"label":label,"feet":str(world.player.global_position),"progress":world.orchestrator.snapshot()})
	var file:=FileAccess.open(prefix+"progress.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checkpoints":checkpoints,"failures":failures},"  "));file.close()
	print("FULL_ROUTE_CHECKPOINT ",label," ",str(world.player.global_position))

func require(ok: bool, label: String) -> bool:
	verify(ok,label)
	if not ok: checkpoint("FAILED: "+label)
	return ok

func capture(label: String) -> void:
	if world.entrance_puzzle.visible:
		verify(host.root.get_visible_rect().encloses(world.entrance_puzzle.panel.get_global_rect()),"Pipe panel clipped: "+label)
	if world.check_in.is_open:
		verify(host.root.get_visible_rect().encloses(world.check_in.panel.get_global_rect()),"Check-in panel clipped: "+label)
	await super.capture(str(passes.size()+1)+"-"+label)

func type_text(field: LineEdit, text: String) -> void:
	field.grab_focus();await host.process_frame
	field.select_all();await key(KEY_BACKSPACE)
	for character: String in text:
		var event:=InputEventKey.new();event.keycode=character.to_upper().unicode_at(0);event.physical_keycode=event.keycode;event.unicode=character.unicode_at(0);event.pressed=true
		Input.parse_input_event(event);await host.process_frame;await frames(2)
		event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await host.process_frame;await frames(2)

func walk_to(target: Vector3) -> bool:
	world.player.set_controls_active(true)
	Input.action_press("walk_forward")
	var deadline: int=Time.get_ticks_msec()+14000
	while Time.get_ticks_msec()<deadline and not cancelled():
		var toward: Vector3=target-world.player.global_position;toward.y=0
		if toward.length()<.14: break
		world.player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)
		await host.physics_frame
	Input.action_release("walk_forward");await frames(4)
	var distance: Vector3=target-world.player.global_position
	return require(Vector2(distance.x,distance.z).length()<.22 and absf(distance.y)<.25,"Walk to "+str(target)+" reached "+str(world.player.global_position))

func entrance() -> bool:
	checkpoint("fresh entrance")
	await capture("start")
	var approach: Vector3=world.entrance_keypad.global_position+Vector3(0,0,.95);approach.y=world.ENTRANCE_POINT.y+.03
	if not await walk_to(approach+Vector3(0,0,1.3)) or not await walk_to(approach): return false
	face(world.entrance_keypad.global_position);await key(KEY_E)
	var puzzle: Control=world.entrance_puzzle
	if puzzle.guide.visible: await activate(puzzle.guide_button)
	if not require(puzzle.visible and world.orchestrator.snapshot().interaction=="entrance","E opens physical entrance keypad"): return false
	for level: int in range(1):
		var turns: Dictionary=Pipes.route(puzzle.state)
		if not require(not turns.is_empty(),"Visible pipe shapes have a route"): return false
		for index: int in turns:
			for _i: int in range(turns[index]): await activate(puzzle.tiles[index])
		await activate(puzzle.check_button)
		if not require(puzzle.state.level_cleared and not world.orchestrator.entrance_allowed(),"Circuit verified; door still requires its code"): return false
		current.levels.append({"level":level+1,"phrase":puzzle.reward_label.text,"moves":puzzle.state.moves})
		await capture("pipe-level-"+str(level+1))
	var earned_code: String=puzzle.state.revealed_code()
	await type_text(puzzle.code_input,"0000" if earned_code!="0000" else "1111");await key(KEY_ENTER)
	if not require(not world.orchestrator.entrance_allowed(),"Wrong entry code is rejected"): return false
	await type_text(puzzle.code_input,earned_code);await key(KEY_ENTER)
	if not require(world.orchestrator.snapshot().stage=="elevator" and world.entrance_gate.collision_layer==0,"Earned code unlocks building"): return false
	await capture("entry-earned");await activate(puzzle.close_button)
	if not await walk_to(approach+Vector3(0,0,1.3)) or not await walk_to(Vector3(world.ENTRANCE_POINT.x,world.ENTRANCE_POINT.y,approach.z+1.3)): return false
	for point: Vector3 in [Vector3(0,0,3),Vector3(2.35,0,3),Vector3(2.35,.85,-4.8),Vector3(2.35,.85,-6.6),Vector3(2.35,.85,-9.4),Vector3(1.05,.85,-12.1),world.LIFT_GROUND]:
		if not await walk_to(point): return false
	checkpoint("lower elevator reached on foot");await capture("lower-elevator")
	return true

func face(point: Vector3) -> void:
	var toward: Vector3=point-world.player.global_position
	world.player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)

func flight(seed_value: int) -> bool:
	await key(KEY_E)
	var game: Control=world.elevator_game
	if not require(game.visible and world.orchestrator.snapshot().interaction=="shooter","E opens lower elevator shooter"): return false
	# Reproducibility only. No enemies, shots, shields, clock or wins are written.
	game.state.rng.seed=seed_value
	current.arcade_seed=seed_value;current.flights=[]
	for attempt: int in range(3):
		await activate(game.primary_button);hold(KEY_SPACE,true)
		var started: int=Time.get_ticks_msec();var shown: bool=false
		while game.state.phase not in ["won","lost"] and Time.get_ticks_msec()-started<90000 and not cancelled():
			var state: RefCounted=game.state
			var target: float=state.ship.x
			if not state.enemies.is_empty():
				var enemy: Dictionary=state.enemies[0]
				target=enemy.home.x+sin((state.clock+(state.ship.y-enemy.at.y)/state.SHOT_SPEED)*.95+enemy.offset)*105
			hold(KEY_D,target-state.ship.x>6);hold(KEY_A,target-state.ship.x< -6)
			if not shown and state.clock>1.2:
				await capture("flight-"+str(attempt+1));shown=true
				if passes.is_empty() and attempt==0:
					for code: Key in [KEY_SPACE,KEY_A,KEY_D]: hold(code,false)
					await key(KEY_P);var paused_clock: float=state.clock
					await capture("flight-paused")
					if not require(state.paused and is_equal_approx(state.clock,paused_clock),"P pauses actual flight"): return false
					await key(KEY_ESCAPE)
					if not require(not game.visible and not world.orchestrator.ascent_allowed(),"Close flight preserves locked upstairs"): return false
					await key(KEY_E)
					if not require(game.visible and state.clock>=paused_clock,"Reopening flight resumes its existing encounter"): return false
					hold(KEY_SPACE,true)
			await host.process_frame
		for code: Key in [KEY_SPACE,KEY_A,KEY_D]: hold(code,false)
		await frames()
		current.flights.append({"phase":game.state.phase,"cleared":game.state.cleared,"shields":game.state.shields,"seconds":game.state.clock})
		if game.state.completed(): break
		if not require(game.state.phase=="lost" and not world.orchestrator.ascent_allowed(),"Lost flight leaves upstairs locked and allows retry"): return false
	if not require(game.state.completed() and world.orchestrator.gates_earned(),"Flight earned both gate results through input"): return false
	await capture("flight-earned");await activate(game.primary_button)
	var deadline: int=Time.get_ticks_msec()+10000
	while not world.lift_in_progress and Time.get_ticks_msec()<deadline: await host.process_frame
	if not require(world.lift_in_progress,"Ride upstairs starts a real elevator trip"): return false
	await world.lift_finished;await frames(12)
	if not require(world.orchestrator.snapshot().stage=="check_in_pending" and world.player.global_position.distance_to(world.UPPER_LIFT_EXIT)<.12,"Elevator arrives upstairs without a fixture"): return false
	checkpoint("upstairs gate handoff");await capture("upstairs-arrival")
	return true

func arrival(name_value: String) -> bool:
	for point: Vector3 in [Vector3(1.05,5.05,-7.6),Vector3(1.05,5.05,-5.22),Vector3(3.1,5.05,-5.22)]:
		if not await walk_to(point): return false
	face(world.check_in.computer.point);await key(KEY_E)
	var console: Node=world.check_in
	if not require(console.is_open,"Reception E opens check-in"): return false
	await capture("check-in-name")
	await type_text(console.name_input,name_value);await key(KEY_ENTER)
	await host.create_timer(.6).timeout;await capture("check-in-photo")
	await key(KEY_ENTER)
	if not require(world.orchestrator.checked_in(),"Typed name and photo confirmation verify check-in"): return false
	await capture("checked-in");await key(KEY_ENTER)
	var sequence: Node=world.classroom_sequence
	var deadline: int=Time.get_ticks_msec()+24000
	for beat: String in ["walk","stand_up","crowd","get_to_work"]:
		while sequence.active and sequence.phase!=beat and Time.get_ticks_msec()<deadline: await host.process_frame
		if not require(sequence.active and sequence.phase==beat,"Classroom beat "+beat): return false
		await capture("classroom-"+beat)
	while sequence.active and Time.get_ticks_msec()<deadline: await host.process_frame
	if not require(not sequence.active and world.orchestrator.snapshot().stage=="mr_p_pending" and not world.player.controls_locked,"Classroom releases player to the computer objective"): return false
	checkpoint("classroom ready")
	return true

func _clear_feet(feet: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var floor_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.2,feet-Vector3.UP*.25,1))
	if floor_hit.is_empty() or floor_hit.normal.y<.9 or absf(floor_hit.position.y-feet.y)>.1: return false
	var capsule:=CapsuleShape3D.new();capsule.radius=world.player.RADIUS+.02;capsule.height=world.player.HEIGHT
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1|4|8;query.exclude=[world.player.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*(world.player.HEIGHT*.5+.04))
	return space.intersect_shape(query).is_empty()

func _computer_at(feet: Vector3) -> Dictionary:
	for device: Dictionary in world.computer_portal.computers:
		if device.id==world.check_in.computer.id: continue
		var toward: Vector3=device.point-feet;toward.y=0
		if toward.length()>1.65 or absf(float(device.floor)-feet.y)>.15: continue
		var npc_wins: bool=false
		for actor: Dictionary in world.npc_conversations.actors:
			var offset: Vector3=actor.actor.global_position-feet
			if absf(offset.y)>.5: continue
			offset.y=0
			if offset.length()>world.npc_conversations.INTERACTION_RADIUS: continue
			var alignment: float=toward.normalized().dot(offset.normalized())
			if alignment>=.3 and offset.length_squared()+4*(1-alignment)<toward.length_squared(): npc_wins=true;break
		if npc_wins: continue
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*1.25,device.point,1))
		if hit.is_empty() or hit.position.distance_to(device.point)<.16: return device
	return {}

func computer_path() -> Array[Vector3]:
	# Test-side collision search; it never moves the player to probe candidates.
	var origin: Vector3=world.player.global_position
	var queue: Array[Vector2i]=[Vector2i.ZERO];var parent: Dictionary={Vector2i.ZERO:Vector2i.ZERO};var next: int=0
	while next<queue.size() and next<4000:
		var cell: Vector2i=queue[next];next+=1
		var feet: Vector3=origin+Vector3(cell.x*.35,0,cell.y*.35)
		var device: Dictionary=_computer_at(feet)
		if not device.is_empty():
			target_computer=device
			var path: Array[Vector3]=[]
			while cell!=Vector2i.ZERO:
				path.push_front(origin+Vector3(cell.x*.35,0,cell.y*.35));cell=parent[cell]
			return path
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var candidate: Vector2i=cell+offset
			if parent.has(candidate): continue
			var point: Vector3=origin+Vector3(candidate.x*.35,0,candidate.y*.35)
			if point.x< -14.8 or point.x>2.8 or point.z< -3.6 or point.z>4.5 or not _clear_feet(point): continue
			parent[candidate]=cell;queue.append(candidate)
	return []

func portal_and_course(stress: bool) -> bool:
	var selected: bool=false
	for _try: int in range(3):
		target_computer={}
		var path: Array[Vector3]=computer_path()
		if not require(not target_computer.is_empty(),"Collision search found a classroom computer route"): return false
		for point: Vector3 in path:
			if not await walk_to(point): return false
		face(target_computer.point);await frames(10)
		var device: Dictionary=world.computer_portal.reachable_computer()
		if not device.is_empty() and not world.prefers_npc(world.npc_conversations.reachable_npc(),device): selected=true;break
	if not require(selected,"Computer wins the actual E target over nearby NPCs"): return false
	await key(KEY_E)
	if world.computer_portal.transitioning: await world.computer_portal.transition_finished
	if not require(world.computer_portal.inside and world.orchestrator.snapshot().course.score==0,"Classroom computer enters purple world without course rewards"): return false
	checkpoint("purple world entered");await capture("purple-world")
	if not await open_sample(): return false
	if stress:
		await answer("guess");await capture("first-error")
		if not require(world.orchestrator.snapshot().course.energy==9 and world.orchestrator.snapshot().course.attempts==1,"First wrong answer rephrases and costs one"): return false
		await answer("guess");await activate(world.sample_course.help_button);await capture("second-error-help")
		if not require(world.orchestrator.snapshot().course.energy==8 and world.orchestrator.snapshot().course.help_available,"Second wrong answer offers stronger help"): return false
		for _i: int in range(8): await answer("guess")
		if not require(world.orchestrator.snapshot().course.energy==0 and world.sample_course.notice.text.begins_with("Recovery needed:") and not world.sample_course.notice.text.contains("keep trying"),"Real wrong submissions reach zero with recovery-first instructions"): return false
		await capture("zero-energy");await activate(world.sample_course.recovery_button);await activate(world.sample_course.recovery_decline)
		if not require(world.orchestrator.snapshot().course.energy==0,"Declining recovery retains zero"): return false
		await key(KEY_ESCAPE)
		if not await open_sample(): return false
		await activate(world.sample_course.recovery_button);await activate(world.sample_course.recovery_confirm)
		if not require(world.orchestrator.snapshot().course.energy==10 and world.orchestrator.snapshot().course.attempts==10,"Confirmed recovery refills without erasing attempts"): return false
		await capture("recovered")
	for choice: String in ["observe","decide","verify","return"]:
		if not await answer(choice): return false
	if not require(world.orchestrator.snapshot().course.complete and world.orchestrator.snapshot().course.score==60 and world.orchestrator.snapshot().course.robot_parts.is_empty() and not world.ending_sequence.active,"Required sample set verifies while Lady D's robot stays unchanged"): return false
	await capture("sample-complete");checkpoint("sample results verified")
	await key(KEY_ESCAPE)
	for beat: String in ["results","assessment","celebration","complete"]:
		if not await phase(beat): return false
		await capture("ending-"+beat)
	if not require(not world.ending_sequence.preview and world.orchestrator.snapshot().ending.presented,"Earned normal ending completes after the real route"): return false
	return true

func run(tree: SceneTree) -> Dictionary:
	host=tree;world=host.world;prefix="res://.godot/playtest/full-route-"+str(host.request_id)+"-"
	world.frame_budget_enabled=false;Engine.max_fps=60
	if not require(world.npc_conversations.client.provider=="local" and not world.building_review_mode,"Full route starts without API or gate bypass"): return finish_full()
	var pid: int=OS.get_process_id()
	for index: int in range(2):
		target_computer={}
		host.root.size=Vector2i(800,600) if index==0 else Vector2i(1280,720);host.root.content_scale_size=host.root.size;await frames(8)
		current={"session":world.orchestrator.snapshot().session_id,"name":"Robin" if index==0 else "Sam","levels":[]}
		if not await entrance() or not await flight(42 if index==0 else 7) or not await arrival(current.name) or not await portal_and_course(index==0): return finish_full()
		current.final=world.orchestrator.snapshot();provider_calls+=world.npc_conversations.requests_started;passes.append(current.duplicate(true))
		var session: String=world.orchestrator.snapshot().session_id
		await activate(world.ending_sequence.action);await wait_restart(session)
		var fresh: Dictionary=world.orchestrator.snapshot()
		if not require(OS.get_process_id()==pid and fresh.session_id!=session and fresh.stage=="entrance" and fresh.course.score==0 and fresh.course.energy==10 and not fresh.gates.entrance and not fresh.gates.elevator and not fresh.arrival.checked_in and not fresh.arrival.classroom_complete and not fresh.ending.presented and world.npc_conversations.state.memories.is_empty() and world.npc_conversations.state.met_npcs.is_empty(),"Play Again starts fresh in the same process"): return finish_full()
		checkpoint("fresh replay "+str(index+1))
	await capture("replay-ready")
	return finish_full()

func finish_full() -> Dictionary:
	for code: Key in held: hold(code,false)
	Input.action_release("walk_forward")
	world=host.world
	checkpoint("finished" if failures.is_empty() else "stopped at failure")
	world.frame_budget_enabled=true;world._apply_frame_budget(host.root.has_focus())
	world.player.set_controls_active(true)
	var proof: Dictionary={"passed":failures.is_empty() and passes.size()==2,"checks":checks,"failures":failures,"engine_pid":OS.get_process_id(),"provider_calls":provider_calls+world.npc_conversations.requests_started,"passes":passes,"checkpoints":checkpoints,"captures":captures,"layouts":layouts,"source_hashes":host.loaded_sources.duplicate(true),"input":"normal held walking, camera yaw steering, E, typed name/code, focused Enter, shooter Space/A/D, F3 for the explicit sample only","setup":"fresh game only; no gate or arrival fixtures, bypass, developer travel or test teleports","final":world.orchestrator.snapshot()}
	var file:=FileAccess.open(prefix+"receipt.json",FileAccess.WRITE);file.store_string(JSON.stringify(proof,"  "));file.close()
	proof.receipt=prefix+"receipt.json"
	return proof
