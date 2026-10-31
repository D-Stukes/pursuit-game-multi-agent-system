extends SceneTree
## Bakes the walkable floor for ambient people from the building's static collision.
## Run after the building model changes:
##   godot --headless --path godot --script res://developer/bake_npc_navigation.gd
## The entrance is baked open; NPCLife decides when people may actually use it.
const OUTPUT := "res://assets/characters/npc-navigation.tres"

static func settings() -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1|2|4
	mesh.agent_radius = .3
	mesh.agent_height = 1.7
	mesh.agent_max_climb = .3
	mesh.agent_max_slope = 35
	mesh.cell_size = .1
	mesh.cell_height = .05
	mesh.filter_baking_aabb = AABB(Vector3(-24,-.5,-18),Vector3(34,7,26))
	return mesh

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://Main.tscn").instantiate()
	world.include_population = false
	root.add_child(world)
	for _i: int in range(12): await physics_frame
	world.entrance_gate.collision_layer = 0
	world.entrance_doors.set_open(true)
	for _i: int in range(90): await physics_frame
	var mesh: NavigationMesh = settings()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, world)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	assert(mesh.get_polygon_count() > 200, "Navigation bake produced too few polygons")
	var error: Error = ResourceSaver.save(mesh, OUTPUT)
	print("NPC_NAVIGATION polygons=", mesh.get_polygon_count(), " saved=", error == OK)
	world.queue_free()
	quit(0 if error == OK else 1)
