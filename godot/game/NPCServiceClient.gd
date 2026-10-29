extends Node
## Explicit opt-in loopback transport. API keys never enter the game process.
signal completed(request_id: String, result: Dictionary)
signal failed(request_id: String, reason: String)
var provider: String = "local"
var base_url: String = "http://127.0.0.1:8765"
var timeout_seconds: float = 8.0
var active_id: String = ""
var active_body: Dictionary = {}
var request: HTTPRequest

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--npc-provider=claude": provider = "claude"
		elif arg.begins_with("--npc-agent-url="): base_url = arg.trim_prefix("--npc-agent-url=")

func valid_url() -> bool:
	var pattern := RegEx.new()
	pattern.compile("^http://(127\\.0\\.0\\.1|localhost):([0-9]{1,5})$")
	var matched: RegExMatch = pattern.search(base_url)
	return matched != null and matched.get_string(2).to_int() >= 1024 and matched.get_string(2).to_int() <= 65535

func start(body: Dictionary) -> Error:
	if provider != "claude": return ERR_UNCONFIGURED
	if not valid_url(): return ERR_INVALID_PARAMETER
	if not active_id.is_empty(): return ERR_BUSY
	active_id = body.request_id
	active_body = body.duplicate(true)
	# A fresh node binds each callback to its request ID, including cancellation.
	request = HTTPRequest.new()
	request.timeout = timeout_seconds
	request.body_size_limit = 16384
	request.max_redirects = 0
	add_child(request)
	request.request_completed.connect(_received.bind(active_id))
	var error: Error = request.request(base_url+"/v1/npc/turn",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(body))
	if error != OK: cancel()
	return error

func cancel() -> void:
	active_id = ""
	active_body = {}
	if is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	request = null

func _received(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray, token: String) -> void:
	if token != active_id or active_id.is_empty(): return
	var expected: Dictionary = active_body.duplicate(true)
	cancel()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		failed.emit(token,"service_unavailable")
		return
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		failed.emit(token,"invalid_response")
		return
	if parsed.get("schema") != expected.schema or parsed.get("request_id") != token or parsed.get("npc_id") != expected.npc_id or parsed.get("topic") != expected.topic or parsed.get("mode") != "claude":
		failed.emit(token,"invalid_response")
		return
	if not parsed.get("text") is String or parsed.text.strip_edges().is_empty() or parsed.text.length() > 600:
		failed.emit(token,"invalid_response")
		return
	completed.emit(token,parsed)
