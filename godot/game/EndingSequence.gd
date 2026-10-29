extends Node
## Reusable ending; developer previews never publish completion or course rewards.
const State=preload("res://game/EndingState.gd")
const Event=preload("res://game/SessionEvent.gd")
var world: Node3D
var timing: Dictionary={}
var state: RefCounted
var active: bool=false
var preview: bool=false
var overlay: ColorRect
var panel: PanelContainer
var badge: Label
var heading: Label
var message: Label
var metrics: Label
var action: Button
var retry: Button
var art: Control
var chime: AudioStreamPlayer
var _origin: Dictionary={}
var _phase: String=""

class PortalArt extends Control:
	var cyan: Color
	var success: Color
	func _draw() -> void:
		var center:=Vector2(size.x*.5,size.y*.25)
		for index:int in range(24):
			var direction:=Vector2.from_angle(TAU*index/24.0)
			draw_line(center+direction*100,center+direction*minf(size.x*.65,size.y*.65),Color(cyan,.12),16,true)
		draw_circle(center,88,Color(success,.13))
		draw_rect(Rect2(center-Vector2(48,72),Vector2(96,144)),Color(cyan,.25))
		draw_rect(Rect2(center-Vector2(48,72),Vector2(96,144)),cyan,false,3)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-44,72),center+Vector2(44,72),Vector2(size.x*.8,size.y),Vector2(size.x*.2,size.y)]),Color(success,.08))
		draw_line(Vector2(0,center.y+72),Vector2(size.x,center.y+72),Color(success,.4),2,true)

func _ready() -> void:
	chime=AudioStreamPlayer.new();chime.bus="Effects";chime.volume_db=-14;chime.stream=_make_chime();add_child(chime)
	overlay=ColorRect.new();overlay.color=Color(world.hud.NAVY,.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(overlay)
	art=PortalArt.new();art.cyan=world.hud.CYAN;art.success=world.hud.SUCCESS
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.resized.connect(art.queue_redraw);overlay.add_child(art)
	panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",world.hud._panel_style())
	overlay.add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16);panel.add_child(column)
	badge=world.hud._label("",14);badge.modulate=world.hud.CYAN;column.add_child(badge)
	heading=world.hud._label("",32);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(heading)
	message=world.hud._label("",20);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(message)
	metrics=world.hud._label("",16);metrics.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(metrics)
	action=world.hud._button("Return to Game",true);action.pressed.connect(_action);column.add_child(action)
	retry=world.hud._button("Retry Ending",false);retry.pressed.connect(_retry);column.add_child(retry)
	panel.resized.connect(_fit);world.hud.resized.connect(_fit)
	column.minimum_size_changed.connect(func():call_deferred("_fit"))
	overlay.hide();_fit()

func _make_chime() -> AudioStreamWAV:
	# A quiet, original rising chord; no recorded voice or external music.
	var samples:=PackedByteArray();samples.resize(22050)
	for index:int in range(11025):
		var time:float=float(index)/22050.0
		var value:float=0
		for note:int in range(4):
			var local_time:float=time-float(note)*.07
			if local_time>=0:
				value+=sin(TAU*[523.25,659.25,783.99,1046.5][note]*local_time)*exp(-local_time*12)*minf(1,local_time*120)*.13
		samples.encode_s16(index*2,int(clampf(value,-1,1)*32767))
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050;stream.data=samples
	return stream

func _fit() -> void:
	panel.custom_minimum_size.x=minf(560,world.hud.size.x-48)
	# Give wrapped text its width before measuring the panel's first open.
	for label: Label in [heading,message,metrics]: label.custom_minimum_size.x=panel.custom_minimum_size.x-32
	panel.reset_size();panel.position=(world.hud.size-panel.size)/2
	if art.visible: panel.position.y=world.hud.size.y-panel.size.y-24
	art.queue_redraw()

func start(is_preview: bool=false) -> bool:
	if active or not world.ready_for_test or world.lift_in_progress or world.computer_portal.transitioning or world.hud.menu_open or world.arrival_busy(): return false
	var candidate: RefCounted=State.new(timing)
	if not world.orchestrator.begin_ending(candidate,is_preview): return false
	state=candidate;active=true;preview=is_preview;_phase=""
	var player: CharacterBody3D=world.player
	_origin={"position":player.global_position,"rotation":player.camera_pivot.rotation,"zoom":player.spring_arm.spring_length,"visual_yaw":player.visual.rotation.y,"environment":player.camera.environment,"location":world.last_location}
	world.npc_conversations.interrupt()
	player.set_controls_locked(true)
	world.hud.hint_timer.stop();world.hud.hint_panel.hide()
	world.hud.travel_label.text="Returning to the classroom"
	world.hud.travel_overlay.show()
	# Keep the opaque fade above the presentation, but below Settings.
	world.hud.move_child(world.hud.travel_overlay,world.hud.get_child_count()-1)
	_present();return true

