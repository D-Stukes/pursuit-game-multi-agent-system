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
var pastry_mesh: SphereMesh

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

func cut_floor(label: String, area: Rect2, height: float, holes: Array[Rect2], color: Color) -> void:
	var pieces: Array[Rect2] = [area]
	for hole: Rect2 in holes:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces:
			if not piece.intersects(hole):
				next.append(piece)
				continue
			var cut := piece.intersection(hole)
			for remainder: Rect2 in [Rect2(piece.position,Vector2(cut.position.x-piece.position.x,piece.size.y)),Rect2(cut.end.x,piece.position.y,piece.end.x-cut.end.x,piece.size.y),Rect2(cut.position.x,piece.position.y,cut.size.x,cut.position.y-piece.position.y),Rect2(cut.position.x,cut.end.y,cut.size.x,piece.end.y-cut.end.y)]:
				if remainder.size.x>.00001 and remainder.size.y>.00001:
					next.append(remainder)
		pieces = next
	for piece: Rect2 in pieces:
		slab(label,piece,height,color)

func lift_floor_holes() -> Array[Rect2]:
	return [Rect2(-2.28,11.2,2.28,1.8),Rect2(0,11.55,.135,1.1),Rect2(-2.28,14.2,2.28,1.8),Rect2(0,14.55,.135,1.1)]

func cab_floors(level: float) -> void:
	# Rebuild only four floor plates: retained metal sills have sole ownership
	# of their footprint, with no coplanar cab/lobby face underneath.
	for depth: float in [11.2,14.2]:
		cut_floor("Lift cab floor",Rect2(-2.28,depth,2.28,1.8),level,[Rect2(-.195,depth+.35,.33,1.1)],Color(.13,.17,.20))

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
	sign_node.font_size = 32
	sign_node.outline_size = 0
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

func door_part(label: String, at: Vector2, along_y: bool, lo: Vector3, hi: Vector3, color: Color, glazed: bool = false) -> void:
	# Door-local coordinates: horizontal span, wall depth, absolute height.
	var a := Vector3(at.x+lo.x,at.y+lo.y,lo.z)
	var b := Vector3(at.x+hi.x,at.y+hi.y,hi.z)
	if along_y:
		a = Vector3(at.x+lo.y,at.y+lo.x,lo.z)
		b = Vector3(at.x+hi.y,at.y+hi.x,hi.z)
	if glazed: glass_box(label,a,b)
	else: box(label,a,b,color)

func closed_door(label: String, at: Vector2, width: float, level: float, along_y: bool = false, glazed: bool = false) -> void:
	var half := width*.5
	var frame := Color(.22,.28,.31)
	for side: float in [-1,1]:
		var x := side*(half-.035)
		door_part(label+" jamb",at,along_y,Vector3(x-.035,-.105,level),Vector3(x+.035,.105,level+2.5),frame)
	door_part(label+" head",at,along_y,Vector3(-half,-.105,level+2.43),Vector3(half,.105,level+2.5),frame)
	door_part(label+" threshold",at,along_y,Vector3(-half,-.105,level),Vector3(half,.105,level+.012),frame)
	if glazed:
		door_part(label+" closed glazing",at,along_y,Vector3(-half+.07,-.025,level+.12),Vector3(half-.07,.025,level+2.43),Color.WHITE,true)
		door_part(label+" bottom rail",at,along_y,Vector3(-half+.07,-.04,level+.012),Vector3(half-.07,.04,level+.12),frame)
	else:
		# Recessed opaque leaf and shallow inset distinguish a door from a wall box.
		door_part(label+" closed leaf",at,along_y,Vector3(-half+.07,-.035,level+.012),Vector3(half-.07,.035,level+2.43),Color(.91,.91,.87))
		for face: float in [-1,1]:
			var v := face*.038
			door_part(label+" inset panel",at,along_y,Vector3(-half+.17,minf(v,v+face*.008),level+.3),Vector3(half-.17,maxf(v,v+face*.008),level+2.18),Color(.83,.85,.82))
	for face: float in [-1,1]:
		var v := face*.10
		door_part(label+" lock plate",at,along_y,Vector3(half-.2,minf(v,v+face*.025),level+.94),Vector3(half-.13,maxf(v,v+face*.025),level+1.2),frame)
		door_part(label+" lever",at,along_y,Vector3(half-.36,minf(v,v+face*.06),level+1.08),Vector3(half-.15,maxf(v,v+face*.06),level+1.12),Color(.55,.6,.61))
		var key_depth: float = face*.128
		door_part(label+" keyhole",at,along_y,Vector3(half-.174,minf(key_depth,key_depth+face*.004),level+.985),Vector3(half-.156,maxf(key_depth,key_depth+face*.004),level+1.018),Color(.06,.07,.08))

