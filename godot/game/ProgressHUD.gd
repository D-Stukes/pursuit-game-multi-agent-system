extends VBoxContainer
## Read-only presentation of a published shared-state snapshot. No game authority.
signal pellet_requested
var pellet_button: Button
var theme_source: Control
var metrics: Label
var meter: ProgressBar
var activity: Label
var compact: bool = true
var latest: Dictionary = {}
var fill: StyleBoxFlat

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	metrics=theme_source._label("Energy — · Score —",16)
	metrics.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(metrics)
	meter=ProgressBar.new()
	meter.custom_minimum_size.y=12
	meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	meter.focus_mode=Control.FOCUS_NONE
	meter.show_percentage=false
	var background:=StyleBoxFlat.new()
	background.bg_color=theme_source.NAVY;background.border_color=theme_source.WHITE
	background.set_border_width_all(1)
	meter.add_theme_stylebox_override("background",background)
	fill=StyleBoxFlat.new();fill.bg_color=theme_source.CYAN
	meter.add_theme_stylebox_override("fill",fill)
	add_child(meter)
	pellet_button=theme_source._button("Reserve pellet +1",false)
	pellet_button.add_theme_font_size_override("font_size",14)
	pellet_button.custom_minimum_size.y=28
	pellet_button.pressed.connect(func():pellet_requested.emit())
	add_child(pellet_button)
	activity=theme_source._label("Activities: not started",14)
	activity.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(activity)

func set_compact(enabled: bool) -> void:
	compact=enabled
	apply_snapshot(latest)

func apply_snapshot(snapshot: Dictionary) -> void:
	latest=snapshot.duplicate(true)
	var course: Dictionary = snapshot.get("course",{})
	var energy: int = int(course.get("energy",0))
	var maximum: int = int(course.get("maximum_energy",0))
	metrics.text="Energy %d / %d · Score %d"%[energy,maximum,int(course.get("score",0))]
	metrics.modulate=theme_source.ERROR if maximum>0 and energy==0 else theme_source.WHITE
	meter.max_value=maxi(1,maximum);meter.value=energy;meter.visible=maximum>0
	fill.bg_color=theme_source.ERROR if energy==0 else theme_source.CYAN
	var reserve: int=int(snapshot.get("reserve_pellets",0))
	pellet_button.visible=reserve>0
	pellet_button.disabled=energy>=maximum or snapshot.get("review_mode",false) or snapshot.get("stage","")!="course_active"
	pellet_button.text="Reserve +1 · Saved" if pellet_button.disabled else "Use reserve +1"
	pellet_button.tooltip_text="Saved until energy drops below its maximum. Restores one energy; cannot exceed the maximum."
	var required: Array = course.get("required_questions",[])+course.get("required_challenges",[])
	var completed: Array = course.get("completed_questions",[])+course.get("completed_challenges",[])
	if required.is_empty():
		activity.text="Activities: not started"
		activity.visible=not compact
		if compact: metrics.text="Energy %d / %d"%[energy,maximum]
		return
	activity.show()
	# Shared state owns validity. Unknown/repeated completion IDs add no count.
	var count: int = required.filter(func(id: String):return id in completed).size()
	var prefix: String = "Sample activities" if course.get("mode","")=="sample" else "Activities"
	activity.text="%s: %d / %d%s"%[prefix,count,required.size()," · Complete" if count==required.size() and course.get("complete",false) else ""]
