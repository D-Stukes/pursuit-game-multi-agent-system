extends Node3D
## Face-up dismantled display: keep all seven skins on the original 17-bone rig.
const PART_BONES := {"head":"head", "left_arm":"upper_arm_L", "right_arm":"upper_arm_R", "left_leg":"thigh_L", "right_leg":"thigh_R", "power_core":"power_core"}
const OFFSETS := {"head":Vector3(0,0,-.18), "left_arm":Vector3(.12,0,0), "right_arm":Vector3(-.12,0,0), "left_leg":Vector3(.04,0,.30), "right_leg":Vector3(-.04,0,.30), "power_core":Vector3(.64,0,-.70)}
@export var surface_height: float = .80
var skeleton: Skeleton3D
var parts: Dictionary = {}
var rest_bounds: Dictionary = {}
var part_offsets: Dictionary = {}
var animation: AnimationPlayer
var assembled: bool = false

func _ready() -> void:
	var model: Node3D = $Model
	animation = model.find_children("*", "AnimationPlayer", true, false)[0]
	animation.stop()
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.reset_bone_poses()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var id: String = mesh.get_meta("extras", {}).get("part_id", "")
		assert(not id.is_empty(), "Robot mesh lacks a part ID")
		parts[id] = mesh
		mesh.visibility_range_end = 35.0
		mesh.visibility_range_end_margin = 3.0
	# With every joint at rest, bind bounds are valid. Every part below receives
	# a pure translation at its root bone; its children and weights stay intact.
	var torso_box: AABB = global_transform.affine_inverse() * parts.torso.global_transform * parts.torso.get_aabb()
	model.position.y += surface_height - torso_box.position.y + .005
	for id: String in parts:
		var mesh: MeshInstance3D = parts[id]
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		rest_bounds[id] = box
		var offset: Vector3 = OFFSETS.get(id, Vector3.ZERO)
		offset.y = surface_height - box.position.y + .005
		part_offsets[id] = offset
		if PART_BONES.has(id):
			var bone: int = skeleton.find_bone(PART_BONES[id])
			var parent: int = skeleton.get_bone_parent(bone)
			var parent_basis: Basis = skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
			var to_actor: Basis = global_basis.inverse() * skeleton.global_basis * parent_basis
			# Godot's pose position includes the rest translation. Apply the
			# displacement in parent space without replacing that translation.
			skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + to_actor.inverse() * offset)
	skeleton.force_update_all_bone_transforms()
	# This is an intentionally still pose, not a disconnected-parts animation.
	animation.process_mode = Node.PROCESS_MODE_DISABLED

func part_bounds(id: String) -> AABB:
	var box: AABB = rest_bounds[id]
	box.position += part_offsets[id]
	return box

## The robot challenge payoff: the hand-posed "dismantled" display comes alive
## and runs the authored Assemble -> PowerOn -> Idle animation, so the parts draw
## back together on the bench and the robot powers on. Safe to call once.
func assemble_and_power() -> void:
	if assembled or animation == null:
		return
	assembled = true
	var model: Node3D = $Model
	animation.process_mode = Node.PROCESS_MODE_INHERIT
	# 1. Draw the scattered parts back together on the bench (authored animation).
	if animation.has_animation("Assemble"):
		animation.play("Assemble")
		await animation.animation_finished
	# 2. Stand the finished robot upright, feet on the floor, turned to face the
	#    AI Builder (who stands on the +X side of the bench). Its rest-forward is
	#    +Z, so a +90 deg yaw points it at them.
	var stand_pos: Vector3 = _standing_position(model)
	var face := Vector3(0.0, PI / 2.0, 0.0)
	var rise := create_tween().set_parallel(true)
	rise.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_property(model, "rotation", face, 0.7)
	rise.tween_property(model, "position", stand_pos, 0.7)
	await rise.finished
	# 3. Power on (its lights come up) and settle into a standing idle.
	if animation.has_animation("PowerOn"):
		animation.play("PowerOn")
		await animation.animation_finished
	if animation.has_animation("Idle"):
		animation.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		animation.play("Idle")

## Where the model must sit so that, standing upright (rotation zero), the robot's
## feet rest at this node's origin — the classroom floor in front of the bench.
func _standing_position(model: Node3D) -> Vector3:
	var prev_rot: Vector3 = model.rotation
	model.rotation = Vector3.ZERO
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	var min_y: float = INF
	for id: String in parts:
		var mesh: MeshInstance3D = parts[id]
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		min_y = minf(min_y, box.position.y)
	model.rotation = prev_rot
	if min_y == INF:
		min_y = 0.0
	return Vector3(0.0, model.position.y - min_y, 0.0)