func bakery() -> void:
	# Authored display dressing, visible through fixed glazing and locked street door.
	var steel := Color(.57,.62,.64)
	box("Bakery counter",Vector3(4.4,7.0,.85),Vector3(6.5,9.7,1.65),Color(.67,.49,.31))
	box("Bakery worktop",Vector3(4.35,6.95,1.65),Vector3(6.55,9.75,1.74),steel)
	box("Bakery oven",Vector3(7.8,6.9,.85),Vector3(9.4,8.1,2.7),steel)
	for height: float in [1.2,1.95]:
		box("Oven dark glass",Vector3(7.77,7.05,height),Vector3(7.79,7.95,height+.48),Color(.13,.19,.21))
		box("Oven handle",Vector3(7.69,7.13,height+.33),Vector3(7.76,7.87,height+.38),Color(.35,.4,.42))
	for x: float in [6.9,8.0]:
		for y: float in [9.4,10.5]:
			box("Bakery rack post",Vector3(x-.025,y-.025,.85),Vector3(x+.025,y+.025,2.8),steel)
	for h: float in [1.15,1.6,2.05,2.5]:
		box("Bakery tray shelf",Vector3(6.9,9.4,h),Vector3(8,10.5,h+.04),steel)
		for y: float in [9.65,10.15]:
			pastry("Rack loaf",Vector3(7.4,y+.1,h+.14),Vector3(.65,.2,.27),Color(.72,.43,.18))
	box("Bakery warm feature wall",Vector3(10,5,.85),Vector3(10.12,11.5,3.8),Color(.66,.44,.28))
	for h: float in [1.55,2.35,3.15]:
		box("Bakery wall shelf",Vector3(9.6,5.6,h),Vector3(10,10.9,h+.06),Color(.38,.25,.16))
		for y: float in [6,7,8,9,10]:
			box("Bakery flour tin",Vector3(9.68,y,h+.06),Vector3(9.95,y+.26,h+.38),Color(.86,.73,.49))
	# Low glass pastry case: bread, rolls and iced cakes stay on the worktop.
	glass_box("Bakery display front",Vector3(4.4,7.05,1.75),Vector3(4.43,9.65,2.25))
	glass_box("Bakery display top",Vector3(4.4,7.05,2.25),Vector3(5.75,9.65,2.28))
	for y: float in [7.05,9.65]:
		box("Bakery case upright",Vector3(4.39,y-.025,1.74),Vector3(4.45,y+.025,2.3),steel)
	for y: float in [7.4,8.05,8.7,9.3]:
		pastry("Counter loaf",Vector3(5.15,y,1.86),Vector3(.6,.19,.28),Color(.8,.53,.25))
		pastry("Counter roll",Vector3(4.68,y,1.83),Vector3(.23,.16,.23),Color(.86,.63,.33))
		pastry("Iced pastry",Vector3(5.5,y,1.84),Vector3(.23,.18,.23),Color(.72,.39,.2))
		pastry("Pastry icing",Vector3(5.5,y,1.94),Vector3(.21,.07,.21),Color(.94,.77,.7))
	box("Bakery coffee machine",Vector3(5.95,9.05,1.74),Vector3(6.5,9.6,2.33),Color(.16,.22,.24))
	box("Coffee machine panel",Vector3(5.92,9.14,1.94),Vector3(5.95,9.5,2.23),steel)
	box("Coffee drip tray",Vector3(5.79,9.1,1.75),Vector3(5.95,9.56,1.79),steel)
	for y: float in [9.22,9.44]:
		pastry("Coffee cup",Vector3(5.86,y,1.86),Vector3(.12,.14,.12),Color(.93,.9,.81))
		pastry("Coffee surface",Vector3(5.86,y,1.925),Vector3(.09,.012,.09),Color(.18,.1,.055))
	# Street-side displays make both locked frontage doors read as occupied premises.
	box("Bakery street display",Vector3(8.55,-3.2,0),Vector3(10.3,-2.6,.85),Color(.64,.43,.24))
	for x: float in [8.8,9.35,9.9]:
		pastry("Street display bread",Vector3(x,-2.9,.96),Vector3(.4,.18,.25),Color(.81,.55,.29))

