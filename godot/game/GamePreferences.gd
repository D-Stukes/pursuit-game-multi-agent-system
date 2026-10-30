extends Node
## Device presentation preferences. Never grants game progress.
signal changed
const PATH: String="user://presentation-settings.cfg"
var settings_path: String=PATH
var intro_seen: bool=false
var reduced_motion: bool=false
var speak_choices: bool=true
var extra_hints: bool=false
func _ready() -> void:
 var settings:=ConfigFile.new()
 if settings.load(settings_path)==OK:
  intro_seen=bool(settings.get_value("intro","seen",false))
  reduced_motion=bool(settings.get_value("accessibility","reduced_motion",false))
  speak_choices=bool(settings.get_value("audio","speak_choices",true))
  extra_hints=bool(settings.get_value("navigation","extra_hints",false))
func save() -> void:
 var settings:=ConfigFile.new()
 settings.set_value("intro","seen",intro_seen)
 settings.set_value("accessibility","reduced_motion",reduced_motion)
 settings.set_value("audio","speak_choices",speak_choices)
 settings.set_value("navigation","extra_hints",extra_hints)
 settings.save(settings_path)
func mark_intro_seen() -> void:
 intro_seen=true;save()
func set_reduced_motion(value: bool) -> void:
 reduced_motion=value;save();changed.emit()
func set_speak_choices(value: bool) -> void:
 speak_choices=value;save();changed.emit()

func set_extra_hints(value: bool) -> void:
 extra_hints=value;save();changed.emit()
