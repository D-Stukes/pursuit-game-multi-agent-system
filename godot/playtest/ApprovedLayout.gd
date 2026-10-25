extends RefCounted
## Runtime assembly of the approved plan. Source GLB remains the retained library.
## Bounds use Blender's (x, depth, height), converted once to Godot (x, height, -depth).

const SOURCE_PATH: String = "res://playtest/layout_source.json"
const FLOOR: float = 5.05
const TOP: float = 8.85
const CLASSROOM := Rect2(-15.0, -4.6, 19.32, 9.96)
const GROUND_LEFT := Rect2(-22.0, 3.0, 15.8, 12.18)
const RECEPTION := Rect2(-1.2, 5.56, 6.4, 3.24)
const SMALL_ROOMS: Array[Rect2] = [Rect2(-6.2,7.0,2.3,1.8), Rect2(-3.7,7.0,2.3,1.8)]
var root: Node3D
var materials: Dictionary = {}
var boxes: Dictionary = {}
var retained: Dictionary = {}
var missing: Array[String] = []
var original_transforms: Dictionary = {}
var source_glass: Material

func key(value: String) -> String:
	var result := value.to_lower()
	for token: String in [" ","_","|",".","-",":","/","(",")"]:
		result = result.replace(token, "")
	return result

func apply(building: Node3D) -> void:
	var wanted: Dictionary = {}
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
	for entry: Dictionary in source["meshes"]:
		wanted[key(entry["name"])] = entry
	var found: Dictionary = {}
	for mesh: MeshInstance3D in building.find_children("*", "MeshInstance3D", true, false):
		var id := key(String(mesh.name))
		if not wanted.has(id):
			mesh.free()
			continue
		var entry: Dictionary = wanted[id]
		if String(entry["name"]).contains("clear glass"):
			source_glass = mesh.get_active_material(0)
		found[id] = true
		var kind: String = entry["kind"]
		retained[kind] = int(retained.get(kind, 0)) + 1
		if kind in ["ground","bank"]:
			original_transforms[String(mesh.name)] = mesh.global_transform
		var delta: Array = entry["delta"]
		mesh.global_position += Vector3(delta[0], delta[2], -float(delta[1]))
		mesh.set_meta("layout_source_kind", kind)
	for id: String in wanted:
		if not found.has(id):
			missing.append(wanted[id]["name"])
	assert(missing.is_empty(), "Missing source meshes: " + str(missing))
	root = Node3D.new()
	root.name = "ApprovedLayout"
	building.add_child(root)
	_ground()
	_upper()
	print("APPROVED_LAYOUT retained=",retained," missing=",missing.size())

func material(color: Color) -> StandardMaterial3D:
	var id := color.to_html()
	if not materials.has(id):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = .92
		materials[id] = m
	return materials[id]

func box(label: String, lo: Vector3, hi: Vector3, color: Color = Color(.88,.89,.87)) -> MeshInstance3D:
	var size := Vector3(hi.x-lo.x, hi.z-lo.z, hi.y-lo.y)
	assert(size.x > 0 and size.y > 0 and size.z > 0, label)
	if not boxes.has(size):
		var shape := BoxMesh.new()
		shape.size = size
		boxes[size] = shape
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = boxes[size]
	mesh.material_override = material(color)
	root.add_child(mesh)
	var center := (lo+hi)*.5
	mesh.position = Vector3(center.x,center.z,-center.y)
	return mesh

func slab(label: String, bounds: Rect2, height: float, color: Color) -> void:
	box(label,Vector3(bounds.position.x,bounds.position.y,height-.16),Vector3(bounds.end.x,bounds.end.y,height),color)

func glass_box(label: String, lo: Vector3, hi: Vector3) -> void:
	var mesh := box(label,lo,hi)
	assert(source_glass != null, "Retained glazing material is missing")
	mesh.material_override = source_glass

func wall_x(label: String, x: float, a: float, b: float, floor_height: float, door_a: float = INF, door_b: float = INF) -> void:
	var ceiling: float = 3.8 if floor_height < 1 else TOP
	if door_a == INF:
		box(label,Vector3(x-.08,a,floor_height),Vector3(x+.08,b,ceiling))
	else:
		if door_a > a:
			box(label+" A",Vector3(x-.08,a,floor_height),Vector3(x+.08,door_a,ceiling))
		if b > door_b:
			box(label+" B",Vector3(x-.08,door_b,floor_height),Vector3(x+.08,b,ceiling))
		box(label+" header",Vector3(x-.08,door_a,floor_height+2.5),Vector3(x+.08,door_b,ceiling))

func wall_y(label: String, y: float, a: float, b: float, floor_height: float, door_a: float = INF, door_b: float = INF) -> void:
	var ceiling: float = 3.8 if floor_height < 1 else TOP
	if door_a == INF:
		box(label,Vector3(a,y-.08,floor_height),Vector3(b,y+.08,ceiling))
	else:
		if door_a > a:
			box(label+" A",Vector3(a,y-.08,floor_height),Vector3(door_a,y+.08,ceiling))
		if b > door_b:
			box(label+" B",Vector3(door_b,y-.08,floor_height),Vector3(b,y+.08,ceiling))
		box(label+" header",Vector3(door_a,y-.08,floor_height+2.5),Vector3(door_b,y+.08,ceiling))

