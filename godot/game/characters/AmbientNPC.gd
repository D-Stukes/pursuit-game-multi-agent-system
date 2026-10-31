extends CharacterBody3D
## Reused skinned actor with collision-aware, local authored movement.
const Routine = preload("res://game/characters/NPCRoutineState.gd")
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var record: Dictionary
var animation_active: bool = false
var bind_bounds: AABB
var routine: RefCounted
var locomoting: bool = false
var blocked: bool = false
var distance_walked: float = 0
var current_clip: String = "Idle_Neutral"
const STEP_HEIGHT: float = .4
var props: Dictionary = {}
var prop: String = ""
const PROP_COLORS: Dictionary = {"cup":Color(.93,.92,.88),"phone":Color(.08,.09,.11)}

func configure(packed: PackedScene, placement: Dictionary, index: int) -> void:
	record = placement.duplicate(true)
	name = record.id
	collision_layer = 8
	collision_mask = 1|2|4|8
	safe_margin = .005
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
	var library: AnimationLibrary = animation.get_animation_library("").duplicate()
	animation.remove_animation_library("");animation.add_animation_library("",library)
	for clip: String in ["Idle_Neutral","Walk","Run"]:
		# Clip resources are shared; duplicate only the loop-setting metadata.
		var loop: Animation = animation.get_animation(clip).duplicate()
		loop.loop_mode = Animation.LOOP_LINEAR
		animation.get_animation_library("").remove_animation(clip)
		animation.get_animation_library("").add_animation(clip,loop)
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
	_build_props()
	animation.animation_finished.connect(func(clip: StringName):
		if routine!=null and routine.talking and clip==&"Wave": play_clip("Idle_Neutral"))

## Small hand props for everyday actions. Sized in metres regardless of the model's scale.
func _build_props() -> void:
	var hand := BoneAttachment3D.new()
	hand.name = "RightHandProps"
	hand.bone_name = "Wrist.R"
	skeleton.add_child(hand)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE/model.scale.x
	holder.position = Vector3(0,.09,.03)/model.scale.x
	hand.add_child(holder)
	for id: String in PROP_COLORS:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = id.capitalize()
		if id == "cup":
			var cup := CylinderMesh.new();cup.top_radius = .042;cup.bottom_radius = .036;cup.height = .1
			mesh_instance.mesh = cup
		else:
			var phone := BoxMesh.new();phone.size = Vector3(.075,.15,.012)
			mesh_instance.mesh = phone
		var material := StandardMaterial3D.new();material.albedo_color = PROP_COLORS[id]
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.visible = false
		holder.add_child(mesh_instance)
		props[id] = mesh_instance

func set_prop(id: String) -> void:
	if id == prop: return
	prop = id
	for key: String in props: props[key].visible = key == id

## Everyday life replaces the authored loop; the body, collision and animation stay the same.
func prepare_life(life: RefCounted) -> void:
	routine = life
	assert(routine.valid,"Invalid everyday life for "+str(name))

func prepare_routine() -> void:
	routine = Routine.new(record.routine,global_position)
	assert(routine.valid,"Invalid authored routine for "+str(name))

func begin_conversation(facing: Vector3) -> void:
	if routine==null: return
	routine.begin_conversation();locomoting=false;velocity=Vector3.ZERO
	var toward: Vector3 = facing-global_position;toward.y=0
	if toward.length()>.01: rotation.y=atan2(toward.x,toward.z)
	play_clip("Wave")

func end_conversation() -> void:
	if routine!=null: routine.end_conversation()
	play_clip("Idle_Neutral")

func play_clip(clip: String, speed_scale: float = 1) -> void:
	if current_clip!=clip or animation.current_animation!=clip:
		animation.play(clip,.15);current_clip=clip
	animation.speed_scale=speed_scale

func supported_floor(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,point-Vector3.UP*.25,1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.normal.y>.9 and absf(hit.position.y-global_position.y)<.15

func update_routine(delta: float, allowed: bool) -> void:
	if routine==null: return
	var decision: Dictionary = routine.decide(global_position,delta,allowed)
	blocked=false
	set_prop(str(decision.get("prop","")))
	if decision.has("hidden"): set_riding(decision.hidden)
	if decision.get("teleport") is Vector3: global_position = decision.teleport
	if decision.speed<=0:
		# Presentation and talking own their gestures while routine time is paused.
		if allowed and not routine.talking:
			play_clip(decision.animation)
			if decision.get("face") is Vector3: turn_toward(decision.face,delta)
		elif locomoting: play_clip("Idle_Neutral")
		locomoting=false;velocity=Vector3.ZERO
		return
	move_to_target(decision.target,decision.speed,delta)
	if routine.has_method("report_blocked"):
		if blocked or not locomoting: routine.report_blocked(delta)
		else: routine.report_moving()

func turn_toward(point: Vector3, delta: float) -> void:
	var toward: Vector3 = point-global_position;toward.y=0
	if toward.length()>.05: rotation.y=lerp_angle(rotation.y,atan2(toward.x,toward.z),minf(1,delta*5))

## Hidden inside the elevator cab: no body, no collision, no animation.
func set_riding(riding: bool) -> void:
	visible = not riding
	collision_layer = 0 if riding else 8
	if riding: velocity = Vector3.ZERO;locomoting = false

## Floor height just ahead, so people follow ramps and stair treads within one step.
func floor_height(point: Vector3) -> float:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.45,point-Vector3.UP*.45,1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() and hit.normal.y>.7 else INF

func move_to_target(target: Vector3, speed: float, delta: float) -> void:
	var toward: Vector3 = target-global_position;toward.y=0
	var motion: Vector3 = toward.normalized()*minf(toward.length(),speed*delta)
	var ground: float = floor_height(global_position+motion)
	if not is_finite(ground) or absf(ground-global_position.y)>STEP_HEIGHT:
		blocked=true;locomoting=false;play_clip("Idle_Neutral");return
	var before: Vector3 = global_position
	# Rise onto a tread before moving forward; descend with the forward motion.
	if ground>global_position.y: move_and_collide(Vector3(0,ground-global_position.y,0))
	else: motion.y = ground-global_position.y
	var collision: KinematicCollision3D = move_and_collide(motion)
	if collision != null and routine != null and routine.has_method("explore"):
		# Everyday walkers slide along walls and keep right when they meet someone.
		var rest: Vector3 = collision.get_remainder().slide(collision.get_normal())
		if collision.get_collider() is CharacterBody3D: rest = motion.cross(Vector3.UP).normalized()*motion.length()
		rest.y = 0
		if rest.length() > .001 and absf(floor_height(global_position+rest)-global_position.y) <= STEP_HEIGHT:
			collision = move_and_collide(rest)
	var travelled: float = global_position.distance_to(before)
	distance_walked+=travelled;blocked=collision!=null
	locomoting=travelled>delta*.05
	if locomoting:
		rotation.y=lerp_angle(rotation.y,atan2(toward.x,toward.z),minf(1,delta*8))
		var running: bool=speed>2.8
		play_clip("Run" if running else "Walk",clampf((travelled/delta)/(4.2 if running else 1.8),.6,1.5))
	else: play_clip("Idle_Neutral")

func set_animation_active(active: bool) -> void:
	animation_active = active
	# Stop Skeleton3D/AnimationPlayer processing when distant or outside the view.
	# Pose is retained; character collision and routine state are independent.
	model.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
