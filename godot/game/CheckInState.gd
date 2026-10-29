extends RefCounted
## Temporary form evidence. Only the Orchestrator publishes a confirmed arrival.
enum Phase { NAME, NAMED, PHOTO, CONFIRMED }
const MAX_NAME: int = 32
var phase: Phase = Phase.NAME
var display_name: String = ""

static func valid_name(value: String) -> bool:
	var clean: String = value.strip_edges()
	if clean.is_empty() or clean.length() > MAX_NAME: return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159): return false
	return true

func start_photo(value: String) -> bool:
	if phase == Phase.CONFIRMED or not valid_name(value): return false
	display_name = value.strip_edges()
	phase = Phase.NAMED
	return true

func take_photo() -> bool:
	if phase != Phase.NAMED: return false
	phase = Phase.PHOTO
	return true

func confirm() -> bool:
	if phase != Phase.PHOTO or not valid_name(display_name): return false
	phase = Phase.CONFIRMED
	return true

func completed() -> bool:
	return phase == Phase.CONFIRMED and valid_name(display_name)

func cancel(keep_confirmed: bool = false) -> void:
	if keep_confirmed and completed(): return
	phase = Phase.NAME
	display_name = ""
