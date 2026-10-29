extends SceneTree
## Targeted form retries. Earlier gate solutions are explicitly controller fixtures.
const Pipes=preload("res://developer/tests/PipeTestPilot.gd")
const Gates=preload("res://developer/tests/verify_check_in.gd")
var world: Node3D
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func frames(count: int=5) -> void:
	for _i: int in range(count): await physics_frame
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func key(code: Key, unicode_value: int=0) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.unicode=unicode_value;event.pressed=true
	Input.parse_input_event(event);await process_frame;await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame;await frames(2)
func type_text(value: String) -> void:
	for character: String in value: await key(character.to_upper().unicode_at(0),character.unicode_at(0))
func run() -> void:
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	Pipes.solve_all(world.entrance_puzzle.state)
	preload("res://developer/tests/KeypadTestPilot.gd").approach(world);await frames()
	await key(KEY_E);await frames()
	var puzzle: Control=world.entrance_puzzle
	check("fixture solved circuits still need code input",puzzle.visible and not world.orchestrator.entrance_allowed())
	puzzle.code_input.grab_focus();await process_frame
	await type_text("000");await key(KEY_ENTER)
	check("wrong code keeps field actively editable",not world.orchestrator.entrance_allowed() and puzzle.code_input.has_focus() and puzzle.code_input.is_editing())
	# Type directly over the error's selection: no refocus/edit call or UI reopening.
	await type_text(puzzle.state.revealed_code());await key(KEY_ENTER)
	check("correcting code directly unlocks entrance",world.orchestrator.entrance_allowed() and world.orchestrator.snapshot().stage=="elevator" and world.entrance_gate.collision_layer==0)
	world.queue_free();await process_frame
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	Gates.solve_gates(world)
	world.player.teleport_to(Vector3(3.1,5.05,-5.22));await frames()
	var toward: Vector3=world.check_in.computer.point-world.player.global_position
	world.player.camera_pivot.rotation.y=atan2(-toward.x,-toward.z)
	await key(KEY_E)
	check("reception name form opens",world.check_in.is_open)
	await key(KEY_ENTER)
	check("invalid name remains editable without refocus",not world.orchestrator.checked_in() and world.check_in.name_input.has_focus() and world.check_in.name_input.is_editing() and not world.check_in.notice.text.is_empty())
	await type_text("Robin");await key(KEY_ENTER);await create_timer(.6).timeout
	check("corrected name reaches photo without reopening",world.check_in.state.phase==world.check_in.Rules.Phase.PHOTO and world.check_in.state.display_name=="Robin")
	await key(KEY_ENTER)
	check("corrected name can finish verified check-in",world.orchestrator.checked_in() and world.orchestrator.snapshot().arrival.display_name=="Robin")
	print("TEXT_RETRIES_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
