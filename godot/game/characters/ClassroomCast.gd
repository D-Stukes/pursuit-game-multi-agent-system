extends Node3D
## The classroom repair display stays separate from the building GLB.
var bench: StaticBody3D
var world: Node3D  ## Set by Main before this node enters the tree; used by Mr. P.

func _ready() -> void:
	_add_mr_p()
	bench = StaticBody3D.new()
	bench.name = "RepairBench"
	bench.collision_layer = 1
	bench.collision_mask = 0
	bench.position = Vector3(-14.05, 5.058, 1.8)
	add_child(bench)
	var top_material := StandardMaterial3D.new()
	top_material.albedo_color = Color(.14,.20,.23)
	top_material.roughness = .75
	_box(bench, Vector3(0,.775,0), Vector3(1.75,.05,2.8), top_material)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(.35,.39,.40)
	metal.metallic = .65
	for x: float in [-.72,.72]:
		for z: float in [-1.2,1.2]:
			_box(bench, Vector3(x,.375,z), Vector3(.065,.75,.065), metal)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.75,.80,2.8)
	collision.shape = shape
	collision.position.y = .40
	bench.add_child(collision)

func _add_mr_p() -> void:
	# Mr. P stands near the front of the room, turned to greet the entering student.
	var greeter: Node3D = preload("res://game/characters/ClassroomMrP.gd").new()
	greeter.name = "ClassroomMrP"
	greeter.world = world
	greeter.position = Vector3(0.38, 5.05, -1.0)
	add_child(greeter)

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
