extends SceneTree
const Rules=preload("res://game/ElevatorShooterState.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(label: String, ok: bool) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func setup(wave: int) -> RefCounted:
 var state: RefCounted=Rules.new();state.rng.seed=42;state.start()
 if wave>1:state.wave=wave-1;state._spawn_wave()
 return state
func lanes(items: Array) -> Array:
 return items.filter(func(item: Dictionary):return item.get("lane",false))
func run() -> void:
 var first: RefCounted=setup(1)
 for tick in range(120):first.step(1.0/60,Vector2.ZERO,false)
 check("wave one keeps five drones, 170 speed and no lane attacks",first.enemies.size()==5 and first.movement_frequency()==.95 and lanes(first.warnings).is_empty() and lanes(first.hazards).is_empty() and first.hazards.all(func(h: Dictionary):return is_equal_approx(h.velocity.length(),170)))
 for wave in [2,3]:
  var state: RefCounted=setup(wave);state.lane_delay=0;state.fire_delay=10
  state.step(.01,Vector2.ZERO,false)
  check("lane is warned without immediate damage wave "+str(wave),lanes(state.warnings).size()==1 and lanes(state.hazards).is_empty() and state.shields==3)
  var warning: Dictionary=lanes(state.warnings)[0]
  var row: float=warning.at.y
  check("lane gives 0.9 seconds of warning wave "+str(wave),is_equal_approx(warning.delay,.9))
  state.paused=true;state.step(.05,Vector2.UP,false)
  check("pause freezes warning wave "+str(wave),is_equal_approx(warning.delay,.9) and state.ship.y==row)
  state.paused=false
  for tick in range(12):state.step(.05,Vector2.UP,false)
  check("warning stays on original row as player moves wave "+str(wave),warning.at.y==row and absf(state.ship.y-row)>65)
  for tick in range(7):state.step(.05,Vector2.ZERO,false)
  check("vertical dodge avoids active beam wave "+str(wave),state.shields==3 and lanes(state.hazards).size()==1)
  state.paused=true
  var life: float=lanes(state.hazards)[0].life;state.step(.05,Vector2.ZERO,false)
  check("pause freezes active beam wave "+str(wave),is_equal_approx(lanes(state.hazards)[0].life,life))
  state.paused=false
  for tick in range(5):state.step(.05,Vector2.ZERO,false)
  check("beam expires after brief active window wave "+str(wave),lanes(state.hazards).is_empty())
  state=setup(wave);state.fire_delay=10;state.lane_delay=0;state.step(.01,Vector2.ZERO,false)
  for tick in range(19):state.step(.05,Vector2.RIGHT,false)
  check("sideways movement alone cannot dodge marked row wave "+str(wave),state.shields==2)
  for tick in range(5):state.step(.05,Vector2.ZERO,false)
  check("one beam cannot consume multiple shields wave "+str(wave),state.shields==2)
  state.phase="lost";state.start()
  check("retry clears lanes and starts manageable first wave "+str(wave),state.wave==1 and state.shields==3 and state.warnings.is_empty() and state.hazards.is_empty())
 var second: RefCounted=setup(2);var third: RefCounted=setup(3)
 second.lane_delay=0;third.lane_delay=0;second.step(.01,Vector2.ZERO,false);third.step(.01,Vector2.ZERO,false)
 check("wave three lanes have a shorter interval than wave two",third.lane_delay<second.lane_delay and third.lane_delay>Rules.LANE_WARNING+Rules.LANE_DURATION)
 second.hazards.append({"at":Vector2(24,480),"velocity":Vector2.ZERO,"lane":true,"life":.2})
 second.enemies.clear();second.step(.01,Vector2.ZERO,false)
 check("wave completion clears all pending and active threats",second.phase=="between" and second.warnings.is_empty() and second.hazards.is_empty())
 print("SHOOTER_LANES_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
