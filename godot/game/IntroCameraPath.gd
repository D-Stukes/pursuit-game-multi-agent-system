extends RefCounted
## Storyboard and live intro consume these same camera poses, in Godot metres.
const LENGTH: float=18.0
const SHOTS: Array[Dictionary]=[
 {"title":"1 · SKY AND GOLDEN CLOUDS","time":0.0,"position":Vector3(-17,2.8,16),"target":Vector3(32,30,0),"fov":70.0},
 {"title":"2 · STREET AND SCHOOL","time":6.0,"position":Vector3(-23,3.2,17),"target":Vector3(-4,4.5,4.75),"fov":68.0},
 {"title":"3 · APPROACH THE ENTRANCE","time":12.0,"position":Vector3(-8,2.7,13),"target":Vector3(0,2.2,4.85),"fov":62.0},
 {"title":"4 · STUDENT AT THE DOOR","time":18.0,"position":Vector3(0,2.2,11),"target":Vector3(0,1.4,4.85),"fov":58.0}]
static func apply(camera: Camera3D, elapsed: float, student: Vector3) -> void:
 var index: int=mini(2,maxi(0,int(elapsed/6.0)))
 var a: Dictionary=SHOTS[index];var b: Dictionary=SHOTS[index+1]
 var weight: float=smoothstep(0,1,clampf((elapsed-float(a.time))/6.0,0,1))
 var from: Vector3=a.position;var to: Vector3=b.position
 var target_from: Vector3=a.target;var target_to: Vector3=b.target
 # On replay end behind the student's current position rather than moving them.
 if index==2:
  to=student+Vector3(0,2.2,4.3);target_to=student+Vector3(0,1.4,-1.8)
 camera.fov=lerpf(float(a.fov),float(b.fov),weight)
 camera.look_at_from_position(from.lerp(to,weight),target_from.lerp(target_to,weight),Vector3.UP)
