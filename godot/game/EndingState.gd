extends RefCounted
## Ordered local presentation evidence, separate from course completion.
const PHASES: Array[String]=["fade_out","placement","fade_in","results","assessment","celebration","complete"]
const DEFAULT_SECONDS: Dictionary={"fade_out":.35,"fade_in":.35,"results":3.0,"assessment":3.0,"celebration":3.5}
var seconds: Dictionary=DEFAULT_SECONDS.duplicate()
var phase: String="idle"
var elapsed: float=0
var preview: bool=false
var session: String=""
var nonce: String=""
var results: Dictionary={}
var error: String=""
var _placed: bool=false

func _init(timing: Dictionary={}) -> void:
	for key: String in timing:
		if not seconds.has(key) or not (timing[key] is float or timing[key] is int) or not is_finite(float(timing[key])) or float(timing[key])<.05 or float(timing[key])>30:
			error="invalid_timing";return
		seconds[key]=float(timing[key])

func start(id: String, token: String, snapshot: Dictionary, is_preview: bool) -> bool:
	if not error.is_empty() or phase!="idle" or id.is_empty() or token.is_empty(): return false
	session=id;nonce=token;results=snapshot.duplicate(true);preview=is_preview
	phase="fade_out";elapsed=0;_placed=false
	return true

func step(delta: float, paused: bool=false) -> void:
	if paused or not seconds.has(phase) or not is_finite(delta) or delta<=0: return
	elapsed+=minf(delta,.1)
	if elapsed>=float(seconds[phase]):
		phase=PHASES[PHASES.find(phase)+1];elapsed=0

func placed(safe: bool) -> bool:
	if phase!="placement": return false
	if not safe: phase="error";return false
	_placed=true;phase="fade_in";elapsed=0
	return true

func cancel() -> void:
	phase="cancelled";nonce=""

func completed(id: String, token: String) -> bool:
	return not preview and _placed and phase=="complete" and id==session and not token.is_empty() and token==nonce
