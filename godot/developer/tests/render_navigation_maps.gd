extends SceneTree
## Off-screen floor renders share the live map's projection and cover the full street.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var MapView: GDScript=load("res://game/BuildingMap.gd")
 var viewport:=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var world:=Node3D.new();viewport.add_child(world)
 var building: Node3D=load("res://assets/generated/pursuit-building.glb").instantiate();world.add_child(building)
 preload("res://game/EnvironmentLighting.gd").setup(world)
 var env: WorldEnvironment=world.find_children("*","WorldEnvironment",true,false)[0]
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("eef0f2");env.environment.fog_enabled=false
 var doors:=Node3D.new();doors.set_script(load("res://game/EntranceDoors.gd"));world.add_child(doors);doors.configure(building)
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=MapView.WIDTH
 var floors: Dictionary={}
 for floor_id: int in [0,1]:
  var level: float=0.0 if floor_id==0 else 5.05
  var center: Vector2=MapView.GROUND_CENTER if floor_id==0 else MapView.CENTER
  var depth: float=MapView.GROUND_DEPTH if floor_id==0 else MapView.DEPTH
  viewport.size=Vector2i(1300,roundi(depth*25))
  camera.look_at_from_position(Vector3(center.x,45,-center.y),Vector3(center.x,level,-center.y),Vector3.FORWARD)
  for mesh: MeshInstance3D in building.find_children("*","MeshInstance3D",true,false):
   var bounds: AABB=mesh.global_transform*mesh.get_aabb()
   var module: String=str(mesh.get_meta("extras",{}).get("module_id",""))
   mesh.visible=not (bounds.position.y>level+2.05 or bounds.end.y<level-.25 or module.begins_with("Exterior") or (module=="Streetscape" and floor_id==1))
  doors.visible=floor_id==0
  for i in range(12):await process_frame
  RenderingServer.force_draw(false)
  var id: String="ground" if floor_id==0 else "upper"
  var path: String="res://assets/maps/"+id+".png"
  viewport.get_texture().get_image().save_png(path)
  floors[id]={"texture_size":[viewport.size.x,viewport.size.y],"center":[center.x,center.y],"width":MapView.WIDTH,"depth":depth,"level":level}
  print("MAP_RENDERED ",path)
 var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/provenance.json"))
 record.erase("texture_size");record.erase("world_bounds");record.projection="Orthographic KEEP_WIDTH; Godot [x,height,-depth]; top of image is rear of building";record.floors=floors
 record.source_sha256=FileAccess.get_sha256("res://assets/generated/pursuit-building.glb")
 record.texture_sha256={"ground.png":FileAccess.get_sha256("res://assets/maps/ground.png"),"upper.png":FileAccess.get_sha256("res://assets/maps/upper.png")}
 var receipt:=FileAccess.open("res://assets/maps/provenance.json",FileAccess.WRITE);receipt.store_string(JSON.stringify(record,"  ")+"\n");receipt.close()
 viewport.queue_free();await process_frame;quit()
