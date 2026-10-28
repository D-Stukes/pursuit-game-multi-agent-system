extends SceneTree
## Verify the real review launcher flag and reversible, progress-free bypass.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 5) -> void:
	for _i in range(count): await physics_frame

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("PASS " if passed else "FAIL ", label)

func run() -> void:
	var world: Node3D = load("res://BuildingPlaytest.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var hud: Control = world.hud
	var player: CharacterBody3D = world.player
	var state: RefCounted = world.entrance_puzzle.state
	check("review launch flag applied", world.building_review_mode)
	check("bypass is explicitly visible", hud.review_status.visible and hud.review_toggle.button_pressed)
	check("review opens physical entrance", world.entrance_gate.collision_layer == 0 and not world.entrance_gate.visible)
	check("bypass grants no puzzle progress", not state.solved and not state.unlocked and state.revealed_code().is_empty())
	player.teleport_to(Vector3(0,0,5.7))
	await frames(10)
	check("review does not open puzzle", not world.try_entrance() and not world.entrance_puzzle.visible)
	player.set_controls_active(true)
	Input.action_press("walk_forward")
	await frames(45)
	Input.action_release("walk_forward")
	check("review permits actual doorway walk", player.global_position.z < 4.3)
	world.go_location(0)
	check("reset keeps review bypass", world.building_review_mode and world.entrance_gate.collision_layer == 0)
	hud.set_debug_mode(true)
	world.set_menu_open(true)
	for resolution: Vector2 in [Vector2(800,600),Vector2(1280,720)]:
		hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hud.size = resolution
		await frames(6)
		check("review menu fits "+str(resolution),Rect2(Vector2.ZERO,resolution).encloses(hud.menu_panel.get_global_rect()))
		check("review toggle fits "+str(resolution),hud.menu_panel.get_global_rect().encloses(hud.review_toggle.get_global_rect()))
		check("review banner fits "+str(resolution),hud.get_global_rect().encloses(hud.review_status.get_global_rect()))
	hud.review_toggle.button_pressed = false
	check("developer toggle restores normal lock",not world.building_review_mode and world.entrance_gate.collision_layer == 4 and world.entrance_gate.visible)
	check("normal lock retains unsolved state",not state.solved and not state.unlocked)
	hud.review_toggle.button_pressed = true
	check("developer toggle enables bypass again",world.building_review_mode and world.entrance_gate.collision_layer == 0)
	world.set_menu_open(false)
	check("review resumes movement",not player.controls_locked and player.controls_active)
	world.set_building_review_mode(false)
	world.go_location(0)
	check("return to game relocks without restart",world.try_entrance() and world.entrance_puzzle.visible)
	world.entrance_puzzle.close()
	state.check_order([0,1,2])
	state.enter_code(state.revealed_code())
	world._refresh_entrance_gate()
	world.set_building_review_mode(true)
	world.set_building_review_mode(false)
	check("earned unlock survives review toggle",state.unlocked and world.entrance_gate.collision_layer == 0)
	print("REVIEW_RESULT checks=",checks," failures=",failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
