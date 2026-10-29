extends Node3D
## A wall-mounted entry prop. Puzzle results remain owned by the Orchestrator.
const UI = preload("res://game/GameHUD.gd")
const USE_RADIUS: float = 1.6
var entrance_point: Vector3
var body: StaticBody3D
var status: Label3D
var prompt: Label3D
var keys: Array[Label3D] = []
var mounted: bool = false

func _ready() -> void:
	position = entrance_point+Vector3(-2.3,1.35,.1)
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color(.16,.18,.21)
	housing.metallic = .65; housing.roughness = .4
	var buttons := StandardMaterial3D.new()
	buttons.albedo_color = Color(.58,.62,.65)
	buttons.metallic = .5; buttons.roughness = .5
	var screen := StandardMaterial3D.new()
	screen.albedo_color = UI.NAVY
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box("MountingPlate",Vector3(.32,.5,.025),Vector3(0,0,.0125),buttons)
	_box("Housing",Vector3(.28,.46,.06),Vector3(0,0,.045),housing)
	_box("Display",Vector3(.22,.07,.009),Vector3(0,.15,.0795),screen)
	status = _text("LOCKED",Vector3(0,.15,.087),28,.00065)
	status.modulate = UI.CYAN
	for index: int in range(12):
		var at := Vector3((index%3-1)*.075,.065-floorf(float(index)/3)*.063,.082)
		_box("Key%02d"%index,Vector3(.055,.044,.016),at,buttons)
		var key_text: String = str(index+1) if index<9 else ["*","0","#"][index-9]
		var label: Label3D = _text(key_text,at+Vector3(0,0,.01),30,.00065)
		label.modulate = UI.NAVY
		keys.append(label)
	body = StaticBody3D.new()
	body.collision_layer = 1; body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(.32,.5,.09)
	collision.shape = shape; collision.position.z = .045
	body.add_child(collision); add_child(body)
	prompt = _text("E\nUse keypad",Vector3(0,.35,.1),28,.0018)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.outline_size = 8
	prompt.hide()
	_mount_on_wall()

func _box(label: String, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new(); box.size = size
	mesh.mesh = box; mesh.material_override = material; mesh.position = at
	add_child(mesh)

func _text(value: String, at: Vector3, font: int, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = value; label.position = at; label.font_size = font; label.pixel_size = pixel
	label.outline_size = 0; label.double_sided = false
	add_child(label)
	return label

func _mount_on_wall() -> void:
	await get_tree().physics_frame
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3(0,0,1),global_position-Vector3(0,0,1),1)
	ray.exclude = [body.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.z<.8: return
	global_position.z = hit.position.z+.004
	mounted = true

func can_use(player: CharacterBody3D) -> bool:
	if not mounted or absf(player.global_position.y-entrance_point.y)>.4 or player.global_position.z<=entrance_point.z: return false
	var toward: Vector3 = global_position-player.global_position
	toward.y = 0
	var facing: Vector3 = -player.camera_pivot.global_basis.z
	facing.y = 0
	if toward.length()>USE_RADIUS or facing.normalized().dot(toward.normalized())<.55: return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.25,global_position+Vector3(0,0,.09),1|4|8)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == body

func update_prompt(player: CharacterBody3D, available: bool, focused: bool) -> void:
	prompt.visible = available and player.global_position.z>entrance_point.z and absf(player.global_position.y-entrance_point.y)<.4 and player.global_position.distance_to(global_position)<5
	prompt.modulate = UI.CYAN if focused else UI.WHITE

func set_open(open: bool) -> void:
	var text: String = "OPEN" if open else "LOCKED"
	if status.text != text: status.text = text
