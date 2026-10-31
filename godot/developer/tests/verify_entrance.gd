extends SceneTree
## Pipe UI, real keyboard input, code gate, interruption and physical doorway.
const Pilot = preload("res://developer/tests/PipeTestPilot.gd")
const KeypadPilot = preload("res://developer/tests/KeypadTestPilot.gd")
var world: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for _i: int in range(count): await physics_frame

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ",label)

func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await frames(2)

func activate(button: Button) -> void:
	button.grab_focus()
	await key(KEY_ENTER)

func layout_checks(puzzle: Control, label: String) -> void:
	for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		world.hud.size=resolution
		await frames(4)
		var bounds:=Rect2(Vector2.ZERO,resolution)
		check(label+" frame fits "+str(resolution),bounds.encloses(puzzle.panel.get_global_rect()))
		check(label+" phrase fits "+str(resolution),bounds.encloses(puzzle.reward_label.get_global_rect()) and puzzle.panel.get_global_rect().encloses(puzzle.reward_label.get_global_rect()))
		check(label+" actions fit "+str(resolution),puzzle.panel.get_global_rect().encloses(puzzle.close_button.get_global_rect()) and (not puzzle.next_button.visible or puzzle.panel.get_global_rect().encloses(puzzle.next_button.get_global_rect())) and (not puzzle.code_box.visible or puzzle.panel.get_global_rect().encloses(puzzle.code_box.get_global_rect())))

