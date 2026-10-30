extends Control
## Panoramic street sequence, then readable introduction; Skip always restores play.
signal closed
const DESCRIPTION: String="This game depicts the experience of students attending the Pursuit Fellowship’s 2026 AI Builder’s Program.\n\nPeople of different ages and backgrounds, including those underserved by traditional pathways into technology, learn current technologies, expand their professional networks, and build skills that can improve their employment opportunities and quality of life."
const DURATION: float=24.0
const Path=preload("res://game/IntroCameraPath.gd")
var world: Node3D
var active: bool=false
var elapsed: float=0
var static_text: bool=false
var camera: Camera3D
var title: Label
var subtitle: Label
var window: Control
var paragraph: Label
var skip_button: Button
var static_button: Button
var finish_button: Button
var fade: Tween
var finishing: bool=false
var application_focused: bool=true
var preview_student: Node3D
var student_point:=Vector3.ZERO
func _ready() -> void:
 application_focused=DisplayServer.get_name()=="headless" or get_window().has_focus()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var shade:=ColorRect.new();shade.color=Color(.015,.025,.06,.42);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
 title=world.hud._label("PURSUIT · THE JOURNEY",36);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(title)
 subtitle=world.hud._label("A new beginning",20);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(subtitle)
 window=Control.new();window.clip_contents=true;window.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(window)
 paragraph=world.hud._label(DESCRIPTION,25);paragraph.add_theme_color_override("font_outline_color",Color(.01,.015,.03,.85));paragraph.add_theme_constant_override("outline_size",4);paragraph.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;paragraph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;window.add_child(paragraph)
 skip_button=world.hud._button("Skip intro [Esc]",false);skip_button.pressed.connect(finish);add_child(skip_button)
 static_button=world.hud._button("Read without motion",false);static_button.pressed.connect(func():static_text=not static_text;_fit();_update_scene());add_child(static_button)
 finish_button=world.hud._button("Continue to entrance",true);finish_button.pressed.connect(finish);add_child(finish_button)
 resized.connect(_fit);hide()
func start() -> bool:
 if active or not world.ready_for_test or world.arrival_busy() or world.entrance_puzzle.visible or world.elevator_game.visible or world.lift_in_progress or world.computer_portal.transitioning or not world.orchestrator.claim("intro"):return false
 active=true;finishing=false;elapsed=0;static_text=GamePreferences.reduced_motion
 modulate.a=1;show();_fit();world.hud.hide();world.player.set_controls_locked(true)
 camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=70
 student_point=world.LOCATIONS[0]
 if world.player.global_position.distance_to(student_point)>2:
  preview_student=world.player.visual.duplicate();world.add_child(preview_student)
  preview_student.global_position=student_point;preview_student.rotation=Vector3.ZERO;preview_student.show()
  for animation: AnimationPlayer in preview_student.find_children("*","AnimationPlayer",true,false):animation.stop()
 _update_scene()
 skip_button.grab_focus()
 return true
func _fit() -> void:
 if not is_instance_valid(window):return
 title.position=Vector2(24,40);title.size=Vector2(size.x-48,52)
 subtitle.position=Vector2(24,100);subtitle.size=Vector2(size.x-48,30)
 var width: float=minf(760,size.x-64)
 window.position=Vector2((size.x-width)/2,155);window.size=Vector2(width,maxf(230,size.y-270))
 paragraph.custom_minimum_size.x=width;paragraph.size.x=width
 paragraph.add_theme_font_size_override("font_size",22 if size.y<650 else 25)
 paragraph.size.y=paragraph.get_minimum_size().y
 static_button.text="Animated text" if static_text else "Read without motion"
 var button_width: float=minf(240,(size.x-64)/3)
 for i in range(3):
  var button: Button=[skip_button,static_button,finish_button][i]
  button.position=Vector2((size.x-button_width*3-24)/2+i*(button_width+12),size.y-76);button.size=Vector2(button_width,48)
 _place_text()
func _place_text() -> void:
 if static_text:paragraph.position.y=maxf(0,(window.size.y-paragraph.size.y)/2)
 else:paragraph.position.y=lerpf(window.size.y+12,-paragraph.size.y-12,clampf((elapsed-Path.LENGTH)/DURATION,0,1))
func _update_scene() -> void:
 if not active or not is_instance_valid(camera):return
 var panoramic: bool=not static_text and elapsed<Path.LENGTH
 window.visible=not panoramic
 subtitle.text="Austell Street · Your first day" if panoramic else "A new beginning"
 Path.apply(camera,Path.LENGTH if static_text else minf(elapsed,Path.LENGTH),student_point)
 _place_text()
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:application_focused=false
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:application_focused=true
func _process(delta: float) -> void:
 if not active or finishing or not application_focused:return
 if not static_text:
  elapsed+=delta
  paragraph.modulate.a=minf(1,(Path.LENGTH+DURATION-elapsed)/1.0)
  if elapsed>=Path.LENGTH+DURATION:finish()
 else:paragraph.modulate.a=1
 _update_scene()
func _input(event: InputEvent) -> void:
 if not active:return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
  finish();get_viewport().set_input_as_handled()
func finish(mark_seen: bool=true) -> void:
 if not active or finishing:return
 finishing=true
 if mark_seen:GamePreferences.mark_intro_seen()
 if GamePreferences.reduced_motion or DisplayServer.get_name()=="headless":_restore()
 else:
  fade=create_tween();fade.tween_property(self,"modulate:a",0.0,.5);fade.tween_callback(_restore)
func _restore() -> void:
 if is_instance_valid(camera):camera.queue_free()
 if is_instance_valid(preview_student):preview_student.queue_free()
 world.player.camera.current=true;world.hud.show();hide();active=false;finishing=false
 world.orchestrator.release("intro");world.player.set_controls_locked(world.hud.menu_open)
 world.hud.show_navigation_hint("Approach the keypad left of the entrance to begin. Esc opens controls and help." if not world.orchestrator.entrance_allowed() else "Follow your current objective. Esc opens controls and help.")
 closed.emit()
