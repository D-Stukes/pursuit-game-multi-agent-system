extends Node3D
## Isolated art review; does not change the building, player or progression.
const ASSETS := {"mr_p": "res://assets/generated/characters/mr-p.glb"}
var model: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var camera: Camera3D
var asset_id: String = "mr_p"
var yaw: float = 0.0
var distance: float = 6.3
var center := Vector3(0, 1.8, 0)
var ready_for_test := false
var clip_buttons: HBoxContainer
var title: Label
var spin: bool = false

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.14,.16,.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.88,.91,1)
	env.ambient_light_energy = .4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new();world.environment=env;add_child(world)
	for data: Array in [[Vector3(-35,-30,0),1.5],[Vector3(-20,140,0),.7]]:
		var light:=DirectionalLight3D.new();light.rotation_degrees=data[0];light.light_energy=data[1]
		# Neutral art inspection uses clean fill lighting; scene-specific game
		# shadow tuning belongs to the eventual character integration.
		light.shadow_enabled=false
		add_child(light)
	camera=Camera3D.new();camera.current=true;camera.fov=42;camera.near=.03;add_child(camera)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var panel:=VBoxContainer.new();panel.position=Vector2(20,18);canvas.add_child(panel)
	title=Label.new();title.add_theme_font_size_override("font_size",22);panel.add_child(title)
	var instructions:=Label.new();instructions.text="Drag to orbit · Wheel to zoom · F: front · P: profile · B: back · T: turntable · Esc: close";panel.add_child(instructions)
	clip_buttons=HBoxContainer.new();panel.add_child(clip_buttons)
	load_asset("mr_p")

func load_asset(id: String) -> void:
	ready_for_test=false
	if model:model.queue_free()
	if not ASSETS.has(id) or not ResourceLoader.exists(ASSETS[id]):
		title.text="Character export missing. Run the character build and preparation commands."
		return
	asset_id=id
	var packed:PackedScene=load(ASSETS[id]);model=packed.instantiate();add_child(model)
	var players:Array[Node]=model.find_children("*","AnimationPlayer",true,false)
	animation=players[0] if not players.is_empty() else null
	var skeletons:Array[Node]=model.find_children("*","Skeleton3D",true,false)
	skeleton=skeletons[0] if not skeletons.is_empty() else null
	for child:Node in clip_buttons.get_children():child.queue_free()
	if animation:
		for clip:String in animation.get_animation_list():
			if clip=="RESET":continue
			var button:=Button.new();button.text=clip;button.pressed.connect(func(): play_clip(clip));clip_buttons.add_child(button)
		play_clip("Idle")
	title.text="Mr. P · character asset review"
	yaw=0;distance=6.3;center=Vector3(0,1.8,0);update_camera()
	ready_for_test=true

func play_clip(clip:String)->void:
	if not animation or not animation.has_animation(clip):return
	animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	animation.play(clip)

func update_camera()->void:
	camera.look_at_from_position(center+Vector3(sin(yaw)*distance,.20,cos(yaw)*distance),center)

func _process(delta:float)->void:
	if spin:yaw+=delta*.35;update_camera()

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw-=event.relative.x*.008;update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(2.5,distance-.3)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(12,distance+.3)
		update_camera()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:get_tree().quit()
			KEY_F:yaw=0;update_camera()
			KEY_P:yaw=PI/2;update_camera()
			KEY_B:yaw=PI;update_camera()
			KEY_T:spin=not spin
