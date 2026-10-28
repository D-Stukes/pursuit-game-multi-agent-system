extends Node3D
## Face-up dismantled display: keep all seven skins on the original 17-bone rig.
const PART_BONES := {"head":"head", "left_arm":"upper_arm_L", "right_arm":"upper_arm_R", "left_leg":"thigh_L", "right_leg":"thigh_R", "power_core":"power_core"}
const OFFSETS := {"head":Vector3(0,0,-.18), "left_arm":Vector3(.12,0,0), "right_arm":Vector3(-.12,0,0), "left_leg":Vector3(.04,0,.30), "right_leg":Vector3(-.04,0,.30), "power_core":Vector3(.64,0,-.70)}
@export var surface_height: float = .80
var skeleton: Skeleton3D
var parts: Dictionary = {}
var rest_bounds: Dictionary = {}
var part_offsets: Dictionary = {}

func _ready() -> void:
	var model: Node3D = $Model
	var animation: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
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
