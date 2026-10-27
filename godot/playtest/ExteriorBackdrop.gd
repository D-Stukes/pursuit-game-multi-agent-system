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
const LEFT_ROAD_X: float = -56.0
const RIGHT_ROAD_X: float = 68.0
const FRONT_ROAD_Z: float = 15.5
const ROAD_WIDTH: float = 14.0
const FRONT_EXTENSION: float = 0.0
const TAPE_SHADER_SOURCE: String = "shader_type spatial; render_mode cull_disabled, specular_disabled; uniform vec4 tape_color : source_color; uniform float repeats; void fragment() { float stripe = step(0.5, fract(UV.x * repeats + UV.y * 0.6)); ALBEDO = mix(tape_color.rgb, vec3(0.06), stripe); ROUGHNESS = 1.0; }"
const FLAT_SURFACES: Array[String] = ["DistantGround", "FrontRoad", "SideRoad", "FrontRoadMarking", "SideRoadMarking"]

var materials: Dictionary = {}
var box_meshes: Dictionary = {}
var sphere_meshes: Dictionary = {}
var tape_shader: Shader = Shader.new()

func _ready() -> void:
	name = "ExteriorBackdrop"
	# Keep the approved H and all its props together outside the enlarged wing.
	position.z = FRONT_EXTENSION
	tape_shader.code = TAPE_SHADER_SOURCE
	# Extend farther than the camera's far plane so no terrain edge is exposed.
	_box(self, "DistantGround", Vector3(400, 0.1, 400), Vector3(0, -0.42, 0), ASPHALT)
	# Approved H: the crossbar terminates at two T junctions. No outward arms.
	_box(self, "FrontRoad", Vector3(RIGHT_ROAD_X - LEFT_ROAD_X, 0.035, ROAD_WIDTH), Vector3(6, -0.205, FRONT_ROAD_Z), ASPHALT)
	for x: float in [LEFT_ROAD_X, RIGHT_ROAD_X]:
		_box(self, "SideRoad", Vector3(ROAD_WIDTH, 0.035, 200), Vector3(x, -0.205, FRONT_ROAD_Z), ASPHALT)
	_box(self, "OppositeSidewalk", Vector3(110, 0.24, 4), Vector3(6, -0.12, 24.5), PAVING)
	for x: float in [-65.5, 77.5]:
		_box(self, "OuterSidewalk", Vector3(5, 0.24, 200), Vector3(x, -0.12, FRONT_ROAD_Z), PAVING)
	# Earlier storefront forms, closer across the street; continuous central row.
	_build_neighbor(Vector3(-3, 0, 32), Vector3(27, 8.5, 11), BRICK, 8, 2, 0, "OppositeBrick")
	_build_neighbor(Vector3(-31, 0, 32), Vector3(30, 10, 11), CREAM, 8, 3, 0, "OppositeCream")
	_build_neighbor(Vector3(25, 0, 32), Vector3(30, 12, 11), SAGE, 8, 3, 0, "OppositeSage")
	_build_neighbor(Vector3(48.8, 0, 32), Vector3(17.8, 10, 11), BRICK, 5, 3, 0, "OppositeEnd")
	# Immediate neighbors touch Pursuit. The side roads sit beyond these blocks.
	_build_neighbor(Vector3(-34.875, 0, -13.25), Vector3(21.75, 15, 36), BRICK, 10, 4, PI, "NearLeftNeighbor")
	_build_neighbor(Vector3(40.5, 0, -13.25), Vector3(41.0, 14, 36), SAGE, 10, 4, PI, "NearRightNeighbor")
	# Rear-facing landing window looks across a small court to an occupied facade.
	_build_neighbor(Vector3(2, 0, -30), Vector3(26, 14, 10), CREAM, 7, 3, PI, "RearCourtyardNeighbor")
	# Joined outer rows fill both road-end views, including the crossbar's height.
	for index in range(6):
		var z: float = -74.0 + index * 36.0
		var height: float = 13.0 + (index % 3) * 2.0
		_build_neighbor(Vector3(-77, 0, z), Vector3(36, height, 18), CREAM if index % 2 == 0 else BRICK, 10, 4, -PI / 2.0, "OuterLeft" + str(index))
		_build_neighbor(Vector3(89, 0, z), Vector3(36, height + 1, 18), SAGE if index % 2 == 0 else BRICK, 10, 4, PI / 2.0, "OuterRight" + str(index))
	_build_boundaries()
	# A restrained city planting rhythm; all detail stays outside playable bounds.
	for x: float in [-65.5, 77.5]:
		for z: float in [-20.0, 15.5, 50.0]:
			_planter_tree(Vector3(x, 0, z))
	for x: float in [-25.0, 2.0, 30.0]:
		_planter_tree(Vector3(x, 0, 24.5))
	for x: float in [-8.5, 17.0]:
		_garden(Vector3(x, 0, 25.1))
	for x: float in [-13.0, 11.5]:
		_bench(Vector3(x, 0, 25.4))
	for x: float in [-11.0, -6.0, 14.5, 19.5]:
		_bollard(Vector3(x, 0, 23.1))
	for x: float in [-18.0, 18.0]:
		_box(self, "StreetLamp", Vector3(0.12, 4.6, 0.12), Vector3(x, 2.3, 23.1), NAVY)
		_box(self, "LampCap", Vector3(0.65, 0.18, 0.65), Vector3(x, 4.65, 23.1), CREAM)
	for x in range(-46, 62, 8):
		_box(self, "FrontRoadMarking", Vector3(2.2, 0.01, 0.09), Vector3(x, -0.18, FRONT_ROAD_Z), CREAM)
	for x: float in [LEFT_ROAD_X, RIGHT_ROAD_X]:
		for z in range(-75, 112, 8):
			if z < 7 or z > 24:
				_box(self, "SideRoadMarking", Vector3(0.09, 0.01, 3), Vector3(x, -0.18, z), CREAM)
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

