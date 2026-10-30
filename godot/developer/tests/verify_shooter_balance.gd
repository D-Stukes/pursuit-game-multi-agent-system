extends SceneTree
const Rules=preload("res://game/ElevatorShooterState.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var report: Dictionary={"trials_per_policy":30,"limit_seconds":120,"step_hz":60,"policies":{},"note":"Input-only automated pilots; not human win-rate estimates."}
 for policy: String in ["idle","stationary_fire","sweep_fire","wide_sweep_fire","track_fire","predictive_fire","adaptive_fire"]:
  var wins: int=0;var times: Array[float]=[];var losses: Array[int]=[];var remaining: Array[int]=[];var reached: Array[int]=[];var by_wave: Array[int]=[0,0,0]
  for seed_id in range(30):
   var state: RefCounted=Rules.new();state.rng.seed=seed_id+100;state.start()
   var sweep_sign: float=1
   for tick in range(7200):
    if state.phase in ["won","lost"]:break
    var direction:=Vector2.ZERO
    if policy in ["sweep_fire","wide_sweep_fire"]:
     if state.ship.x>(940 if policy=="wide_sweep_fire" else 870):sweep_sign=-1
     if state.ship.x<(60 if policy=="wide_sweep_fire" else 130):sweep_sign=1
     direction.x=sweep_sign
    elif policy in ["track_fire","predictive_fire","adaptive_fire"] and not state.enemies.is_empty():
     var enemy: Dictionary=state.enemies[0]
     var target: float=enemy.at.x
     if policy in ["predictive_fire","adaptive_fire"]:target=enemy.home.x+sin((state.clock+(state.ship.y-enemy.at.y)/Rules.SHOT_SPEED)*state.movement_frequency()+enemy.offset)*105
     direction.x=clampf((target-state.ship.x)/8,-1,1)
    if policy=="adaptive_fire":direction=preload("res://developer/tests/ShooterTestPilot.gd").direction(state)
    var previous: int=state.shields;var wave: int=state.wave
    state.step(1.0/60,direction,policy!="idle")
    by_wave[wave-1]+=previous-state.shields
   if state.completed():wins+=1
   times.append(state.clock);remaining.append(state.shields);reached.append(state.wave);losses.append(3-state.shields)
  times.sort();var total: float=0
  for time: float in times:total+=time
  report.policies[policy]={"wins":wins,"trials":30,"median_seconds":snappedf(times[15],.1),"mean_seconds":snappedf(total/30,.1),"min_seconds":snappedf(times[0],.1),"max_seconds":snappedf(times[-1],.1),"damage_by_wave":by_wave,"mean_shields_left":remaining.reduce(func(a: float,b: int):return a+b,0.0)/30,"reached_wave_3":reached.count(3)}
  print("BALANCE_POLICY ",policy," ",JSON.stringify(report.policies[policy]))
 var output: String="res://.godot/shooter-balance-review.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 var sweep: Dictionary=report.policies.sweep_fire
 var adaptive: Dictionary=report.policies.adaptive_fire
 var failures: int=0
 for result: Dictionary in [{"name":"old sweep no longer wins","ok":sweep.wins==0},{"name":"first wave remains damage-free for sweep","ok":sweep.damage_by_wave[0]==0},{"name":"responsive pilot wins at least 27 of 30","ok":adaptive.wins>=27}]:
  print("PASS " if result.ok else "FAIL ",result.name)
  if not result.ok:failures+=1
 print("BALANCE_REVIEW_RESULT checks=3 failures=",failures)
 quit(0 if failures==0 else 1)
