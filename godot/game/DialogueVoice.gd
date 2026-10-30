extends Node
## Local system TTS for the student's selected line. No provider/network request.
signal finished(id: int)
var active_id: int=0
var serial: int=0
var voice: String=""
var last_text: String=""
var native_starts: int=0
var native_ends: int=0
func _ready() -> void:
 GamePreferences.changed.connect(_preferences_changed)
 GameAudio.volume_changed.connect(_volume_changed)
 if DisplayServer.get_name()=="headless":return
 DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED,_started)
 DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED,_ended)
 DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED,_ended)
 _select_voice()
func _select_voice() -> void:
 for entry: Dictionary in DisplayServer.tts_get_voices():
  if str(entry.language).begins_with("en"):
   voice=str(entry.id)
   if str(entry.name) in ["Samantha","Aria","Microsoft Aria Desktop"]:break
func speak(text: String) -> int:
 stop()
 last_text=text
 if not GamePreferences.speak_choices or DisplayServer.get_name()=="headless" or float(GameAudio.levels.Master)*float(GameAudio.levels.Effects)<=0:return 0
 if voice.is_empty():_select_voice()
 if voice.is_empty():return 0
 serial+=1;active_id=serial;GameAudio.set_voice_active(true)
 DisplayServer.tts_speak(text,voice,maxi(1,int(100*float(GameAudio.levels.Master)*float(GameAudio.levels.Effects))),1.0,.95,active_id,true)
 return active_id
func _started(_id: int) -> void:
 native_starts+=1
func _ended(id: int) -> void:
 native_ends+=1
 if id!=active_id:return
 active_id=0;GameAudio.set_voice_active(false);finished.emit(id)
func stop() -> void:
 var previous: int=active_id
 active_id=0
 if DisplayServer.get_name()!="headless":DisplayServer.tts_stop()
 GameAudio.set_voice_active(false)
 if previous!=0:finished.emit(previous)
func _preferences_changed() -> void:
 if not GamePreferences.speak_choices:stop()
func _volume_changed() -> void:
 if float(GameAudio.levels.Master)*float(GameAudio.levels.Effects)<=0:stop()
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:stop()

func _exit_tree() -> void:
 stop()
 if DisplayServer.get_name()!="headless":
  for event: int in [DisplayServer.TTS_UTTERANCE_STARTED,DisplayServer.TTS_UTTERANCE_ENDED,DisplayServer.TTS_UTTERANCE_CANCELED]:
   DisplayServer.tts_set_utterance_callback(event,Callable())