func sign_text(label: String, at: Vector3, yaw: float = PI) -> void:
	var sign_node := Label3D.new()
	sign_node.name = label+" sign"
	sign_node.text = label
	sign_node.font_size = 48
	sign_node.pixel_size = .005
	sign_node.double_sided = false
	sign_node.modulate = Color(.1,.16,.23)
	root.add_child(sign_node)
	sign_node.position = Vector3(at.x,at.z,-at.y)
	sign_node.rotation.y = yaw

func light_strip(x: float, y: float, ceiling: float) -> void:
	box("Ceiling strip",Vector3(x-.65,y-.09,ceiling-.12),Vector3(x+.65,y+.09,ceiling-.06),Color(.98,.98,.9))

func open_leaf(label: String, hinge_x: float, depth: float, inward: float = 1.0) -> void:
	var end: float = depth+inward*.95
	box(label,Vector3(hinge_x-.035,minf(depth,end),FLOOR),Vector3(hinge_x+.035,maxf(depth,end),FLOOR+2.42),Color(.91,.92,.9))
	box(label+" handle",Vector3(hinge_x-.07,end-.05,FLOOR+1.05),Vector3(hinge_x-.035,end+.05,FLOOR+1.13),Color(.17,.21,.24))

func _ground() -> void:
	# One original entrance; no front annex or extra pair of street doors.
	slab("Original entrance sidewalk",Rect2(-11.8,-8.3,23.6,3.55),0,Color(.64,.64,.59))
	slab("Ground foundation",Rect2(-24,-4.75,44,22.15),-.02,Color(.54,.55,.53))
	slab("Left ground room floor",GROUND_LEFT,.85,Color(.55,.56,.53))
	slab("Raised ground core",Rect2(-6.2,6.24,9.56,11.16),.84,Color(.55,.56,.53))
	slab("Right ground room floor",Rect2(3.36,-4.75,16.56,22.15),.85,Color(.55,.56,.53))
	# Explicit threshold finishes bridge both slab joins, including exact-edge rays.
	slab("Left room threshold",Rect2(-6.45,7.55,.6,1.65),.852,Color(.55,.56,.53))
	slab("Right room threshold",Rect2(3.08,7.55,.4,1.65),.852,Color(.55,.56,.53))
	# Supporting side wings close outside the accepted stair/ramp/core envelope.
	wall_x("Ground west perimeter",-24,-4.75,17.4,0)
	wall_x("Ground east perimeter",20,-4.75,17.4,0)
	wall_y("Ground rear perimeter",17.4,-24,20,0)
	wall_y("Ground left frontage",-4.75,-24,-3.36,0)
	wall_y("Ground right frontage",-4.75,3.36,20,0)
	# Original ground face/glazed entry, stairs, yellow doors, ramp and banks remain.
	wall_x("Left room west",-22,3,15.18,.85)
	wall_y("Left room front",3,-22,-6.2,.85)
	wall_y("Left room back",15.18,-22,-6.2,.85)
	wall_x("Brown L west and left room entry",-6.1,3,16.8,.85,7.55,9.2)
	wall_y("Brown L back",16.8,-6.1,-2.48,.85)
	wall_x("Right room entry from forecourt",3.28,6.3,16.8,.85,7.55,9.2)
	box("Ground side wing ceiling west",Vector3(-24,-4.75,3.8),Vector3(-3.4,17.4,4.85))
	box("Ground side wing ceiling east",Vector3(3.4,-4.75,3.8),Vector3(20,17.4,4.85))
	for x: float in [-19,-14,-9,8,13,18]:
		for y: float in [4.5,10.0,14.0]:
			light_strip(x,y,3.8)
	sign_text("ROOM",Vector3(-6.0,9.6,3.0),PI/2)
	sign_text("ROOM",Vector3(3.18,9.6,3.0),-PI/2)

