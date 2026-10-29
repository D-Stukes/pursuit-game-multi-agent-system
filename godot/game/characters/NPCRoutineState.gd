extends RefCounted
## Session-local authored routine. No provider, navigation service or game awards.
var valid: bool = false
var started: bool = false
var talking: bool = false
var phase: String = "idle"
var waypoints: Array[Vector3] = []
var index: int = 0
var remaining: float = 0
var arrivals: int = 0
var conversations: int = 0
var speed: float = 1.2
var wait_seconds: float = 3
var activity: String = "Interact"

func _init(config: Dictionary, home: Vector3) -> void:
	if not home.is_finite() or config.size()!=4: return
	var offsets: Variant = config.get("offsets")
	if not offsets is Array or offsets.size()<2 or offsets.size()>8: return
	for field: String in ["speed","wait_seconds"]:
		var number: Variant = config.get(field)
		if not (number is int or number is float) or not is_finite(float(number)): return
	if config.speed<.3 or config.speed>4.2 or config.wait_seconds<1 or config.wait_seconds>8 or config.get("activity") not in ["Idle_Neutral","Wave","Interact"]: return
	var points: Array[Vector3] = []
	for offset: Variant in offsets:
		if not offset is Array or offset.size()!=3: return
		for number: Variant in offset:
			if not (number is int or number is float) or not is_finite(float(number)): return
		var relative := Vector3(offset[0],offset[1],offset[2])
		# Local routes are horizontal; supporting-floor validation owns height.
		if relative.length()>4 or relative.y!=0: return
		points.append(home+relative)
	if points.all(func(point: Vector3):return point.distance_to(home)<.08): return
	waypoints = points;speed=config.speed;wait_seconds=config.wait_seconds;activity=config.activity
	valid = true

func begin_conversation() -> void: talking = true

func end_conversation() -> void:
	talking = false
	if not valid: return
	conversations += 1
	if not started: started=true;phase="walk"

func decide(position: Vector3, delta: float, allowed: bool) -> Dictionary:
	var idle: Dictionary = {"target":position,"speed":0.0,"animation":"Idle_Neutral"}
	if not valid or not started or talking or not allowed: return idle
	if phase=="activity":
		remaining=maxf(0,remaining-delta)
		if remaining>0: return {"target":position,"speed":0.0,"animation":activity}
		phase="walk"
	if position.distance_to(waypoints[index])<.08:
		arrivals+=1;index=(index+1)%waypoints.size();phase="activity";remaining=wait_seconds
		return {"target":position,"speed":0.0,"animation":activity}
	return {"target":waypoints[index],"speed":speed,"animation":"Run" if speed>2.8 else "Walk"}