func pastry(label: String, at: Vector3, size: Vector3, color: Color) -> void:
	if pastry_mesh == null:
		pastry_mesh = SphereMesh.new()
		pastry_mesh.radius = .5
		pastry_mesh.height = 1
		pastry_mesh.radial_segments = 8
		pastry_mesh.rings = 4
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = pastry_mesh
	mesh.material_override = material(color)
	root.add_child(mesh)
	mesh.position = Vector3(at.x,at.z,-at.y)
	mesh.scale = Vector3(size.x,size.z,size.y)

func _ground() -> void:
	# One original entrance; no front annex or extra pair of street doors.
	slab("Original entrance sidewalk",Rect2(-11.8,-8.3,23.6,3.55),0,Color(.64,.64,.59))
	slab("Entrance inner threshold bridge",Rect2(-3.32,-4.75,6.64,.35),0,Color(.64,.64,.59))
	slab("Ground foundation",Rect2(-24,-4.75,44,22.15),-.02,Color(.54,.55,.53))
	slab("Left ground room floor",GROUND_LEFT,.85,Color(.55,.56,.53))
	cut_floor("Raised ground core",Rect2(-6.2,6.24,9.56,11.16),.85,lift_floor_holes(),Color(.55,.56,.53))
	cab_floors(.85)
	slab("Right ground room floor",Rect2(3.36,2,16.56,15.4),.85,Color(.55,.56,.53))
	slab("Right neighbor street display floor",Rect2(3.36,-4.75,16.56,6.75),0,Color(.55,.56,.53))
	slab("Left neighbor street display floor",Rect2(-24,-4.75,20.64,7.75),0,Color(.55,.56,.53))
	# Explicit threshold finishes bridge both slab joins, including exact-edge rays.
	slab("Left room threshold",Rect2(-6.45,7.55,.6,1.65),.852,Color(.55,.56,.53))
	slab("Right room threshold",Rect2(3.08,7.55,.4,1.65),.852,Color(.55,.56,.53))
	# Supporting side wings close outside the accepted stair/ramp/core envelope.
	wall_x("Ground west perimeter",-24,-4.75,17.4,0)
	wall_x("Ground east perimeter",20,-4.75,17.4,0)
	wall_y("Ground rear perimeter",17.4,-24,20,0)
	wall_y("Ground left frontage",-4.75,-24,-3.36,0,-10.09,-8.69)
	wall_y("Ground right frontage",-4.75,3.36,20,0,8.69,10.09)
	closed_door("Left street locked glazed door",Vector2(-9.39,-4.75),1.4,0,false,true)
	closed_door("Right street locked glazed door",Vector2(9.39,-4.75),1.4,0,false,true)
	box("Left neighbor display desk",Vector3(-10.4,-2.9,0),Vector3(-8.5,-2.2,.8),Color(.64,.48,.3))
	box("Left neighbor display monitor",Vector3(-9.7,-2.6,.8),Vector3(-9.2,-2.5,1.25),Color(.15,.22,.25))
	box("Left neighbor display bench",Vector3(-11.4,-1.3,0),Vector3(-9.9,-.7,.48),Color(.42,.5,.5))
	# Fixed sidelights/transom complete the envelope around the existing open leaves.
	for span: Vector2 in [Vector2(-3.36,-1.315),Vector2(1.315,3.36)]:
		box("Entrance sidelight sill",Vector3(span.x,-4.86,0),Vector3(span.y,-4.68,.18),Color(.3,.35,.36))
		glass_box("Entrance fixed sidelight",Vector3(span.x,-4.79,.18),Vector3(span.y,-4.76,2.68))
		for x: float in [span.x,span.y]:
			box("Entrance fixed jamb",Vector3(x-.035,-4.87,0),Vector3(x+.035,-4.67,3.8),Color(.23,.29,.31))
	box("Entrance transom rail",Vector3(-3.36,-4.87,2.68),Vector3(3.36,-4.67,2.78),Color(.23,.29,.31))
	glass_box("Entrance fixed transom",Vector3(-3.36,-4.79,2.78),Vector3(3.36,-4.76,3.55))
	box("Entrance lintel",Vector3(-3.36,-4.88,3.55),Vector3(3.36,-4.66,3.8))
	box("Facade storey band",Vector3(-24,-4.88,3.8),Vector3(20,-4.66,FLOOR))
	# The old interior side walls stop short of the street plane; close both reveals.
	for span: Vector2 in [Vector2(-3.44,-3.28),Vector2(3.28,3.44)]:
		box("Entrance corner reveal closure",Vector3(span.x,-4.87,0),Vector3(span.y,-4.22,3.8))
	# Original ground face/glazed entry, stairs, yellow doors, ramp and banks remain.
	wall_x("Left room west",-22,3,15.18,.85)
	wall_y("Left room front",3,-22,-6.2,.85)
	wall_y("Left room back",15.18,-22,-6.2,.85)
	wall_x("Brown L west and left room entry",-6.1,3,16.8,.85,7.55,9.2)
	wall_y("Brown L back",16.8,-6.1,-2.48,.85)
	wall_x("Right room entry from forecourt",3.28,6.3,16.8,.85,7.55,9.2)
	closed_door("Locked left neighbor",Vector2(-6.1,8.375),1.65,.85,true,true)
	# No interior bakery doorway: a fixed viewing window closes the former opening.
	box("Bakery viewing sill",Vector3(3.2,7.55,.85),Vector3(3.36,9.2,1.65))
	glass_box("Bakery fixed viewing window",Vector3(3.265,7.55,1.65),Vector3(3.295,9.2,3.35))
	box("Bakery window head",Vector3(3.2,7.55,3.35),Vector3(3.36,9.2,3.8))
	for depth: float in [7.55,9.2]:
		box("Bakery window jamb",Vector3(3.18,depth-.035,1.6),Vector3(3.38,depth+.035,3.4),Color(.23,.29,.31))
	for height: float in [1.65,2.5,3.35]:
		box("Bakery window rail",Vector3(3.18,7.55,height-.035),Vector3(3.38,9.2,height+.035),Color(.27,.33,.35))
	bakery()
	box("Ground side wing ceiling west",Vector3(-24,-4.75,3.8),Vector3(-3.4,17.4,4.85))
	box("Ground side wing ceiling east",Vector3(3.4,-4.75,3.8),Vector3(20,17.4,4.85))
	for x: float in [-19,-14,-9,8,13,18]:
		for y: float in [4.5,10.0,14.0]:
			light_strip(x,y,3.8)

