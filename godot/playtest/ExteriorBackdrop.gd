extends Node3D
## Decorative street context outside the playable sidewalk; no imported assets.

const BRICK := Color(0.53, 0.32, 0.25)
const CREAM := Color(0.83, 0.79, 0.68)
const SAGE := Color(0.46, 0.55, 0.48)
const NAVY := Color(0.12, 0.17, 0.23)
const GLASS := Color(0.39, 0.54, 0.59)
const PAVING := Color(0.64, 0.64, 0.59)
const ASPHALT := Color(0.26, 0.29, 0.31)
const LEAVES := Color(0.35, 0.48, 0.29)
const CLOUD := Color(0.97, 0.95, 0.88)
const TAPE_YELLOW := Color(1.0, 0.79, 0.17)

var materials: Dictionary = {}

func _ready() -> void:
	name = "ExteriorBackdrop"
	# Extend farther than the camera's far plane so no terrain edge is exposed.
	_box(self, "DistantGround", Vector3(400, 0.1, 400), Vector3(0, -0.42, 0), ASPHALT)
	_box(self, "OppositeSidewalk", Vector3(106, 0.24, 8), Vector3(0, -0.12, 21), PAVING)
	_build_neighbor(Vector3(-3, 0, 30), Vector3(27, 8.5, 11), BRICK, 8, 2)
	# Overlap neighboring shells slightly and align their street faces: no alleys.
	_build_neighbor(Vector3(-31, 0, 30), Vector3(30, 10, 11), CREAM, 8, 3)
	_build_neighbor(Vector3(25, 0, 30), Vector3(30, 12, 11), SAGE, 8, 3)
	_build_neighbor(Vector3(-60, 0, 30), Vector3(29, 13, 11), SAGE, 8, 3)
	_build_neighbor(Vector3(54, 0, 30), Vector3(29, 10, 11), BRICK, 8, 3)
	# Near-side neighbors join the accepted facade at x=-10.3 and x=23.4.
	_build_neighbor(Vector3(-28, 0, -13.25), Vector3(35.5, 15, 36), BRICK, 10, 4, PI)
	_build_neighbor(Vector3(40.5, 0, -13.25), Vector3(34.4, 14, 36), SAGE, 10, 4, PI)
	# Return blocks close the long street views at both ends.
	_build_neighbor(Vector3(-60, 0, 11), Vector3(30, 13, 20), CREAM, 8, 3, -PI / 2.0)
	_build_neighbor(Vector3(60, 0, 11), Vector3(30, 13, 20), BRICK, 8, 3, PI / 2.0)
	_build_boundaries()
	for x: float in [-9.0, 10.0]:
		_planter_tree(Vector3(x, 0, 19.5))
	for x: float in [-18.0, 18.0]:
		_box(self, "StreetLamp", Vector3(0.12, 4.6, 0.12), Vector3(x, 2.3, 17.8), NAVY)
		_box(self, "LampCap", Vector3(0.65, 0.18, 0.65), Vector3(x, 4.65, 17.8), CREAM)
	for x: float in [-10.0, -4.0, 2.0, 8.0]:
		_box(self, "RoadMarking", Vector3(2.2, 0.01, 0.09), Vector3(x, -0.20, 13), CREAM)
	_cloud(Vector3(-24, 23, 58), Vector3(12, 2.1, 5))
	_cloud(Vector3(24, 25, 72), Vector3(15, 2.4, 6))
	_cloud(Vector3(61, 31, 26), Vector3(14, 2.0, 7))
	_cloud(Vector3(-65, 29, -16), Vector3(13, 2.4, 6))
	_cloud(Vector3(10, 34, -65), Vector3(17, 2.3, 6))

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(unshaded)
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.95
		if unshaded:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[key] = material
	return materials[key]

