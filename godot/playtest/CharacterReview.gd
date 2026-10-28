extends Node3D
## Isolated art review; does not change the building, player or progression.
const ASSETS := {"mr_p": "res://assets/generated/characters/mr-p.glb", "robot": "res://assets/generated/characters/robot.glb"}
const ROBOT_PARTS: Array[String] = ["torso","left_leg","right_leg","left_arm","right_arm","head","power_core"]
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
var parts_buttons: HBoxContainer
var sprite_panel: Control
var sprite_images: Dictionary = {}
var show_2d_button: Button

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
	var asset_buttons:=HBoxContainer.new();panel.add_child(asset_buttons)
	for id:String in ASSETS:
		var button:=Button.new();button.text="Mr. P" if id=="mr_p" else "Robot"
		button.pressed.connect(func(): load_asset(id));asset_buttons.add_child(button)
	show_2d_button=Button.new();show_2d_button.text="2D assembly layers";show_2d_button.toggle_mode=true
	show_2d_button.toggled.connect(set_2d);asset_buttons.add_child(show_2d_button)
	clip_buttons=HBoxContainer.new();panel.add_child(clip_buttons)
	parts_buttons=HBoxContainer.new();panel.add_child(parts_buttons)
	sprite_panel=Control.new();canvas.add_child(sprite_panel);sprite_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;sprite_panel.hide()
	get_viewport().size_changed.connect(func():
		if ready_for_test:frame_character(str(animation.current_animation) if animation else "Idle")
	)
	load_asset("mr_p")

func load_asset(id: String) -> void:
	ready_for_test=false
	if not ASSETS.has(id) or not ResourceLoader.exists(ASSETS[id]):
		title.text="Character export missing. Run the character build and preparation commands."
		return
	if is_instance_valid(model):model.queue_free()
	asset_id=id
	var packed:PackedScene=load(ASSETS[id]);model=packed.instantiate();add_child(model)
	var players:Array[Node]=model.find_children("*","AnimationPlayer",true,false)
	animation=players[0] if not players.is_empty() else null
	var skeletons:Array[Node]=model.find_children("*","Skeleton3D",true,false)
	skeleton=skeletons[0] if not skeletons.is_empty() else null
	for child:Node in clip_buttons.get_children():child.queue_free()
	for child:Node in parts_buttons.get_children():child.queue_free()
	for child:Node in sprite_panel.get_children():child.queue_free()
	sprite_images.clear();sprite_panel.hide();show_2d_button.set_pressed_no_signal(false)
	show_2d_button.visible=id=="robot"
	if animation:
		for clip:String in animation.get_animation_list():
			if clip=="RESET":continue
			var button:=Button.new();button.text=clip;button.pressed.connect(func(): play_clip(clip));clip_buttons.add_child(button)
		play_clip("Idle")
		animation.animation_finished.connect(func(_clip:StringName): play_clip("Idle"))
	if id=="robot":
		var registration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/characters/robot-parts/parts.json"))
		var layer_order:Array=registration.get("overlay_order",ROBOT_PARTS)
		for part:String in ROBOT_PARTS:
			var button:=Button.new();button.text=part.replace("_"," ");button.toggle_mode=true;button.button_pressed=true
			button.toggled.connect(func(visible:bool): set_part_visible(part,visible));parts_buttons.add_child(button)
			var path:String="res://assets/generated/characters/robot-parts/"+part+".png"
			if ResourceLoader.exists(path):
				var image:=TextureRect.new();image.texture=load(path);sprite_panel.add_child(image)
				image.z_index=layer_order.find(part)
				image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				image.offset_top=175;image.offset_bottom=-15;image.offset_left=20;image.offset_right=-20
				image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				image.mouse_filter=Control.MOUSE_FILTER_IGNORE;sprite_images[part]=image
		show_2d_button.disabled=sprite_images.size()!=ROBOT_PARTS.size()
	title.text=("Mr. P" if id=="mr_p" else "Robot")+" · character asset review"
	yaw=0;frame_character("Idle")
	ready_for_test=true

func play_clip(clip:String)->void:
	if not animation or not animation.has_animation(clip):return
	animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR if clip=="Idle" else Animation.LOOP_NONE
	animation.play(clip)
	frame_character(clip)

func frame_character(clip:String)->void:
	# Fit the declared full motion envelope below the review toolbar. This
	# changes the camera framing, never the mesh scale or assembly coordinates.
	var viewport_size:Vector2=get_viewport().get_visible_rect().size
	var toolbar:float=185.0 if asset_id=="robot" else 150.0
	var top:float=3.65 if asset_id=="mr_p" else (2.75 if clip=="Assemble" else 2.25)
	var width:float=2.5 if asset_id=="mr_p" else 3.1
	var available:float=maxf(.35,(viewport_size.y-toolbar)/viewport_size.y)
	var field_height:float=maxf(top/(available*.80),width/(viewport_size.x/viewport_size.y))
	distance=field_height/(2*tan(deg_to_rad(camera.fov*.5)))
	center=Vector3(0,top*.5+toolbar/viewport_size.y*field_height*.5,0)
	update_camera()

func set_2d(visible:bool)->void:
	if not model:return
	sprite_panel.visible=visible and asset_id=="robot";model.visible=not sprite_panel.visible
	for button:Button in clip_buttons.get_children():button.disabled=sprite_panel.visible

func set_part_visible(part:String,visible:bool)->void:
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var extras:Dictionary=mesh.get_meta("extras",{})
		if extras.get("part_id","")==part:mesh.visible=visible
	if sprite_images.has(part):sprite_images[part].visible=visible

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
