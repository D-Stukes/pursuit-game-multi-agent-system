extends RefCounted
## Storyboard and live intro consume these same camera poses, in Godot metres.
## The last shot is the gameplay camera itself, so the intro settles exactly where play begins.
const TEXT_START: float=12.0
const LENGTH: float=38.0
const SHOTS: Array[Dictionary]=[
 {"title":"1 · SKY AND GOLDEN CLOUDS","time":0.0,"position":Vector3(-17,2.8,16),"target":Vector3(32,30,0),"fov":70.0},
 {"title":"2 · STREET AND SCHOOL","time":6.0,"position":Vector3(-23,3.2,17),"target":Vector3(-4,4.5,4.75),"fov":68.0},
 {"title":"3 · APPROACH AS THE TEXT RISES","time":TEXT_START,"position":Vector3(-8,2.7,13),"target":Vector3(0,2.2,4.85),"fov":62.0},
 {"title":"4 · SETTLE INTO THE PLAYER VIEW","time":LENGTH}]
static func apply(camera: Camera3D, elapsed: float, arrival: Transform3D, arrival_fov: float) -> void:
 var points: Array[Vector3]=[];var targets: Array[Vector3]=[];var fovs: Array[float]=[]
 for shot: Dictionary in SHOTS.slice(0,3):points.append(shot.position);targets.append(shot.target);fovs.append(float(shot.fov))
 points.append(arrival.origin);targets.append(arrival.origin-arrival.basis.z*3.0);fovs.append(arrival_fov)
 var u: float=progress(elapsed)
 var i: int=mini(int(u),2);var w: float=u-i
 camera.fov=cubic_interpolate(fovs[i],fovs[i+1],fovs[maxi(i-1,0)],fovs[mini(i+2,3)],w)
 camera.look_at_from_position(_spline(points,i,w),_spline(targets,i,w),Vector3.UP)
## Monotone cubic time warp over the shot times: eases in and out without pausing at shots 2 and 3.
static func progress(elapsed: float) -> float:
 var t: float=clampf(elapsed,0,LENGTH);var i: int=0
 while i<SHOTS.size()-2 and t>float(SHOTS[i+1].time):i+=1
 var h: float=float(SHOTS[i+1].time)-float(SHOTS[i].time);var x: float=(t-float(SHOTS[i].time))/h
 return i+(3*x*x-2*x*x*x)+h*(_slope(i)*(x*x*x-2*x*x+x)+_slope(i+1)*(x*x*x-x*x))
static func _slope(i: int) -> float:
 if i==0 or i==SHOTS.size()-1:return 0.0
 var h0: float=float(SHOTS[i].time)-float(SHOTS[i-1].time);var h1: float=float(SHOTS[i+1].time)-float(SHOTS[i].time)
 return 3*(h0+h1)/((2*h1+h0)*h0+(h1+2*h0)*h1)
static func _spline(values: Array[Vector3], i: int, w: float) -> Vector3:
 var before: Vector3=values[i-1] if i>0 else values[0]*2-values[1]
 var after: Vector3=values[i+2] if i+2<values.size() else values[i+1]*2-values[i]
 return values[i].cubic_interpolate(values[i+1],before,after,w)
