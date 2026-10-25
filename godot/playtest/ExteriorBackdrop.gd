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

var materials: Dictionary = {}

func _ready() -> void:
	name = "ExteriorBackdrop"
	# Extend farther than the camera's far plane so no terrain edge is exposed.
	_box(self, "DistantGround", Vector3(400, 0.1, 400), Vector3(0, -0.42, 0), ASPHALT)
	_box(self, "OppositeSidewalk", Vector3(106, 0.24, 8), Vector3(0, -0.12, 21), PAVING)
	_build_neighbor(Vector3(-3, 0, 30), Vector3(27, 8.5, 11), BRICK, 8, 2)
	_build_neighbor(Vector3(-29, 0, 37), Vector3(18, 9, 12), CREAM, 5, 2)
	_build_neighbor(Vector3(27, 0, 35), Vector3(24, 14, 13), SAGE, 7, 4)
	_build_neighbor(Vector3(-48, 0, 48), Vector3(17, 16, 13), SAGE, 4, 4)
	_build_neighbor(Vector3(48, 0, 48), Vector3(19, 11, 13), BRICK, 5, 3)
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

func _solid(label: String, size: Vector3, center: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	_box(body, label + "Surface", size, Vector3.ZERO, color)

func _build_boundaries() -> void:
	# Only enclose the street-side strip (z >= 4.8), never the interior rooms.
	_solid("LeftBoundary", Vector3(0.45, 11, 8), Vector3(-12.15, 5.5, 8.8), BRICK)
	# Join the left cap to the narrower original facade, closing the rear corner.
	_solid("LeftBoundaryReturn", Vector3(2.15, 11, 0.45), Vector3(-11.15, 5.5, 4.85), BRICK)
	_solid("RightBoundary", Vector3(0.45, 11, 8), Vector3(12.15, 5.5, 8.8), CREAM)
	for side: float in [-1.0, 1.0]:
		_box(self, "BoundaryCap", Vector3(0.65, 0.18, 8.1), Vector3(side * 12.15, 11.05, 8.8), CREAM)
		_solid("BoundaryPlinth", Vector3(0.70, 0.45, 3.65), Vector3(side * 11.8, 0.225, 6.7), SAGE)
	# A continuous low curb/railing gives a visible physical limit to the sidewalk.
	_solid("StreetBoundary", Vector3(24.0, 0.35, 0.35), Vector3(0, 0.175, 8.45), CREAM)
	_solid("StreetRail", Vector3(24.0, 0.12, 0.12), Vector3(0, 1.0, 8.45), NAVY)
	for x in range(-12, 13, 2):
		_box(self, "RailPost", Vector3(0.07, 0.75, 0.07), Vector3(x, 0.65, 8.45), NAVY)

func _build_neighbor(center: Vector3, size: Vector3, color: Color, columns: int, rows: int) -> void:
	var facade := Node3D.new()
	facade.name = "Neighbor" + str(get_child_count())
	facade.position = center
	add_child(facade)
	_box(facade, "Shell", size, Vector3(0, size.y / 2.0, 0), color)
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
