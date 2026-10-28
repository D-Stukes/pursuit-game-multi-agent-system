extends StaticBody3D
## A reusable visual actor, not a gameplay agent or pathfinding character.
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var record: Dictionary
var animation_active: bool = false
var bind_bounds: AABB

func configure(packed: PackedScene, placement: Dictionary, index: int) -> void:
	record = placement
	name = record.id
	collision_layer = 8
	collision_mask = 0
	position = Vector3(record.position[0], record.position[1], record.position[2])
	rotation.y = deg_to_rad(float(record.yaw))
	model = packed.instantiate()
	model.name = "Model"
	add_child(model)
	var found: bool = false
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		# The source suit includes an optional weapon. Ambient office people do not.
		if mesh.name == &"Pistol":
			mesh.hide()
			continue
		var box: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bind_bounds = bind_bounds.merge(box) if found else box
		found = true
		mesh.visibility_range_end = 32.0
		mesh.visibility_range_end_margin = 3.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	assert(found and bind_bounds.size.y > .1, "NPC model has no usable geometry")
	var factor: float = float(record.height) / bind_bounds.size.y
	model.scale = Vector3.ONE * factor
	model.position.y = -bind_bounds.position.y * factor
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animation = model.find_children("*", "AnimationPlayer", true, false)[0]
	animation.get_animation("Idle_Neutral").loop_mode = Animation.LOOP_LINEAR
	animation.play("Idle_Neutral")
	animation.seek(fmod(index * .173, animation.current_animation_length), true)
	set_animation_active(false)
	var capsule := CapsuleShape3D.new()
	capsule.radius = .18
	capsule.height = float(record.height)
	var shape := CollisionShape3D.new()
	shape.name = "PersonalSpace"
	shape.shape = capsule
	shape.position.y = capsule.height * .5
	add_child(shape)

func set_animation_active(active: bool) -> void:
	animation_active = active
	# Stop Skeleton3D/AnimationPlayer processing when distant or outside the view.
	# The last valid idle pose is retained; static collision stays active.
	model.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
