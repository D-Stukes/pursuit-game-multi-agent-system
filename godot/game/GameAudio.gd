extends Node
## Persistent mixer; sound never owns gameplay state or completion.
const SETTINGS := "user://audio-settings.cfg"
const MUSIC_PLAY_DB: float = -3.0
const MUSIC_MENU_DB: float = -9.0
const DEFAULTS := {"Master":0.5,"Music":0.5,"Effects":0.5}
const PREVIOUS_DEFAULTS := {"Master":0.8,"Music":0.22,"Effects":0.65}
const MIX_VERSION: int = 2
var levels: Dictionary = DEFAULTS.duplicate()
signal volume_changed
const UPSTAIRS_TRACKS: Array[String]=["electric-dreams","horizons","helios"]
const TRACK_TITLES: Dictionary={"hymn":"Hymn","electric-dreams":"Electric Dreams","horizons":"Horizons","helios":"Helios","discovery":"Discovery"}
var upstairs_track: String="electric-dreams"
var context: String="ground"
var active_track: String="hymn"
var preview_track: String=""
var focused: bool=true
var menu_open: bool=false
var voice_active: bool=false
var retiring: AudioStreamPlayer
var preview_timer: Timer
var retirement: Tween
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var fade: Tween
var footsteps_remaining: float = 0.0
var save_timer: Timer
var played: Dictionary = {}

func _ready() -> void:
	for bus: String in ["Music","Effects"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	var config:=ConfigFile.new()
	config.load(SETTINGS)
	levels=levels_from_config(config)
	var selected: String=str(config.get_value("audio","upstairs_track","electric-dreams"))
	if selected in UPSTAIRS_TRACKS:upstairs_track=selected
	for bus: String in levels: _apply(bus)
	save_timer=Timer.new();save_timer.one_shot=true;save_timer.wait_time=.3
	save_timer.timeout.connect(save_settings);add_child(save_timer)
	for sound: String in ["menu","pipe-turn","success","error","shot","hit","damage","step","unlock"]:
		sounds[sound]=load("res://assets/audio/"+sound+".wav")
	for index: int in range(12):
		var voice:=AudioStreamPlayer.new();voice.bus="Effects";add_child(voice);voices.append(voice)
	music=AudioStreamPlayer.new();music.bus="Music";music.volume_db=-60;add_child(music)
	retiring=AudioStreamPlayer.new();retiring.bus="Music";retiring.volume_db=-60;add_child(retiring)
	preview_timer=Timer.new();preview_timer.one_shot=true;preview_timer.wait_time=8;add_child(preview_timer)
	preview_timer.timeout.connect(stop_preview)
	music.stream=_stream("hymn")
	if DisplayServer.get_name()!="headless":music.play()
	set_menu_open(false)

func _stream(id: String) -> AudioStreamMP3:
	var stream: AudioStreamMP3=load("res://assets/audio/"+id+"-scott-buckley.mp3").duplicate()
	stream.loop=true;stream.loop_offset=0
	return stream

func _gain() -> float:
	return (MUSIC_MENU_DB if menu_open else MUSIC_PLAY_DB)+(0.0 if active_track=="hymn" else -4.0)+(-9.0 if voice_active else 0.0)

func _refresh_track() -> void:
	var wanted: String=preview_track if not preview_track.is_empty() else ("discovery" if context=="shooter" else upstairs_track if context=="upstairs" else "hymn")
	if wanted==active_track:return
	if fade:fade.kill()
	if retirement:retirement.kill()
	retiring.stop()
	var old: AudioStreamPlayer=music;music=retiring;retiring=old
	active_track=wanted;music.stream=_stream(wanted);music.volume_db=-60
	if DisplayServer.get_name()!="headless":music.play();music.stream_paused=not focused
	fade=create_tween();fade.tween_property(music,"volume_db",_gain(),1.2)
	retirement=create_tween();retirement.tween_property(retiring,"volume_db",-60.0,1.2)
	var previous: AudioStreamPlayer=retiring
	retirement.tween_callback(previous.stop)

func set_context(value: String) -> void:
	if value not in ["ground","upstairs","shooter"]:return
	if context!=value:
		context=value;preview_track="";preview_timer.stop()
	_refresh_track()

func select_upstairs(id: String) -> void:
	if id not in UPSTAIRS_TRACKS:return
	upstairs_track=id;save_timer.start();_refresh_track()

func preview_upstairs() -> void:
	preview_track=upstairs_track;preview_timer.start();_refresh_track()

func stop_preview() -> void:
	preview_track="";preview_timer.stop();_refresh_track()

func set_voice_active(active: bool) -> void:
	voice_active=active;_retarget_mix()

func _retarget_mix() -> void:
	if not is_instance_valid(music) or not is_inside_tree():return
	if fade:fade.kill()
	fade=create_tween();fade.tween_property(music,"volume_db",_gain(),.35)

func levels_from_config(config: ConfigFile) -> Dictionary:
	var loaded: Dictionary=DEFAULTS.duplicate()
	var previous_defaults: bool=true
	for bus: String in loaded:
		var value: Variant=config.get_value("volume",bus,DEFAULTS[bus])
		if (value is float or value is int) and is_finite(float(value)):
			loaded[bus]=clampf(float(value),0,1)
		previous_defaults=previous_defaults and is_equal_approx(float(loaded[bus]),float(PREVIOUS_DEFAULTS[bus]))
	# Upgrade only the untouched prototype preset. Preserve player choices/mutes.
	if config.get_value("audio","mix_version",0)!=MIX_VERSION and previous_defaults: return DEFAULTS.duplicate()
	return loaded

func _apply(bus: String) -> void:
	var index: int=AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index,float(levels[bus])<=0)
	AudioServer.set_bus_volume_linear(index,float(levels[bus]))

func set_volume(bus: String, value: float) -> void:
	if not levels.has(bus) or not is_finite(value): return
	levels[bus]=clampf(value,0,1);_apply(bus);save_timer.start();volume_changed.emit()

func save_settings() -> void:
	var config:=ConfigFile.new()
	for bus: String in levels: config.set_value("volume",bus,levels[bus])
	config.set_value("audio","mix_version",MIX_VERSION)
	config.set_value("audio","upstairs_track",upstairs_track)
	var error: Error=config.save(SETTINGS)
	if error!=OK: push_warning("Could not save volume settings: "+error_string(error))

func play(sound: String) -> void:
	if not sounds.has(sound): return
	played[sound]=int(played.get(sound,0))+1
	if DisplayServer.get_name()=="headless": return
	for voice: AudioStreamPlayer in voices:
		if not voice.playing:
			voice.stream=sounds[sound]
			voice.volume_db=-24.0 if sound=="step" else 0.0
			voice.pitch_scale=randf_range(.94,1.06) if sound=="step" else 1.0
			voice.play();return

func walk(_delta: float, distance: float, grounded: bool) -> void:
	if not grounded or distance<.001:
		footsteps_remaining=0;return
	footsteps_remaining-=distance
	if footsteps_remaining<=0:
		play("step");footsteps_remaining=1.8

func set_menu_open(open: bool) -> void:
	menu_open=open;_retarget_mix()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused=false
		if is_instance_valid(music): music.stream_paused=true
		if is_instance_valid(retiring):retiring.stream_paused=true
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		focused=true
		if is_instance_valid(music): music.stream_paused=false
		if is_instance_valid(retiring):retiring.stream_paused=false

func _exit_tree() -> void:
	if save_timer and not save_timer.is_stopped(): save_settings()
