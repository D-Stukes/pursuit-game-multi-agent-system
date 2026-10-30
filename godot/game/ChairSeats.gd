extends RefCounted
## Seat surfaces come from the imported building, not guessed room coordinates.
var player: CharacterBody3D
var seats: Array[Dictionary]=[]
var active: Dictionary={}
var stand_origin:=Vector3.ZERO
func configure(actor: CharacterBody3D, building: Node3D) -> void:
 player=actor
 if building==null:return
 var meshes: Array[Node]=building.find_children("*","MeshInstance3D",true,false)
 var names: Dictionary={}
 for mesh: MeshInstance3D in meshes:names[str(mesh.name).to_lower()]=mesh
 for mesh: MeshInstance3D in meshes:
  var key: String=str(mesh.name).to_lower()
  if not key.contains("chair") or not key.contains("seat"):continue
  var bounds: AABB=mesh.global_transform*mesh.get_aabb()
  var point: Vector3=bounds.get_center();point.y=bounds.end.y
  var forward: Vector3=-mesh.global_basis.z;forward.y=0
  var back: MeshInstance3D=names.get(key.replace("seat","back"))
  if back!=null:
   var back_bounds: AABB=back.global_transform*back.get_aabb()
   forward=point-back_bounds.get_center();forward.y=0
  if forward.length_squared()<.001:forward=Vector3.FORWARD
  seats.append({"id":str(mesh.name),"point":point,"forward":forward.normalized()})
func nearest() -> Dictionary:
 if player==null:return {}
 var chosen: Dictionary={};var distance: float=1.1
 for seat: Dictionary in seats:
  var height: float=seat.point.y-player.global_position.y
  if height<.28 or height>.78:continue
  var difference: Vector3=seat.point-player.global_position;difference.y=0
  if difference.length()>=distance:continue
  # Eye-height visibility rejects chairs through partitions without hitting seat backs.
  var target: Vector3=Vector3(seat.point.x,player.global_position.y+1.4,seat.point.z)
  var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.4,target,1|4|8,[player.get_rid()])
  if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
  var occupied:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.4;capsule.radius=.28
  occupied.shape=capsule;occupied.transform=Transform3D(Basis.IDENTITY,Vector3(seat.point.x,player.global_position.y+.8,seat.point.z));occupied.collision_mask=8;occupied.exclude=[player.get_rid()]
  if not player.get_world_3d().direct_space_state.intersect_shape(occupied).is_empty():continue
  chosen=seat;distance=difference.length()
 return chosen
func begin(seat: Dictionary) -> void:
 active=seat;stand_origin=player.global_position
 player.global_position=Vector3(seat.point.x,stand_origin.y,seat.point.z)
 player.visual.rotation.y=atan2(-seat.forward.x,-seat.forward.z)
 player.reset_physics_interpolation()
func _clear_at(point: Vector3) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.height=player.HEIGHT;capsule.radius=player.RADIUS
 query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(player.HEIGHT/2+.05));query.collision_mask=1|4|8;query.exclude=[player.get_rid()]
 if not player.get_world_3d().direct_space_state.intersect_shape(query).is_empty():return false
 var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point-Vector3.UP*.25,1,[player.get_rid()])
 var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(ray)
 if hit.is_empty() or hit.normal.y<.9:return false
 var sight:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.4,point+Vector3.UP*1.4,1|4,[player.get_rid()])
 return player.get_world_3d().direct_space_state.intersect_ray(sight).is_empty()
func exit_point() -> Vector3:
 if active.is_empty():return player.global_position
 if _clear_at(stand_origin):return stand_origin
 for radius: float in [.8,1.1,1.4,1.8]:
  for i in range(16):
   var angle: float=TAU*i/16
   var at: Vector3=Vector3(active.point.x+cos(angle)*radius,stand_origin.y,active.point.z+sin(angle)*radius)
   if _clear_at(at):return at
 return Vector3.INF
