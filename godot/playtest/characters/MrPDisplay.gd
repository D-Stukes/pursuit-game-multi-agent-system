extends Node3D
## Reusable rigged art actor. Question content and AI remain separate.
var skeleton: Skeleton3D
var animation: AnimationPlayer

func _ready() -> void:
	skeleton = $Model.find_children("*", "Skeleton3D", true, false)[0]
	animation = $Model.find_children("*", "AnimationPlayer", true, false)[0]
	animation.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	animation.play("Idle")
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = 35.0
		mesh.visibility_range_end_margin = 3.0
