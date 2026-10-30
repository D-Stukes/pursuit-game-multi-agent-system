extends Node3D
## Places Mr. P in the classroom. He floats, faces the student and gestures via
## the shared MrPDisplay behaviour; here we just give him the player to watch and
## play his recorded welcome (voice + "Welcome" gesture) the first time the
## student stands in the room.
const WELCOME_PATH := "res://assets/audio/mrp/mrp_jeter_01_full.wav"

var world: Node3D
var mrp: Node3D
var voice: AudioStreamPlayer
var greeted: bool = false

func _ready() -> void:
	mrp = preload("res://scenes/characters/MrP.tscn").instantiate()
	mrp.hover_lift = 0.12   # a slight ghostly hover, not a balloon to the ceiling
	add_child(mrp)
	if world != null:
		mrp.look_target = world.player
	voice = AudioStreamPlayer.new()
	voice.bus = "Effects"
	if ResourceLoader.exists(WELCOME_PATH):
		voice.stream = load(WELCOME_PATH)
	add_child(voice)

func _process(_delta: float) -> void:
	if greeted or world == null or world.player == null or world.classroom_sequence == null:
		return
	if world.classroom_sequence.in_classroom():
		greeted = true
		mrp.play_once("Welcome")
		if voice.stream != null:
			voice.play()
