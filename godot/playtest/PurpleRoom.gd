extends Node3D
## Native reusable interior; question panels are a visual preview, not content logic.
const RADIUS: float = 4.6
const HEIGHT: float = 3.8
@export var room_environment: Environment
@onready var mrp: Node3D = $MrP
@onready var spawn: Marker3D = $PlayerSpawn
@onready var return_point: Marker3D = $ReturnPoint
@onready var return_prompt: Label3D = $ReturnPoint/Prompt
var panels: Array[Node] = []

func _ready() -> void:
	panels = find_children("QuestionBoard*", "Node3D", true, false)
	for i: int in range(panels.size()):
		panels[i].get_node("Header").text = "QUESTION %d · PREVIEW" % (i+1)
	set_active(false)

func set_active(active: bool) -> void:
	visible = active
	mrp.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