func _box_mesh(size: Vector3) -> BoxMesh:
	if not box_meshes.has(size):
		var shape := BoxMesh.new()
		shape.size = size
		box_meshes[size] = shape
	return box_meshes[size]

func _sphere_mesh(radius: float, height: float, segments: int = 10, rings: int = 5) -> SphereMesh:
	var key := Vector4(radius, height, segments, rings)
	if not sphere_meshes.has(key):
		var shape := SphereMesh.new()
		shape.radius = radius
		shape.height = height
		shape.radial_segments = segments
		shape.rings = rings
		sphere_meshes[key] = shape
	return sphere_meshes[key]

func _box(parent: Node3D, label: String, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = _box_mesh(size)
	mesh.material_override = _material(color)
	if label in FLAT_SURFACES:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var tape_material := ShaderMaterial.new()
	tape_material.shader = tape_shader
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

func _build_neighbor(center: Vector3, size: Vector3, color: Color, columns: int, rows: int, heading: float = 0.0, label: String = "") -> void:
	var facade := Node3D.new()
	facade.name = label if not label.is_empty() else "Neighbor" + str(get_child_count())
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
	batch.mesh = _box_mesh(size)
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = _material(color)
	parent.add_child(instance)

func _planter_tree(center: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "StreetTree" + str(get_child_count())
	tree.position = center
	add_child(tree)
	_box(tree, "TreePlanter", Vector3(1.7, 0.55, 1.7), Vector3(0, 0.275, 0), CREAM)
	_box(tree, "TreeTrunk", Vector3(0.2, 2.9, 0.2), Vector3(0, 1.6, 0), BRICK)
	var crown := MeshInstance3D.new()
	crown.mesh = _sphere_mesh(1.3, 2.6)
	crown.material_override = _material(LEAVES)
	crown.position = Vector3(0, 3.4, 0)
	tree.add_child(crown)

func _garden(center: Vector3) -> void:
	var garden := Node3D.new()
	garden.name = "PocketGarden" + str(get_child_count())
	garden.position = center
	add_child(garden)
	_box(garden, "RaisedBed", Vector3(3.2, 0.35, 1.15), Vector3(0, 0.175, 0), CREAM)
	_box(garden, "Soil", Vector3(3, 0.06, 0.95), Vector3(0, 0.34, 0), BRICK)
	for x: float in [-1.0, 0.0, 1.0]:
		var shrub := MeshInstance3D.new()
		shrub.mesh = _sphere_mesh(0.43, 0.65)
		shrub.material_override = _material(LEAVES)
		shrub.position = Vector3(x, 0.65, 0)
		garden.add_child(shrub)

func _bench(center: Vector3) -> void:
	var bench := Node3D.new()
	bench.name = "StreetBench" + str(get_child_count())
	bench.position = center
	add_child(bench)
	_box(bench, "Seat", Vector3(1.8, 0.12, 0.5), Vector3(0, 0.48, 0), CREAM)
	_box(bench, "Back", Vector3(1.8, 0.5, 0.10), Vector3(0, 0.78, 0.23), SAGE)
	for x: float in [-0.65, 0.65]:
		_box(bench, "Support", Vector3(0.10, 0.42, 0.4), Vector3(x, 0.21, 0), NAVY)

func _bollard(center: Vector3) -> void:
	var bollard := Node3D.new()
	bollard.name = "StreetMarker" + str(get_child_count())
	bollard.position = center
	add_child(bollard)
	_box(bollard, "Post", Vector3(0.16, 0.8, 0.16), Vector3(0, 0.4, 0), NAVY)
	_box(bollard, "Reflector", Vector3(0.18, 0.10, 0.18), Vector3(0, 0.64, 0), CREAM)

func _cloud(center: Vector3, size: Vector3) -> void:
	var group := Node3D.new()
	group.name = "Cloud" + str(get_child_count())
	group.position = center
	add_child(group)
	for i in range(3):
		var puff := MeshInstance3D.new()
		puff.mesh = _sphere_mesh(1.0, 2.0, 16, 8)
		puff.material_override = _material(CLOUD, true)
		puff.scale = size * Vector3(0.44, 0.7 + 0.25 * (i % 2), 0.45)
		puff.position = Vector3((i - 1) * size.x * 0.3, 0.3 * (i % 2), 0)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(puff)