func _box(parent: Node3D, label: String, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _material(color)
	mesh.position = center
	parent.add_child(mesh)
	return mesh

func _collider(parent: Node3D, label: String, size: Vector3, center: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	body.collision_layer = layer
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body

func _build_boundaries() -> void:
	# Low pedestrian barriers keep the route clear without tall blank walls.
	_tape_boundary("LeftTape", Vector3(-11.3, 0, 4.85), Vector3(-11.3, 0, 8.45))
	_tape_boundary("LeftReturnTape", Vector3(-11.3, 0, 4.85), Vector3(-10.0, 0, 4.85))
	_tape_boundary("RightTape", Vector3(11.3, 0, 4.85), Vector3(11.3, 0, 8.45))
	_tape_boundary("StreetTape", Vector3(-11.3, 0, 8.45), Vector3(11.3, 0, 8.45))

func _tape_boundary(label: String, start: Vector3, end: Vector3) -> void:
	var group := Node3D.new()
	group.name = label
	add_child(group)
	var direction: Vector3 = end - start
	var length: float = direction.length()
	var heading: float = atan2(-direction.z, direction.x)
	var midpoint: Vector3 = (start + end) / 2.0
	# Layer 4 blocks the player; the camera can orbit across the low tape.
	var barrier := _collider(group, "PedestrianBoundary", Vector3(length + 0.12, 1.12, 0.30), midpoint + Vector3.UP * 0.56, 4)
	barrier.rotation.y = heading
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled, specular_disabled; uniform vec4 tape_color : source_color; uniform float repeats; void fragment() { float stripe = step(0.5, fract(UV.x * repeats + UV.y * 0.6)); ALBEDO = mix(tape_color.rgb, vec3(0.06), stripe); ROUGHNESS = 1.0; }"
	var tape_material := ShaderMaterial.new()
	tape_material.shader = shader
	tape_material.set_shader_parameter("tape_color", TAPE_YELLOW)
	tape_material.set_shader_parameter("repeats", length * 4.0)
	for height: float in [0.64, 1.0]:
		var tape := _box(group, "CautionTape", Vector3(length, 0.12, 0.025), midpoint + Vector3.UP * height, TAPE_YELLOW)
		tape.rotation.y = heading
		tape.material_override = tape_material
	var sections: int = maxi(1, ceili(length / 2.0))
	for i in range(sections + 1):
		var position: Vector3 = start.lerp(end, float(i) / sections)
		_box(group, "PostBase", Vector3(0.3, 0.07, 0.3), position + Vector3.UP * 0.035, NAVY)
		_box(group, "Post", Vector3(0.08, 1.12, 0.08), position + Vector3.UP * 0.56, NAVY)
		_box(group, "PostCap", Vector3(0.12, 0.07, 0.12), position + Vector3.UP * 1.12, TAPE_YELLOW)

func _build_neighbor(center: Vector3, size: Vector3, color: Color, columns: int, rows: int, heading: float = 0.0) -> void:
	var facade := Node3D.new()
	facade.name = "Neighbor" + str(get_child_count())
	facade.position = center
	facade.rotation.y = heading
	add_child(facade)
	_box(facade, "Shell", size, Vector3(0, size.y / 2.0, 0), color)
	_collider(facade, "FacadeCollision", size, Vector3(0, size.y / 2.0, 0), 1)
	var front: float = -size.z / 2.0 - 0.02
	_box(facade, "Cornice", Vector3(size.x + 0.45, 0.3, size.z + 0.3), Vector3(0, size.y - 0.2, 0), CREAM)
	_box(facade, "StorefrontBand", Vector3(size.x, 0.25, 0.18), Vector3(0, 2.9, front), CREAM)
	# One instanced draw for all window frames and one for their colored panes.
	var transforms: Array[Transform3D] = []
	for row in range(rows):
		for column in range(columns):
			var x: float = (column + 0.5) * size.x / columns - size.x / 2.0
			var y: float = 4.1 + row * (size.y - 5.6) / maxf(rows - 1, 1)
			transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, y, front)))
	_windows(facade, "WindowFrames", transforms, Vector3(1.8, 1.75, 0.09), NAVY)
	var panes: Array[Transform3D] = []
	for transform: Transform3D in transforms:
		transform.origin.z -= 0.06
		panes.append(transform)
	_windows(facade, "WindowPanes", panes, Vector3(1.56, 1.5, 0.06), GLASS)
	for shop in range(3):
		var x: float = (shop - 1) * size.x / 3.0
		_box(facade, "Storefront", Vector3(size.x / 3.0 - 0.65, 2.0, 0.12), Vector3(x, 1.35, front - 0.06), NAVY)
		_box(facade, "Awning", Vector3(size.x / 3.0 - 0.4, 0.16, 1.0), Vector3(x, 2.7, front - 0.4), SAGE if shop != 1 else CREAM)
		_box(facade, "ShopGlass", Vector3(size.x / 3.0 - 1.0, 1.65, 0.06), Vector3(x, 1.35, front - 0.14), GLASS)
	_box(facade, "RoofUtility", Vector3(2.5, 0.65, 2), Vector3(size.x / 4.0, size.y + 0.3, 1.2), NAVY)

func _windows(parent: Node3D, label: String, transforms: Array[Transform3D], size: Vector3, color: Color) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	parent.add_child(instance)

func _planter_tree(center: Vector3) -> void:
	_box(self, "TreePlanter", Vector3(1.7, 0.55, 1.7), center + Vector3(0, 0.275, 0), CREAM)
	_box(self, "TreeTrunk", Vector3(0.2, 2.9, 0.2), center + Vector3(0, 1.6, 0), BRICK)
	var crown := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.3
	mesh.height = 2.6
	mesh.radial_segments = 10
	mesh.rings = 5
	crown.mesh = mesh
	crown.material_override = _material(LEAVES)
	crown.position = center + Vector3(0, 3.4, 0)
	add_child(crown)

func _cloud(center: Vector3, size: Vector3) -> void:
	var group := Node3D.new()
	group.name = "Cloud" + str(get_child_count())
	group.position = center
	add_child(group)
	for i in range(3):
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		puff.mesh = mesh
		puff.material_override = _material(CLOUD, true)
		puff.scale = size * Vector3(0.44, 0.7 + 0.25 * (i % 2), 0.45)
		puff.position = Vector3((i - 1) * size.x * 0.3, 0.3 * (i % 2), 0)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(puff)
