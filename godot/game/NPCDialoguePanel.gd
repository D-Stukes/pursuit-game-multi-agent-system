extends Control
## Native HUD dialogue; no model request is made for the scripted greeting.
signal closed
signal topic_requested(topic: String)
var theme_source: Control
var topics: Dictionary
var column: VBoxContainer
var panel: PanelContainer
var heading: Label
var status: Label
var text_label: Label
var scroll: ScrollContainer
var choices: Array[Button] = []
var close_button: Button
var waiting: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",theme_source._panel_style())
	add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	heading = theme_source._label("",24)
	column.add_child(heading)
	status = theme_source._label("",14)
	column.add_child(status)
	status.hide()
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 120
	column.add_child(scroll)
	text_label = theme_source._label("",20)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text_label)
	_build_choices(topics)
	close_button = theme_source._button("Thanks [Esc]",true)
	close_button.pressed.connect(_say_thanks)
	column.add_child(close_button)
	var controls: Array[Control] = []
	controls.append_array(choices)
	controls.append(close_button)
	for i: int in range(controls.size()):
		controls[i].focus_next = controls[i].get_path_to(controls[(i+1)%controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i-1+controls.size())%controls.size()])
	resized.connect(_fit)
	_fit()
	hide()

func _build_choices(options: Dictionary) -> void:
	for button: Button in choices:
		column.remove_child(button);button.queue_free()
	choices.clear()
	for topic: String in options:
		var button: Button=theme_source._button(options[topic],false)
		button.set_meta("topic",topic)
		button.pressed.connect(func():
			if not waiting:topic_requested.emit(str(button.get_meta("topic"))))
		column.add_child(button)
		if is_instance_valid(close_button):column.move_child(button,close_button.get_index())
		choices.append(button)
	if is_instance_valid(close_button):
		var controls: Array[Control]=[];controls.append_array(choices);controls.append(close_button)
		for i: int in range(controls.size()):
			controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()])
			controls[i].focus_previous=controls[i].get_path_to(controls[(i-1+controls.size())%controls.size()])

func _fit() -> void:
	if not is_instance_valid(panel): return
	panel.size = Vector2(minf(660,size.x-48),minf(510,size.y-48))
	panel.position = (size-panel.size)*.5

func open_for(label: String, text: String, options: Dictionary = {}) -> void:
	if not options.is_empty():
		if options.size()!=choices.size(): _build_choices(options)
		var index: int = 0
		for topic: String in options:
			choices[index].text=options[topic];choices[index].set_meta("topic",topic);index+=1
	heading.text = label
	text_label.text = text
	set_waiting(false)
	show()
	choices[0].grab_focus()
	scroll.scroll_vertical = 0

func set_waiting(value: bool) -> void:
	waiting = value
	for button: Button in choices: button.disabled = value
	set_notice("Waiting for a reply…" if value else "")
	if value:
		close_button.grab_focus()

func set_notice(text: String) -> void:
	status.text = text
	status.visible = not text.is_empty()

func present_reply(text: String, fallback: bool = false) -> void:
	text_label.text = text
	scroll.scroll_vertical = 0
	set_waiting(false)
	if fallback: set_notice("Connection unavailable. Here’s a hint instead.")
	choices[0].grab_focus()

func _say_thanks() -> void:
	if waiting:
		close();return
	set_waiting(true);set_notice("You: Thanks")
	var utterance: int=DialogueVoice.speak("Thanks")
	if utterance!=0:await DialogueVoice.finished
	if visible:close()

func close() -> void:
	hide()
	set_waiting(false)
	closed.emit()
