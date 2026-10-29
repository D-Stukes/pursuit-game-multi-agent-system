extends SceneTree
var checks: int=0
var failures: int=0
var audio: Node
func _initialize() -> void: call_deferred("run")
func check(label: String, ok: bool) -> void:
	checks+=1
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)
func run() -> void:
	audio=root.get_node("GameAudio")
	audio.save_timer.process_mode=Node.PROCESS_MODE_DISABLED
	var original: Dictionary=audio.levels.duplicate()
	check("fresh installation starts all sliders at 50 percent",audio.levels_from_config(ConfigFile.new())=={"Master":.5,"Music":.5,"Effects":.5})
	var config:=ConfigFile.new()
	for bus: String in audio.PREVIOUS_DEFAULTS: config.set_value("volume",bus,audio.PREVIOUS_DEFAULTS[bus])
	check("untouched prototype preset upgrades to 50 percent",audio.levels_from_config(config)==audio.DEFAULTS)
	config.set_value("volume","Music",0.0)
	check("saved player mute survives preset upgrade",audio.levels_from_config(config).Music==0.0)
	config.set_value("volume","Music",.73)
	check("custom player volume survives preset upgrade",is_equal_approx(audio.levels_from_config(config).Music,.73))
	for bus: String in ["Master","Music","Effects"]:
		var index: int=AudioServer.get_bus_index(bus)
		check(bus+" bus exists",index>=0)
		audio.set_volume(bus,0)
		check(bus+" zero mutes",AudioServer.is_bus_mute(index))
		audio.set_volume(bus,.5)
		var middle: float=AudioServer.get_bus_volume_linear(index)
		audio.set_volume(bus,1.0)
		check(bus+" maximum is stronger than midpoint",not AudioServer.is_bus_mute(index) and AudioServer.get_bus_volume_linear(index)>middle)
		audio.set_volume(bus,.4)
		check(bus+" volume applies independently",not AudioServer.is_bus_mute(index) and is_equal_approx(AudioServer.get_bus_volume_linear(index),.4))
		audio.set_volume(bus,2)
		check(bus+" values clamp",audio.levels[bus]==1.0)
	for sound: String in audio.sounds:
		var stream: AudioStreamWAV=audio.sounds[sound]
		check(sound+" has usable samples",stream.data.size()>0 and stream.get_length()>0)
	check("music loops forward",audio.music.stream is AudioStreamMP3 and audio.music.stream.loop and audio.music.stream.get_length()>0)
	var world: Node3D=load("res://Main.tscn").instantiate();root.add_child(world)
	for i in range(8): await process_frame
	world.set_menu_open(true);world.hud._show_page("Audio")
	for i in range(8): await process_frame
	check("audio page exposes all three sliders",world.hud.audio_controls.visible and world.hud.audio_controls.get_child_count()==7)
	world.hud.audio_controls.get_child(3).value=17
	check("music slider changes mixer",is_equal_approx(audio.levels.Music,.17))
	world.hud._show_page("home")
	check("audio sliders hide on pause root",not world.hud.audio_controls.visible and world.hud.developer.entry_button.visible)
	var saved: Dictionary=world.orchestrator.snapshot()
	var count: int=audio.played.get("step",0)
	audio.walk(.1,0,true);audio.walk(.1,1,false)
	check("idle and airborne movement produce no steps",audio.played.get("step",0)==count)
	audio.walk(.1,.2,true)
	check("ground movement produces a step",audio.played.get("step",0)==count+1)
	for sound: String in audio.sounds: audio.play(sound)
	check("audio never awards game progress",world.orchestrator.snapshot()==saved)
	for bus: String in original: audio.set_volume(bus,original[bus])
	audio.save_timer.stop()
	world.queue_free();await process_frame
	print("AUDIO_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