func _upper() -> void:
	cut_floor("Upper continuous floor",Rect2(-24,-4.75,44,22.15),FLOOR,lift_floor_holes(),Color(.49,.5,.48))
	cab_floors(FLOOR)
	slab("Classroom carpet",CLASSROOM,FLOOR+.008,Color(.24,.27,.29))
	slab("Reception finish",RECEPTION,FLOOR+.008,Color(.6,.61,.58))
	box("Upper ceiling",Vector3(-24,-4.75,TOP),Vector3(20,17.4,TOP+.16))
	wall_x("Upper west perimeter",-24,-4.75,17.4,FLOOR)
	wall_x("Upper east perimeter",20,-4.75,17.4,FLOOR)
	wall_y("Upper rear west",17.4,-24,0,FLOOR)
	wall_y("Upper rear east",17.4,4.94,20,FLOOR)
	# The bank end meets the wall; no accessible slot around the final cab.
	box("Lift bank end infill",Vector3(-2.5,16.04,FLOOR),Vector3(.02,17.4,TOP))
	box("Landing left window sill",Vector3(0,16.72,FLOOR),Vector3(4.94,16.88,6.0))
	glass_box("Landing left exterior window",Vector3(0,16.785,6.0),Vector3(4.94,16.815,7.8))
	box("Landing left window head",Vector3(0,16.72,7.8),Vector3(4.94,16.88,TOP))
	for x: float in [0,1.65,3.3,4.94]:
		box("Landing left window mullion",Vector3(x-.035,16.70,5.95),Vector3(x+.035,16.90,7.85),Color(.27,.33,.35))
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
	box("Classroom fixed door head",Vector3(-.98,5.35,7.55),Vector3(1.74,5.58,7.63),Color(.44,.48,.48))
	wall_x("Reception open hall return",-1.3,5.56,8.8,FLOOR,5.56,8.8)
	wall_x("Reception separate room door",5.3,5.56,8.8,FLOOR,7.15,8.65)
	closed_door("Reception side locked door",Vector2(5.3,7.9),1.5,FLOOR,true)
	box("Reception front header",Vector3(-1.3,8.82,7.9),Vector3(5.3,8.98,TOP))
	for x: float in [-1.3,1.4,3.94,5.3]:
		box("Reception front jamb",Vector3(x-.04,8.80,FLOOR),Vector3(x+.04,8.98,7.9),Color(.44,.48,.48))
	# Cover the solid front panels in matching blue glazing, with a clear doorway.
	# Panels end at jamb edges: shared front faces must not overlap the posts.
	for pair: Vector2 in [Vector2(-1.26,1.36),Vector2(3.98,5.26)]:
		box("Reception front sill",Vector3(pair.x,8.82,FLOOR),Vector3(pair.y,8.98,5.95))
		glass_box("Reception glazing",Vector3(pair.x,8.80,5.95),Vector3(pair.y,8.82,7.84))
		box("Reception sidelight top rail",Vector3(pair.x,8.8,7.84),Vector3(pair.y,8.98,7.9),Color(.27,.33,.35))
	# The closed white opposite door stays straight ahead out of the lift.
	wall_x("Other room west",4.94,9.0,17.4,FLOOR,11.55,12.65)
	closed_door("Opposite lift locked door",Vector2(4.94,12.1),1.1,FLOOR,true)
	wall_y("Other room front",9.0,4.94,20,FLOOR)
	# Hallway 1 ends at the bathrooms; the open area begins to its west.
	wall_x("Bathroom west",-6.2,11.2,17.4,FLOOR)
	wall_x("Bathroom east",-2.5,11.2,17.4,FLOOR)
	wall_x("Bathroom divider",-4.35,11.2,17.4,FLOOR)
	box("Bathroom shaft junction closure",Vector3(-2.58,11.04,FLOOR),Vector3(-2.25,11.16,TOP))
	wall_y("Bathroom 1 door wall",11.2,-6.2,-4.35,FLOOR,-5.88,-4.88)
	wall_y("Bathroom 2 door wall",11.2,-4.35,-2.5,FLOOR,-4.02,-3.02)
	closed_door("Bathroom 1 locked door",Vector2(-5.38,11.2),1.0,FLOOR)
	closed_door("Bathroom 2 locked door",Vector2(-3.52,11.2),1.0,FLOOR)
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
		closed_door("Hall room locked door "+str(i+1),Vector2(center,room.position.y),1.0,FLOOR)
	box("Hall rooms shared pier",Vector3(-3.9,6.92,FLOOR),Vector3(-3.7,8.88,TOP))
	# Additional room between classroom and the separate room, reaching the facade.
	wall_x("Additional room east",6.9,-4.75,5.46,FLOOR)
	wall_y("Additional room entry",5.46,4.42,6.9,FLOOR,5.1,6.2)
	open_leaf("Additional room open door",5.1,5.36,-1)
	# Other-room front is the sole shared wall; no second coplanar rear wall.
	for x: float in [-21,-16,-11,-7,-2,3,8,13,18]:
		for y: float in [-2.5,2.5,7.5,12.5,16]:
			light_strip(x,y,TOP)
	sign_text("RECEPTION",Vector3(2.65,9.0,8.1))
	sign_text("CLASSROOM",Vector3(.38,5.57,8.1))
	sign_text("BATHROOM",Vector3(-5.3,11.1,8.0),0)
	sign_text("BATHROOM",Vector3(-3.4,11.1,8.0),0)
