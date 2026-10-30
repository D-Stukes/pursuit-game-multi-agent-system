extends Node3D
## Mr. P greets the arriving student in the classroom: he faces the student and
## speaks his recorded welcome line once, the first time they stand in the room.
## Reuses the shared MrP art actor; owns no question or AI logic.
const WELCOME_PATH := "res://assets/audio/mrp/mrp_jeter_01_full.wav"
# Mr. P stays large/imposing here (full model size, no shrink).
# The art's front is ~90° off the -Z look axis; this rotates him to face front-on.
@export var yaw_offset: float = PI / 2.0

var world: Node3D
var voice: AudioStreamPlayer
var greeted: bool = false

func _ready() -> void:
	var mrp: Node3D = preload("res://scenes/characters/MrP.tscn").instantiate()
	add_child(mrp)
	voice = AudioStreamPlayer.new()
	voice.bus = "Effects"
	if ResourceLoader.exists(WELCOME_PATH):
		voice.stream = load(WELCOME_PATH)
	add_child(voice)

func _process(_delta: float) -> void:
	if world == null or world.player == null:
		return
	# Keep Mr. P turned toward the student (yaw only, feet planted).
	var target: Vector3 = world.player.global_position
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_squared_to(global_position) > 0.0025:
		look_at(flat, Vector3.UP)
		rotation.y += yaw_offset
	# Speak the welcome once, when the student first stands in the classroom.
	if not greeted and voice.stream != null and world.classroom_sequence != null \
			and world.classroom_sequence.in_classroom():
		greeted = true
		voice.play()