func safe_classroom_position() -> Vector3:
	var player: CharacterBody3D=world.player
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new();capsule.radius=player.RADIUS+.03;capsule.height=player.HEIGHT
	for offset: Vector3 in [Vector3.ZERO,Vector3(0,0,.6),Vector3(0,0,-.6),Vector3(-.6,0,0),Vector3(.6,0,0),Vector3(0,0,1.2)]:
		var feet: Vector3=world.LOCATIONS[2]+offset
		var floor_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.3,feet-Vector3.UP*.3,1))
		if floor_hit.is_empty() or floor_hit.normal.y<.9 or absf(floor_hit.position.y-feet.y)>.1: continue
		feet.y=floor_hit.position.y+.04
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1|8
		query.exclude=[player.get_rid()];query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*(player.HEIGHT*.5+.01))
		if space.intersect_shape(query).is_empty(): return feet
	return Vector3.INF

func _process(delta: float) -> void:
	if not active: return
	chime.stream_paused=world.hud.menu_open
	overlay.visible=not world.hud.menu_open
	world.hud.travel_overlay.visible=not world.hud.menu_open and state.phase in ["fade_out","placement","fade_in"]
	if world.hud.menu_open: return
	state.step(delta)
	if state.phase=="placement":
		var destination: Vector3=safe_classroom_position()
		if destination.is_finite():
			if not preview: world.computer_portal.leave_for_developer_travel()
			world.player.camera.environment=world.computer_portal.previous_environment if world.computer_portal.inside else world.player.camera.environment
			world.player.teleport_to(destination,world.LOCATION_HEADINGS[2])
			world.player.camera_pivot.rotation.x=-.14;world.player.spring_arm.spring_length=2.4
			world.last_location=2
		state.placed(destination.is_finite())
	if state.phase!=_phase: _present()
	if state.phase in ["fade_out","fade_in"]:
		var amount: float=clampf(state.elapsed/float(state.seconds[state.phase]),0,1)
		world.hud.set_travel_opacity(amount if state.phase=="fade_out" else 1.0-amount)

func _present() -> void:
	_phase=state.phase
	var fading: bool=_phase in ["fade_out","placement","fade_in"]
	overlay.visible=not fading
	world.hud.travel_overlay.visible=fading
	art.visible=_phase in ["celebration","complete"]
	overlay.color=world.hud.NAVY if art.visible else Color(world.hud.NAVY,.5)
	panel.visible=not fading
	badge.text="ENDING PREVIEW · Progress preserved" if preview else ("SAMPLE COURSE · STORY ENDING" if state.results.course.get("mode","")=="sample" else "THE JOURNEY · STORY ENDING")
	var course: Dictionary=state.results.course
	var required: Array=course.get("required_questions",[])+course.get("required_challenges",[])
	var completed: Array=course.get("completed_questions",[])+course.get("completed_challenges",[])
	metrics.text="Score %d   ·   Energy %d / %d\nActivities %d / %d"%[int(course.get("score",0)),int(course.get("energy",10)),int(course.get("maximum_energy",10)),required.filter(func(id:String):return id in completed).size(),required.size()]
	if required.is_empty(): metrics.text="Score %d   ·   Energy %d / %d\nActivities: not started"%[int(course.get("score",0)),int(course.get("energy",10)),int(course.get("maximum_energy",10))]
	heading.modulate=world.hud.WHITE
	action.visible=preview or _phase in ["complete","error"]
	action.text="Return to Game" if preview else "Play Again"
	retry.visible=_phase=="error" and not preview
	match _phase:
		"results":
			heading.text="Today's work is complete"
			message.text="This was the final challenge of your cycle. Your completed activities are ready for assessment."
			if preview: message.text="Preview the classroom results, assessment and L3 celebration. Your current run is preserved."
		"assessment":
			heading.text="Assessing your results…"
			message.text="A brief pause before your next chapter. Your journey continues."
		"celebration":
			chime.play()
			heading.text="You have advanced to L3!"
			heading.modulate=world.hud.SUCCESS
			message.text="Congratulations! A new chapter is waiting beyond the light."
		"complete":
			heading.text="L3 · The next chapter"
			message.text="Thank you for completing this chapter of The Journey."
			if not preview:
				var result: Dictionary=world.orchestrator.submit(world.orchestrator.new_event(Event.Kind.ENDING_PRESENTED))
				if not result.accepted:
					state.phase="error";_present();return
		"error":
			heading.text="The ending could not continue"
			message.text="Your progress is preserved. Try the ending again, or choose Play Again to start a fresh run."
		_:
			heading.text="";message.text=""
	_fit()
	call_deferred("_fit")
	if action.visible: action.call_deferred("grab_focus")

func _action() -> void:
	if preview: close_preview()
	else: world.request_restart()

func _retry() -> void:
	if preview or state.phase!="error": return
	world.orchestrator.end_presentation();active=false;overlay.hide()
	start(false)

func close_preview() -> void:
	if not active or not preview: return
	world.player.teleport_to(_origin.position)
	world.player.camera_pivot.rotation=_origin.rotation
	world.player.spring_arm.spring_length=_origin.zoom
	world.player.visual.rotation.y=_origin.visual_yaw
	world.player.camera.environment=_origin.environment
	world.last_location=_origin.location
	world.orchestrator.end_presentation()
	chime.stop()
	active=false;overlay.hide();world.hud.travel_overlay.hide()
	world.player.set_controls_locked(world.hud.menu_open)