func door_clear(x: float) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,1.4,4.4),Vector3(x,1.4,5.2),1)
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func run() -> void:
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var puzzle: Control=world.entrance_puzzle
	var player: CharacterBody3D=world.player
	check("world starts with locked door and one required puzzle",world.ready_for_test and world.entrance_gate.collision_layer==4 and puzzle.tiles.size()==9 and not puzzle.state.solved)
	check("both retained door leaves start visibly and physically closed",not world.entrance_doors.open and world.entrance_doors.bodies.size()==2 and world.entrance_doors.triangle_count>0 and not door_clear(-.6) and not door_clear(.6))
	check("no early sentence or entry code",puzzle.reward_label.text=="• • •" and puzzle.state.revealed_code().is_empty() and not puzzle.state.enter_code("123"))
	puzzle.entrance_unlocked.emit()
	check("spoofed UI signal cannot unlock door",world.entrance_gate.collision_layer==4)
	await key(KEY_3)
	check("shortcut cannot bypass normal entrance",player.global_position.y<1)
	player.teleport_to(Vector3(0,0,5.7))
	await frames(10)
	player.set_controls_active(true)
	Input.action_press("walk_forward");await frames(45);Input.action_release("walk_forward")
	check("physical door blocks movement before win",player.global_position.z>4.8)
	await key(KEY_E)
	check("door center is no longer the puzzle target",not puzzle.visible)
	check("keypad mounts left of the doorway",world.entrance_keypad.mounted and world.entrance_keypad.global_position.x<world.ENTRANCE_POINT.x-1.4)
	check("keypad has twelve marked keys and locked status",world.entrance_keypad.keys.size()==12 and world.entrance_keypad.keys[9].text=="*" and world.entrance_keypad.keys[10].text=="0" and world.entrance_keypad.status.text=="LOCKED")
	KeypadPilot.approach(world);await frames(6)
	check("approaching the keypad opens the puzzle without E",puzzle.visible and player.controls_locked and world.orchestrator.snapshot().interaction=="entrance")
	check("first visit shows a short guide before play",puzzle.guide.visible and puzzle.tiles.all(func(tile: Button):return tile.disabled))
	for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
		world.hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);world.hud.size=resolution;await frames(4)
		check("guide fits "+str(resolution),Rect2(Vector2.ZERO,resolution).encloses(puzzle.guide_panel.get_global_rect()) and puzzle.guide_panel.get_global_rect().encloses(puzzle.guide_button.get_global_rect()))
	await key(KEY_TAB);await key(KEY_RIGHT)
	check("guide keeps keyboard focus and leaves pipes unchanged",root.gui_get_focus_owner()==puzzle.guide_button and puzzle.state.moves==0)
	await activate(puzzle.guide_button)
	check("guide starts without changing board or granting progress",not puzzle.guide.visible and puzzle.guide_seen and puzzle.state.moves==0 and not world.orchestrator.entrance_allowed())
	await key(KEY_ESCAPE);await frames(12)
	check("Escape stays closed while standing at the keypad",not puzzle.visible and not player.controls_locked)
	player.teleport_to(world.entrance_keypad.global_position+Vector3(0,-1.35,2.2));await frames(4)
	KeypadPilot.approach(world);await frames(5)
	check("leaving and reapproaching resumes without another guide",puzzle.visible and not puzzle.guide.visible)
	await key(KEY_ESCAPE);await frames(4)
	player.camera_pivot.rotation.y += PI
	check("automatic approach does not require camera aiming",world.entrance_keypad.can_approach(player) and not world.entrance_keypad.can_use(player))
	check("manual use still rejects looking away",not world.try_entrance())
	KeypadPilot.approach(world)
	var approach: Vector3 = player.global_position
	player.global_position += Vector3(0,0,2)
	check("distant keypad use is rejected",not world.try_entrance())
	player.global_position = approach+Vector3.UP*5
	check("keypad cannot be used from another floor",not world.try_entrance())
	KeypadPilot.approach(world);await frames(4)
	var blocker := StaticBody3D.new();blocker.collision_layer=1;blocker.collision_mask=0
	var blocking_shape := CollisionShape3D.new()
	var blocking_box := BoxShape3D.new();blocking_box.size=Vector3(.5,2,.15)
	blocking_shape.shape=blocking_box;blocker.add_child(blocking_shape);world.add_child(blocker)
	blocker.global_position=(world.entrance_keypad.global_position+player.global_position+Vector3.UP*1.25)*.5
	await frames(3)
	check("nearer obstruction blocks keypad use",not world.try_entrance())
	blocker.queue_free();await frames(3)
	check("HUD targets the same physical keypad",world.hud.prompt_label.text.contains("approach to resume") and not world.entrance_keypad.prompt.visible)
	await key(KEY_E)
	check("reopen resumes the board without repeating the guide",puzzle.visible and player.controls_locked and not puzzle.guide.visible)
	check("opening hides unrelated arrival instructions",not world.hud.hint_panel.visible and world.hud.hint_timer.is_stopped())
	puzzle.tiles[0].grab_focus()
	await key(KEY_RIGHT)
	check("right arrow selects neighboring pipe",root.gui_get_focus_owner()==puzzle.tiles[1])
	await key(KEY_DOWN)
	check("down arrow selects next pipe row",root.gui_get_focus_owner()==puzzle.tiles[4])
	var before: Vector3=player.global_position
	Input.action_press("walk_forward");await frames(10);Input.action_release("walk_forward")
	await key(KEY_R);await key(KEY_3)
	check("modal blocks movement reset and shortcuts",player.global_position.distance_to(before)<.01)
	var zoom: float=player.spring_arm.spring_length
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;Input.parse_input_event(wheel)
	await frames()
	check("modal wheel does not change camera",player.spring_arm.spring_length==zoom)
	await activate(puzzle.check_button)
	check("incorrect circuit earns no phrase or code",puzzle.state.rewards.is_empty() and puzzle.feedback.text.contains("still open") and world.entrance_gate.collision_layer==4)
	await activate(puzzle.hint_button)
	check("hint marks a pipe and explains real ports",puzzle.feedback.text.contains("Connect") and puzzle.tiles[puzzle.state.hint_index()].hinted)
	var index: int=puzzle.state.hint_index()
	var old_mask: int=puzzle.state.masks[index]
	await activate(puzzle.tiles[index])
	check("real keyboard activation rotates a tile",puzzle.state.masks[index]==puzzle.state.turn(old_mask))
	var masks: Array=puzzle.state.masks.duplicate()
	await key(KEY_ESCAPE)
	check("Escape closes without opening Settings",not puzzle.visible and not world.hud.menu_open and not player.controls_locked)
	await key(KEY_E)
	check("reopening retains exact board and moves",puzzle.visible and puzzle.state.masks==masks and puzzle.state.moves==1)
	for _i: int in range(20):
		await key(KEY_TAB)
		var focus: Control=root.gui_get_focus_owner()
		check("Tab stays in circuit panel",focus!=null and puzzle.is_ancestor_of(focus))
	await activate(puzzle.reset_button)
	check("reset changes no earlier progress",puzzle.state.moves==0 and puzzle.state.rewards.is_empty() and puzzle.state.masks==puzzle.state.initial_masks)
	await layout_checks(puzzle,"required circuit")
	var rotations: Dictionary=Pilot.route(puzzle.state)
	check("independent visible-shape pilot finds a route",not rotations.is_empty())
	for tile_index: int in rotations:
		for _i: int in range(rotations[tile_index]):await activate(puzzle.tiles[tile_index])
	check("connected preview alone grants no reward",puzzle.state.connected() and puzzle.state.rewards.is_empty())
	await activate(puzzle.check_button)
	check("one verified circuit reveals the four digit code",puzzle.state.solved and puzzle.state.revealed_code().length()==4 and puzzle.code_box.visible)
	check("verified circuit freezes tile edits",puzzle.tiles[0].disabled)
	await layout_checks(puzzle,"number pad")
	for button: Button in puzzle.keypad_buttons:
		check("number pad button remains inside panel "+button.text,puzzle.panel.get_global_rect().encloses(button.get_global_rect()))
	check("verified code reveal still requires keypad entry",puzzle.code_label.text.contains(puzzle.state.revealed_code()) and not puzzle.state.unlocked and world.entrance_gate.collision_layer==4)
	puzzle.code_input.text="0000" if puzzle.state.revealed_code()!="0000" else "1111"
	await activate(puzzle.unlock_button)
	check("wrong code is rejected with visible feedback",not puzzle.state.unlocked and puzzle.code_feedback.is_visible_in_tree() and puzzle.code_feedback.text.contains("does not match"))
	puzzle.code_input.text=puzzle.state.revealed_code()
	puzzle.code_input.grab_focus()
	await key(KEY_ENTER)
	check("correct code removes physical lock",puzzle.state.unlocked and world.entrance_gate.collision_layer==0 and not world.entrance_gate.visible)
	check("unlocked door leaves and their colliders open together",world.entrance_doors.open and door_clear(-.6) and door_clear(.6))
	check("earned entry changes keypad status and removes prompt",world.entrance_keypad.status.text=="OPEN" and not world.entrance_keypad.prompt.visible)
	check("duplicate unlock is disabled",puzzle.unlock_button.disabled and not puzzle.code_input.editable)
	var entry_code: String=puzzle.state.revealed_code()
	for level: int in range(1,4):
		await activate(puzzle.next_button)
		await layout_checks(puzzle,"optional bonus "+str(level))
		var bonus_turns: Dictionary=Pilot.route(puzzle.state)
		for bonus_index: int in bonus_turns:
			for _i: int in range(bonus_turns[bonus_index]):await activate(puzzle.tiles[bonus_index])
		await activate(puzzle.check_button)
		check("bonus is verified without changing entry code "+str(level),puzzle.state.level_cleared and puzzle.state.revealed_code()==entry_code and world.orchestrator.entrance_allowed())
	check("bonuses do not farm the reserve reward",int(world.orchestrator.snapshot().reserve_pellets)==1)
	await activate(puzzle.close_button)
	check("close restores movement",not puzzle.visible and not player.controls_locked)
	check("leaving after the first unlock returns the player centred before the open doors",player.global_position.distance_to(world.LOCATIONS[0])<.2 and world.entrance_doors.open)
	world.entering=true;world.set_menu_open(true)
	check("pause menu waits for the entry fade",not world.hud.menu_open)
	world.entering=false
	world.go_location(0)
	await frames(10)
	check("R-style reset preserves session progress",puzzle.state.unlocked and puzzle.state.rewards.size()==4)
	player.teleport_to(Vector3(0,0,5.7))
	await frames(10)
	player.set_controls_active(true)
	Input.action_press("walk_forward");await frames(45);Input.action_release("walk_forward")
	check("player walks through earned unlocked door",player.global_position.z<4.3)
	KeypadPilot.approach(world);await frames(6)
	check("keypad offers a replay once the entrance is open",world.replay_target()=="entrance" and world.hud.prompt_label.text.contains("F: Play the entrance puzzle again"))
	var pellets: int=int(world.orchestrator.snapshot().reserve_pellets)
	await key(KEY_F)
	check("F opens a fresh practice puzzle",puzzle.visible and puzzle.replaying and not puzzle.state.solved and puzzle.earned_state.unlocked)
	Pilot.solve_level(puzzle.state);puzzle._test_circuit();puzzle.code_input.text=puzzle.state.revealed_code();puzzle._unlock()
	check("practice unlock awards nothing and keeps the entrance open",puzzle.state.unlocked and int(world.orchestrator.snapshot().reserve_pellets)==pellets and world.orchestrator.entrance_allowed() and not puzzle.entry_pending)
	var practice_spot: Vector3=player.global_position
	await key(KEY_ESCAPE)
	check("leaving practice restores the earned puzzle in place",not puzzle.visible and not puzzle.replaying and puzzle.state.unlocked and puzzle.state.rewards.size()==4 and not player.controls_locked and player.global_position.distance_to(practice_spot)<.05)
	var fresh: RefCounted=load("res://game/EntrancePuzzleState.gd").new()
	check("fresh session resets boards rewards and code",not fresh.solved and not fresh.unlocked and fresh.level==0 and fresh.rewards.is_empty() and fresh.revealed_code().is_empty())
	print("ENTRANCE_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame
	quit(0 if failures==0 else 1)
