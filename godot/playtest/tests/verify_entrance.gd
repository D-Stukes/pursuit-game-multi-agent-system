extends SceneTree
## Pipe UI, real keyboard input, code gate, interruption and physical doorway.
const Pilot = preload("res://playtest/tests/PipeTestPilot.gd")
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

func run() -> void:
	world=load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var puzzle: Control=world.entrance_puzzle
	var player: CharacterBody3D=world.player
	check("world starts with locked door and four-level puzzle",world.ready_for_test and world.entrance_gate.collision_layer==4 and puzzle.tiles.size()==9 and not puzzle.state.solved)
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
	check("E opens circuit panel and locks world controls",puzzle.visible and player.controls_locked)
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
	for level: int in range(4):
		await layout_checks(puzzle,"level "+str(level+1))
		var rotations: Dictionary=Pilot.route(puzzle.state)
		check("independent visible-shape pilot finds path "+str(level+1),not rotations.is_empty())
		for tile_index: int in rotations:
			for _i: int in range(rotations[tile_index]): await activate(puzzle.tiles[tile_index])
		check("connected preview alone grants no reward "+str(level+1),puzzle.state.connected() and puzzle.state.rewards.size()==level)
		await activate(puzzle.check_button)
		check("verified circuit reveals expected word order "+str(level+1),puzzle.reward_label.text==puzzle.state.REWARDS[level] and puzzle.state.rewards.size()==level+1)
		check("verified circuit freezes tile edits "+str(level+1),puzzle.tiles[0].disabled)
		await layout_checks(puzzle,"reward "+str(level+1))
		await key(KEY_ESCAPE);await key(KEY_E)
		check("reopening preserves earned reward "+str(level+1),puzzle.state.rewards.size()==level+1 and puzzle.state.level_cleared)
		if level<3:
			check("partial completion cannot reveal or accept code "+str(level+1),not puzzle.state.solved and puzzle.state.revealed_code().is_empty() and not puzzle.state.enter_code("123"))
			await activate(puzzle.next_button)
	check("fourth reward is exact final sentence",puzzle.reward_label.text=="Welcome to Pursuit" and puzzle.state.solved and puzzle.code_box.visible)
	check("verified code reveal still requires keypad entry",puzzle.code_label.text.contains(puzzle.state.revealed_code()) and not puzzle.state.unlocked and world.entrance_gate.collision_layer==4)
	puzzle.code_input.text="000"
	await activate(puzzle.unlock_button)
	check("wrong code is rejected with visible feedback",not puzzle.state.unlocked and puzzle.code_feedback.is_visible_in_tree() and puzzle.code_feedback.text.contains("does not match"))
	puzzle.code_input.text=puzzle.state.revealed_code()
	puzzle.code_input.grab_focus()
	await key(KEY_ENTER)
	check("correct code removes physical lock",puzzle.state.unlocked and world.entrance_gate.collision_layer==0 and not world.entrance_gate.visible)
	check("duplicate unlock is disabled",puzzle.unlock_button.disabled and not puzzle.code_input.editable)
	await activate(puzzle.close_button)
	check("close restores movement",not puzzle.visible and not player.controls_locked)
	world.go_location(0)
	await frames(10)
	check("R-style reset preserves session progress",puzzle.state.unlocked and puzzle.state.rewards.size()==4)
	player.teleport_to(Vector3(0,0,5.7))
	await frames(10)
	player.set_controls_active(true)
	Input.action_press("walk_forward");await frames(45);Input.action_release("walk_forward")
	check("player walks through earned unlocked door",player.global_position.z<4.3)
	var fresh: RefCounted=load("res://playtest/EntrancePuzzleState.gd").new()
	check("fresh session resets boards rewards and code",not fresh.solved and not fresh.unlocked and fresh.level==0 and fresh.rewards.is_empty() and fresh.revealed_code().is_empty())
	print("ENTRANCE_RESULT checks=",checks," failures=",failures)
	world.queue_free();await process_frame
	quit(0 if failures==0 else 1)
