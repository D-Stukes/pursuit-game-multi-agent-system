extends RefCounted
## Supplies movement only. Reads visible drones, lane warnings and active beams.
static func direction(state: RefCounted) -> Vector2:
 var target: float=state.ship.x
 if not state.enemies.is_empty():
  var enemy: Dictionary=state.enemies[0]
  target=enemy.home.x+sin((state.clock+(state.ship.y-enemy.at.y)/state.SHOT_SPEED)*state.movement_frequency()+enemy.offset)*105
 var result:=Vector2(clampf((target-state.ship.x)/8,-1,1),0)
 # React to visible approaching projectiles; lane avoidance takes priority.
 for hazard: Dictionary in state.hazards:
  if not hazard.get("lane",false):
   var approaching: Vector2=hazard.at+hazard.velocity*.2
   if approaching.distance_to(state.ship)<70:result.y=-1 if approaching.y>state.ship.y else 1
 for threats: Array in [state.warnings,state.hazards]:
  for threat: Dictionary in threats:
   if threat.get("lane",false) and absf(threat.at.y-state.ship.y)<65:
    result.y=-1 if threat.at.y>423 else 1
 return result
