extends RefCounted
## Read the shared authoring contract. Geometry stays in the imported Blender export.
const MANIFEST_PATH := "res://assets/building-layout.json"
var root: Node3D
var manifest: Dictionary = {}
var retained: Dictionary = {}
var missing: Array[String] = []

func apply(building: Node3D) -> void:
	root = building
	manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	for mesh: MeshInstance3D in building.find_children("*", "MeshInstance3D", true, false):
		var extras: Dictionary = mesh.get_meta("extras", {})
		var kind: String = str(extras.get("retained_source_kind", ""))
		if not kind.is_empty():
			retained[kind] = int(retained.get(kind, 0)) + 1
	for id: String in manifest.anchors:
		var nodes: Array[Node] = building.find_children("ANCHOR_" + id, "Node3D", true, false)
		if nodes.size() != 1 or nodes[0].global_position.distance_to(anchor(id)) > .001:
			missing.append(id)
	assert(missing.is_empty(), "Building export and gameplay anchors differ: " + str(missing))

func anchor(id: String) -> Vector3:
	var p: Array = manifest.anchors[id]
	return Vector3(float(p[0]), float(p[2]), -float(p[1]))