func _upper() -> void:
	# Tile around the retained cab floor rectangles, avoiding coplanar faces.
	for area: Rect2 in [Rect2(-24,-4.75,21.72,22.15),Rect2(0,-4.75,20,22.15),Rect2(-2.28,-4.75,2.28,15.95),Rect2(-2.28,13,2.28,1.2),Rect2(-2.28,16,2.28,1.4)]:
		slab("Upper continuous floor",area,FLOOR,Color(.49,.5,.48))
	slab("Classroom carpet",CLASSROOM,FLOOR+.008,Color(.24,.27,.29))
	slab("Reception finish",RECEPTION,FLOOR+.008,Color(.6,.61,.58))
	box("Upper ceiling",Vector3(-24,-4.75,TOP),Vector3(20,17.4,TOP+.16))
	wall_x("Upper west perimeter",-24,-4.75,17.4,FLOOR)
	wall_x("Upper east perimeter",20,-4.75,17.4,FLOOR)
	wall_y("Upper rear perimeter",17.4,-24,20,FLOOR)
	# Front window bays stay behind the one street boundary.
	box("Front sill",Vector3(-24,-4.75,FLOOR),Vector3(20,-4.59,5.95))
	box("Front window head",Vector3(-24,-4.75,8.1),Vector3(20,-4.59,TOP))
	glass_box("Front glazing",Vector3(-24,-4.71,5.95),Vector3(20,-4.68,8.1))
	for x in range(-24,21,2):
		box("Window mullion",Vector3(x-.035,-4.76,5.9),Vector3(x+.035,-4.58,8.15),Color(.27,.33,.35))
	# Classroom and reception share exactly one original glass double-door pair.
	wall_x("Classroom west",-15.1,-4.75,5.46,FLOOR)
	wall_x("Classroom east",4.42,-4.75,5.46,FLOOR)
	wall_y("Classroom north shared wall",5.46,-15.1,4.42,FLOOR,-.9,1.66)
	wall_x("Reception open hall return",-1.3,5.56,8.8,FLOOR,5.56,8.8)
	wall_x("Reception separate room door",5.3,5.56,8.8,FLOOR,7.15,8.65)
	# Open opaque leaf sits against the wall; no collision across the threshold.
	box("Separate room open white leaf",Vector3(5.4,8.64,FLOOR),Vector3(6.7,8.7,7.5),Color(.91,.92,.9))
	box("Reception front header",Vector3(-1.3,8.82,7.9),Vector3(5.3,8.98,TOP))
	for x: float in [-1.3,1.4,3.94,5.3]:
		box("Reception front jamb",Vector3(x-.04,8.80,FLOOR),Vector3(x+.04,8.98,7.9),Color(.44,.48,.48))
	# Cover the solid front panels in matching blue glazing, with a clear doorway.
	for pair: Vector2 in [Vector2(-1.3,1.4),Vector2(3.94,5.3)]:
		box("Reception front sill",Vector3(pair.x,8.82,FLOOR),Vector3(pair.y,8.98,5.95))
		glass_box("Reception glazing",Vector3(pair.x,8.80,5.95),Vector3(pair.y,8.82,7.6))
	# The closed white opposite door stays straight ahead out of the lift.
	wall_x("Other room west",4.94,9.0,17.4,FLOOR,11.55,12.65)
	box("Other room closed opaque white door",Vector3(4.86,11.55,FLOOR),Vector3(4.93,12.65,7.55),Color(.94,.94,.91))
	wall_y("Other room front",9.0,4.94,20,FLOOR)
	# Hallway 1 ends at the bathrooms; the open area begins to its west.
	wall_x("Bathroom west",-6.2,11.2,17.4,FLOOR)
	wall_x("Bathroom east",-2.5,11.2,17.4,FLOOR)
	wall_x("Bathroom divider",-4.35,11.2,17.4,FLOOR)
	wall_y("Bathroom 1 door wall",11.2,-6.2,-4.35,FLOOR,-5.88,-4.88)
	wall_y("Bathroom 2 door wall",11.2,-4.35,-2.5,FLOOR,-4.02,-3.02)
	open_leaf("Bathroom 1 open door",-5.88,11.3)
	open_leaf("Bathroom 2 open door",-4.02,11.3)
	# No wall or door between the west open area and Hallway 2.
	wall_x("Hallway 1 end",-6.2,8.8,11.2,FLOOR)
	for i in range(SMALL_ROOMS.size()):
		var room: Rect2 = SMALL_ROOMS[i]
		slab("Hall room floor "+str(i+1),room,FLOOR+.008,Color(.64,.61,.55))
		wall_x("Hall room west "+str(i+1),room.position.x,room.position.y,room.end.y,FLOOR)
		wall_x("Hall room east "+str(i+1),room.end.x,room.position.y,room.end.y,FLOOR)
		wall_y("Hall room back "+str(i+1),room.end.y,room.position.x,room.end.x,FLOOR)
		var center: float = room.get_center().x
		wall_y("Hall room door "+str(i+1),room.position.y,room.position.x,room.end.x,FLOOR,center-.5,center+.5)
		open_leaf("Hall room open door "+str(i+1),center-.5,room.position.y+.1)
		sign_text("ROOM "+str(i+1),Vector3(center,room.position.y-.09,7.8),0)
	# Additional room between classroom and the separate room, reaching the facade.
	wall_x("Additional room east",6.9,-4.75,5.46,FLOOR)
	wall_y("Additional room entry",5.46,4.42,6.9,FLOOR,5.1,6.2)
	open_leaf("Additional room open door",5.1,5.36,-1)
	wall_y("Separate room rear",8.9,5.3,20,FLOOR)
	for x: float in [-21,-16,-11,-7,-2,3,8,13,18]:
		for y: float in [-2.5,2.5,7.5,12.5,16]:
			light_strip(x,y,TOP)
	sign_text("RECEPTION",Vector3(2.65,9.0,8.1))
	sign_text("CLASSROOM",Vector3(.38,5.57,8.1))
	sign_text("BATHROOM",Vector3(-5.3,11.1,8.0),0)
	sign_text("BATHROOM",Vector3(-3.4,11.1,8.0),0)
	sign_text("ROOM",Vector3(5.65,5.57,8.0))
