extends Node3D
## Pose the retained entrance leaves; static building collision excludes these meshes.
var bodies: Array[StaticBody3D]=[]
var open: bool=true
var triangle_count: int=0

static func is_leaf(node: Node) -> bool:
 return str(node.name).begins_with("Exterior open door") or str(node.name).begins_with("Exterior door pull")

func configure(building: Node3D) -> void:
 var leaves: Array[Node]=building.find_children("*","MeshInstance3D",true,false).filter(func(mesh: Node):return is_leaf(mesh))
 for side: int in [-1,1]:
  var body:=StaticBody3D.new()
  body.name="LeftLeaf" if side<0 else "RightLeaf"
  body.position=Vector3(side*1.26,0,4.85)
  body.collision_layer=1;body.collision_mask=0
  add_child(body);bodies.append(body)
  var faces:=PackedVector3Array()
  for mesh: MeshInstance3D in leaves:
   var bounds: AABB=mesh.global_transform*mesh.get_aabb()
   if signf(bounds.get_center().x)!=side:continue
   mesh.reparent(body,true)
   for vertex: Vector3 in mesh.mesh.get_faces():faces.append(mesh.transform*vertex)
  assert(not faces.is_empty(),"Missing retained entrance leaf geometry")
  var shape:=ConcavePolygonShape3D.new()
  shape.set_faces(faces);shape.backface_collision=true
  triangle_count+=faces.size()/3
  var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
 set_open(false)

func set_open(value: bool) -> void:
 open=value
 for index: int in range(bodies.size()):
  bodies[index].rotation.y=0.0 if value else (PI/2 if index==0 else -PI/2)
