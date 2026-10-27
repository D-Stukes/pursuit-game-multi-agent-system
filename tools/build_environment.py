"""Rebuild the photo-reference environment in Blender; imported props stay separate.

Run with Blender --background --python tools/build_environment.py -- --output-dir ...
The manifest is the assembly contract. Native masters and images stay outside Git.
"""
import argparse, hashlib, json, math, subprocess, sys
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = ROOT / 'godot/assets/building-layout.json'
LAYOUT = json.loads(LAYOUT_PATH.read_text(encoding='utf-8-sig'))
LAYOUT_MODULE_ORIGINS={i['id']:i['origin'] for i in LAYOUT['modules']}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, required=True)
parser.add_argument('--source', type=Path)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = args.output_dir.resolve(); OUT.mkdir(parents=True, exist_ok=True)
F = LAYOUT['levels']['upper']; TOP = LAYOUT['levels']['upper_ceiling']
materials, meshes, modules, collections = {}, {}, {}, {}
BLUE=(.018,.065,.33,1); WHITE=(.74,.73,.68,1); STEEL=(.39,.44,.46,1)
INK=(.035,.045,.05,1); TILE=(.45,.45,.40,1); WOOD=(.53,.35,.17,1)
GLASS=(.34,.49,.53,.22); GREY=(.16,.18,.18,1); RED=(.5,.035,.022,1)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
if args.source:
    source=args.source.read_bytes()
else:
    s=LAYOUT['source']
    source=subprocess.check_output(['git','show',f"{s['revision']}:{s['path']}"],cwd=ROOT)
assert hashlib.sha256(source).hexdigest()==LAYOUT['source']['sha256'], 'Source identity changed'
cache=OUT/'source-cache.glb'; cache.write_bytes(source)
bpy.ops.import_scene.gltf(filepath=str(cache))
imported=list(scene.objects)
lookup={}
exact_lookup={}
def key(s):
    return ''.join(c for c in s.lower() if c not in ' _|.-:/()')
for ob in imported:
    if ob.type=='MESH':
        lookup[key(ob.name)]=ob
        exact_lookup[ob.name]=ob
selection=json.loads((ROOT/LAYOUT['source']['selection']).read_text())['meshes']

root=bpy.data.objects.new('Pursuit_Assembly',None); scene.collection.objects.link(root)
root['assembly_schema']=2; root['units']='metres'; root['source_sha256']=LAYOUT['source']['sha256']
root['dimensions']='Photo-estimated, not surveyed'
for item in LAYOUT['modules']:
    col=bpy.data.collections.new(item['id']); scene.collection.children.link(col)
    col.instance_offset=item['origin']; col['reference_photos']=','.join('IMG_'+str(n) for n in item['photos'])
    module=bpy.data.objects.new(item['id']+'_ROOT',None); col.objects.link(module)
    module.parent=root; module.location=item['origin']; module['module_id']=item['id']
    modules[item['id']]=module; collections[item['id']]=col
# Floor roots are explicit stacking references; vertical core remains independent.
for floor_name,height,ids in [
 ('Floor_Street',0,['Ground_Core']),
 ('Floor_Upper',F,['Upper_Circulation','Reception','Classroom','Small_Room','Larger_Room','Internal_Hall','Commons','Side_Workspace'])]:
    floor_root=bpy.data.objects.new(floor_name,None);scene.collection.objects.link(floor_root)
    floor_root.parent=root;floor_root.location=(0,0,height);floor_root['level_elevation']=height
    for ident in ids:
        modules[ident].parent=floor_root
        modules[ident].location=Vector(LAYOUT_MODULE_ORIGINS[ident])-Vector((0,0,height))
current='Ground_Core'
def attach(ob, module_id=None):
    ident=module_id or current
    world=ob.matrix_world.copy()
    for c in list(ob.users_collection): c.objects.unlink(ob)
    collections[ident].objects.link(ob)
    ob.parent=modules[ident]; ob.matrix_parent_inverse=Matrix.Identity(4)
    ob.matrix_basis=modules[ident].matrix_world.inverted() @ world
    ob['module_id']=ident
    return ob
# Evaluate module matrices before parenting existing geometry in world space.
bpy.context.view_layer.update()
kept=[]
for item in selection:
    kind=item['kind']
    if kind not in ('ground','bank','bank_trim','classroom'):continue
    ob=exact_lookup.get(item['name']) or lookup.get(key(item['name']))
    assert ob is not None, item['name']
    ob.matrix_world=Matrix.Translation(Vector(item['delta'])) @ ob.matrix_world
    if kind=='classroom': ob.matrix_world=Matrix.Translation((-6.3,0,0)) @ ob.matrix_world
    if kind=='bank_trim':
        ys=[(ob.matrix_world @ Vector(v)).y for v in ob.bound_box]; lo,hi=min(ys),max(ys)
        factor=(hi-11.08)/(hi-lo)
        assert 0<factor<1
        ob.matrix_world=Matrix.Translation((0,hi,0)) @ Matrix.Diagonal((1,factor,1,1)) @ Matrix.Translation((0,-hi,0)) @ ob.matrix_world
    attach(ob,'Classroom' if kind=='classroom' else 'Lift_Banks' if kind.startswith('bank') else 'Ground_Core')
    assert ob not in kept, 'Duplicate source selection: '+item['name']
    ob['retained_source_kind']=kind; kept.append(ob)
for ob in imported:
    if ob not in kept and ob.name in bpy.data.objects: bpy.data.objects.remove(ob,do_unlink=True)
for col in list(bpy.data.collections):
    if col.name not in collections and not col.objects and not col.children: bpy.data.collections.remove(col)

# Shared data meshes: repeat objects keep identity and parentage without welding.
def mat(color,metal=0,emission=0):
    k=(tuple(color),metal,emission)
    if k in materials:return materials[k]
    m=bpy.data.materials.new('MAT_'+str(len(materials)));m.diffuse_color=color;m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.65 if not metal else .32
    p.inputs['Alpha'].default_value=color[3]
    if color[3]<1:m.surface_render_method='DITHERED';m.use_transparency_overlap=False
    if emission:
        p.inputs['Emission Color'].default_value=color;p.inputs['Emission Strength'].default_value=emission
    materials[k]=m;return m

def mesh_object(name,verts,faces,color,metal=0,emission=0):
    k=(tuple(tuple(round(v,5) for v in a) for a in verts),tuple(tuple(a) for a in faces),tuple(color),metal,emission)
    if k not in meshes:
        data=bpy.data.meshes.new(name+'_mesh');data.from_pydata(verts,[],faces);data.materials.append(mat(color,metal,emission));meshes[k]=data
    ob=bpy.data.objects.new(name,meshes[k]);collections[current].objects.link(ob)
    ob.parent=modules[current];ob['module_id']=current
    return ob

def box(name,lo,hi,color=WHITE,metal=0,emission=0):
    lo,hi=Vector(lo),Vector(hi);size=hi-lo
    assert min(size)>0,(name,lo,hi)
    verts=[(x*size.x/2,y*size.y/2,z*size.z/2) for x,y,z in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
    # Counterclockwise viewed from outside: correct light response and culling.
    faces=[(2,6,4,0),(5,7,3,1),(4,5,1,0),(3,7,6,2),(1,3,2,0),(6,7,5,4)]
    ob=mesh_object(name,verts,faces,color,metal,emission)
    ob.location=(lo+hi)/2-Vector(LAYOUT_MODULE_ORIGINS[current]);return ob

def cyl(name,at,r,h,color=WHITE,segments=16):
    verts=[(r*math.cos(i*math.tau/segments),r*math.sin(i*math.tau/segments),z) for z in [-h/2,h/2] for i in range(segments)]
    faces=[tuple(reversed(range(segments))),tuple(range(segments,segments*2))]+[(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
    ob=mesh_object(name,verts,faces,color);ob.location=Vector(at)-Vector(LAYOUT_MODULE_ORIGINS[current]);return ob

def beam(name,a,b,r,color=STEEL):
    a,b=Vector(a),Vector(b);ob=cyl(name,(a+b)/2,r,(b-a).length,color,10)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return ob

def floor(name,x0,y0,x1,y1,z,color=TILE):box(name,(x0,y0,z-.14),(x1,y1,z),color)
def wallx(name,x,y0,y1,z=F,top=TOP,doors=(),color=WHITE,door_height=2.55):
    cursor=y0
    for a,b in sorted(doors):
        if a>cursor:box(name,(x-.08,cursor,z),(x+.08,a,top),color)
        box(name+'_head',(x-.08,a,z+door_height),(x+.08,b,top),color);cursor=b
    if cursor<y1:box(name,(x-.08,cursor,z),(x+.08,y1,top),color)
def wally(name,y,x0,x1,z=F,top=TOP,doors=(),color=WHITE,door_height=2.55):
    cursor=x0
    for a,b in sorted(doors):
        if a>cursor:box(name,(cursor,y-.08,z),(a,y+.08,top),color)
        box(name+'_head',(a,y-.08,z+door_height),(b,y+.08,top),color);cursor=b
    if cursor<x1:box(name,(cursor,y-.08,z),(x1,y+.08,top),color)
def glazing_y(name,y,x0,x1,z0,z1,color=GLASS):
    box(name+'_glass',(x0,y-.025,z0),(x1,y+.025,z1),color)
    for z in [z0,z1]:box(name+'_rail',(x0,y-.045,z-.025),(x1,y+.045,z+.025),STEEL)
    for x in [x0,x1]:box(name+'_jamb',(x-.025,y-.045,z0),(x+.025,y+.045,z1),STEEL)
def glazing_x(name,x,y0,y1,z0,z1):
    box(name+'_glass',(x-.025,y0,z0),(x+.025,y1,z1),GLASS)
    for z in [z0,z1]:box(name+'_rail',(x-.045,y0,z-.025),(x+.045,y1,z+.025),STEEL)
    for y in [y0,y1]:box(name+'_jamb',(x-.045,y-.025,z0),(x+.045,y+.025,z1),STEEL)
def portal(name,x,y,width,along_x=False,open=True,color=STEEL,swing_positive=False):
    # Origin sits exactly at floor/threshold. Open leaves remain clear of the aperture.
    if along_x:
        for v in [-width/2,width/2]:box(name+'_jamb',(x+v-.035,y-.06,F),(x+v+.035,y+.06,F+2.55),color)
        box(name+'_head',(x-width/2,y-.06,F+2.5),(x+width/2,y+.06,F+2.56),color)
    else:
        for v in [-width/2,width/2]:box(name+'_jamb',(x-.06,y+v-.035,F),(x+.06,y+v+.035,F+2.55),color)
        box(name+'_head',(x-.06,y-width/2,F+2.5),(x+.06,y+width/2,F+2.56),color)
    if open:
        # A ninety-degree open glass leaf stays hinged to the jamb, clear of travel.
        if along_x:
            xx=x-width/2
            if swing_positive:glazing_x(name+'_open_leaf',xx,y+.04,y+width-.06,F+.08,F+2.45)
            else:glazing_x(name+'_open_leaf',xx,y-width+.06,y-.04,F+.08,F+2.45)
        else:
            yy=y-width/2
            glazing_y(name+'_open_leaf',yy,x-width+.06,x-.04,F+.08,F+2.45)
    if not open:
        if along_x:box(name+'_closed_leaf',(x-width/2+.03,y-.03,F+.01),(x+width/2-.03,y+.03,F+2.48),(.57,.61,.60,1))
        else:box(name+'_closed_leaf',(x-.03,y-width/2+.03,F+.01),(x+.03,y+width/2-.03,F+2.48),(.57,.61,.60,1))

def text(name,value,at,size=.22,color=INK,rotation=(math.pi/2,0,0)):
    curve=bpy.data.curves.new(name,'FONT');curve.body=value;curve.size=size;curve.align_x='CENTER';curve.extrude=.001
    ob=bpy.data.objects.new(name,curve);collections[current].objects.link(ob);ob.parent=modules[current]
    ob.location=Vector(at)-Vector(LAYOUT_MODULE_ORIGINS[current]);ob.rotation_euler=rotation;curve.materials.append(mat(color));return ob

def table(name,x,y,z=F,w=1.5,d=.8,h=.75,color=WHITE):
    box(name+'_top',(x-w/2,y-d/2,z+h-.05),(x+w/2,y+d/2,z+h),color)
    for dx in [-w/2+.08,w/2-.08]:
        for dy in [-d/2+.08,d/2-.08]:box(name+'_leg',(x+dx-.025,y+dy-.025,z),(x+dx+.025,y+dy+.025,z+h-.05),INK)
def chair(name,x,y,z=F,heading=0):
    objects=[]
    def b(n,lo,hi,c):objects.append(box(name+n,lo,hi,c))
    b('_seat',(x-.22,y-.22,z+.43),(x+.22,y+.22,z+.49),INK)
    b('_back',(x-.23,y+.18,z+.49),(x+.23,y+.24,z+.9),INK)
    for dx in [-.18,.18]:
        for dy in [-.18,.18]:b('_leg',(x+dx-.018,y+dy-.018,z),(x+dx+.018,y+dy+.018,z+.43),STEEL)
    if heading:
        centre=Vector((x,y,z));T=Matrix.Translation(centre) @ Matrix.Rotation(heading,4,'Z') @ Matrix.Translation(-centre)
        bpy.context.view_layer.update()
        for ob in objects:ob.matrix_world=T @ ob.matrix_world

def sofa(name,x,y,w=2,z=F,color=GREY):
    box(name+'_base',(x-w/2,y-.42,z+.12),(x+w/2,y+.42,z+.46),color)
    box(name+'_back',(x-w/2,y+.3,z+.46),(x+w/2,y+.46,z+.9),color)
    for dx in [-w/2,w/2]:box(name+'_arm',(x+dx-.08,y-.42,z+.28),(x+dx+.08,y+.42,z+.72),color)
    for dx in [-w*.32,w*.32]:box(name+'_cushion',(x+dx-.22,y-.05,z+.48),(x+dx+.22,y+.28,z+.72),(.55,.57,.25,1))

def plant(name,x,y,z=F):
    cyl(name+'_pot',(x,y,z+.25),.23,.5,(.61,.57,.44,1))
    for i in range(7):
        angle=i*math.tau/7
        beam(name+'_stem',(x,y,z+.4),(x+.18*math.cos(angle),y+.18*math.sin(angle),z+.85+.1*(i%3)),.018,(.10,.22,.065,1))
        ob=cyl(name+'_leaf',(x+.2*math.cos(angle),y+.2*math.sin(angle),z+.85+.1*(i%3)),.11,.035,(.13,.30,.08,1),8)
        ob.rotation_euler=(.5*math.cos(angle),.5*math.sin(angle),angle)

# Ground: retain source stairs/ramp/partition and dress the photographed envelope.
current='Ground_Core'
floor('Ground_foundation',-23,-4.75,25,17.4,-.02)
floor('Street_threshold',-3.32,-4.85,3.32,-4.3,.006)
# Raised elevator forecourt, with cab floors inside the shared shaft anchors.
floor('Raised_lobby',-2.5,6.3,3.35,17.4,.85)
for depth in [12.1,15.1]:floor('Ground_cab_plate',-2.28,depth-.9,0,depth+.9,.85,INK)
wallx('Ground_east',25,-4.75,17.4,0,4.85)
wallx('Ground_west',-23,-4.75,17.4,0,4.85)
wally('Ground_rear',17.4,-23,25,0,4.85)
# Closed side wings, with bakery visible through existing view opening.
wallx('Bakery_view_wall',3.32,6.3,17.4,.85,4.5,doors=[(7.55,9.2)])
glazing_x('Bakery_observation',3.32,7.55,9.2,1.65,3.35)
box('Bakery_window_sill',(3.24,7.55,.85),(3.40,9.2,1.65))
box('Bakery_window_head',(3.24,7.55,3.35),(3.40,9.2,4.5))
floor('Bakery_floor',3.4,2,24.8,17.2,.85)
for x in [7,10,13]:
    for y in [7,11,14]:
        for h in [1.3,1.7,2.1,2.5]:box('Bakery_rack_shelf',(x,y,h),(x+1.3,y+.65,h+.035),STEEL,metal=.7)
        for dx in [0,1.3]:
            for dy in [0,.65]:box('Bakery_rack_post',(x+dx-.02,y+dy-.02,.85),(x+dx+.02,y+dy+.02,2.7),STEEL,metal=.7)
        for h in [1.36,1.76,2.16]:
            for a in range(4):cyl('Bread_roll',(x+.2+a*.28,y+.33,h),.10,.09,(.66,.39,.12,1),10)
for x in [7,11]:box('Bakery_steel_worktop',(x,3.5,1.65),(x+2.5,4.3,1.72),STEEL,metal=.8)
# No ground check-in desk: selected gameplay check-in is upstairs.
box('Ground_ceiling',( -3.3,-4.6,4.52),(3.3,6.3,4.65),(.55,.55,.51,1))

# Upper slab and shaft floor holes: no floor across the bores except cab plates.
current='Upper_Circulation'
floor('Upper_front_slab',-23,-4.75,25,11.0,F)
floor('Upper_west_slab',-23,11.0,-2.5,17.4,F)
floor('Upper_east_slab',0.14,11.0,25,17.4,F)
for depth in [12.1,15.1]:floor('Upper_cab_plate',-2.28,depth-.9,0,depth+.9,F,INK)
box('Upper_ceiling',(-23,-4.75,TOP),(25,17.4,TOP+.16))
wallx('Upper_west',-23,-4.75,17.4)
wallx('Upper_east',25,-4.75,17.4)
wally('Upper_rear',17.4,-23,25)
# Narrow landing: lifts to west, blue-glazed separate room to east, window at end.
wallx('Landing_east_room',2.25,10.2,17.4,doors=[(14.25,15.55)])
portal('Landing_separate_room_door',2.25,14.9,1.3,open=False)
for a,b in [(10.35,13.9),(15.8,17.1)]:glazing_x('Landing_blue_glazing',2.16,a,b,F+.75,F+2.7)
wallx('Landing_shaft_side',-2.5,11.0,17.4)
# End window replaces opaque wall segment and looks to adjacent facade.
# Rear wall is split to preserve this opening.
for ob in list(collections[current].objects):
    if ob.name=='Upper_rear':bpy.data.objects.remove(ob,do_unlink=True)
wally('Upper_rear_west',17.4,-23,0)
wally('Upper_rear_east',17.4,2.3,25)
box('Landing_end_sill',(0,17.32,F),(2.3,17.48,F+.65))
box('Landing_end_head',(0,17.32,F+2.9),(2.3,17.48,TOP))
glazing_y('Landing_end_window',17.4,.12,2.18,F+.65,F+2.9)
# External corridor along reception glass; it does not enter the commons.
wallx('External_corridor_end',10.3,8.1,10.9)
wally('External_corridor_north',10.9,2.25,10.3,doors=[(6.6,7.6),(8.6,9.6)])
for x in [7.1,9.1]:portal('Restroom_door',x,10.9,1,along_x=True,open=False)
for x in [2.8,6.0]:cyl('External_corridor_column',(x,9.9,F+1.9),.28,3.8)
for x in [7.1,9.1]:
    floor('Restroom_floor',x-.8,10.3,x+.8,13.2,F)
    text('Restroom_sign','RESTROOM',(x,10.08,F+2.75),.13)
# Finish partition behind shaft / unobserved service rooms stays closed.
wallx('Service_west_return',-12,10.2,17.4)

# Reception has distinct D2, D3, D4 destinations and separate hall opening.
current='Reception'
floor('Reception_finish',-1.72,2.58,6.92,8.02,F+.006,(.67,.67,.61,1))
# West blue wall: classroom then small room.
wallx('Reception_blue_room_wall',-1.8,2.5,8.1,doors=[(3.45,4.95),(6.05,7.35)],color=BLUE)
portal('Classroom_portal',-1.8,4.2,1.5)
portal('Small_room_portal',-1.8,6.7,1.3)
# Three different sides: white far wall, blue room wall, glazed entry wall.
wally('Reception_far_room_wall',8.1,-1.8,7,doors=[(-1.55,-.25)])
portal('Larger_room_portal',-.9,8.1,1.3,along_x=True,swing_positive=True)
portal('Reception_entry_portal',7,6.7,1.5)
for a,b in [(2.6,4.2),(4.3,5.9),(7.5,8.0)]:glazing_x('Reception_entry_glazing',7,a,b,F+.12,F+2.8)
box('Reception_glass_sill',(6.92,2.5,F),(7.08,5.9,F+.12))
box('Reception_glass_head',(6.92,2.5,F+2.8),(7.08,8.1,TOP))
# An outer return connects the elevator corridor to the glazed entrance, without
# cutting through reception or into commons. The main slab supports this strip.
# Commons' existing entry wall closes the outer return. Do not duplicate it.
box('Reception_far_TV',(2.5,7.97,F+1.3),(4.5,8.02,F+2.42),INK)
box('Reception_far_TV_screen',(2.57,7.95,F+1.37),(4.43,7.97,F+2.35),BLUE)
# The screen is graphic geometry; no floating text outside its frame.
wally('Reception_south_blue',2.5,-1.8,7,doors=[(0,2)],color=BLUE,door_height=3.5)
# Reception counter faces arriving player, beside blue room wall.
box('Reception_counter',( -1.1,4.7,F),(1.1,5.5,F+1.0),WHITE)
box('Reception_counter_top',(-1.15,4.65,F+1),(1.15,5.55,F+1.07),(.91,.90,.85,1))
box('Reception_counter_light',(-.9,5.505,F+.35),(.9,5.52,F+.53),(.10,.68,.42,1),emission=.6)
table('Reception_side_desk',1.5,4.5,w=1.8,d=.75)
chair('Reception_task_chair',.3,4.2)
box('Reception_monitor',(.1,4.75,F+1.08),(.75,4.82,F+1.5),INK)
sofa('Reception_sofa',5.8,4.2,w=2.0)
# Distinctive egg chair: a curved open cocoon, cushion and pedestal.
verts=[];faces=[];rings=16;segments=24
for j in range(rings+1):
    phi=-1.1+j*2.6/rings
    for i in range(segments+1):
        theta=i*math.pi/segments
        verts.append((.55*math.cos(phi)*math.cos(theta),.48*math.cos(phi)*math.sin(theta),.78*math.sin(phi)))
for j in range(rings):
    for i in range(segments):
        a=j*(segments+1)+i;faces.append((a,a+1,a+segments+2,a+segments+1))
egg=mesh_object('Reception_egg_chair_shell',verts,faces,GREY)
egg.location=Vector((4.1,3.25,F+.95))-Vector(LAYOUT_MODULE_ORIGINS[current])
shell=egg.modifiers.new('Upholstery_shell','SOLIDIFY');shell.thickness=.055
for face in egg.data.polygons:face.use_smooth=True
box('Egg_chair_cushion',(3.70,3.02,F+.47),(4.50,3.48,F+.61),(.28,.27,.22,1))
cyl('Egg_chair_pedestal',(4.1,3.25,F+.23),.045,.46,STEEL)
cyl('Egg_chair_base',(4.1,3.25,F+.035),.34,.07,STEEL)
table('Reception_coffee',5.0,5.8,w=1.4,d=.65,h=.42,color=WOOD)
plant('Reception_plant',5.9,7.4)
cyl('Reception_red_bin',(6.3,6.9,F+.45),.21,.9,RED)
box('Reception_display',(-1.69,5.1,F+1.7),(-1.62,5.85,F+2.25),BLUE)
for tilt in [-.6,.6]:
    points=[]
    for i in range(49):
        t=i*math.tau/48;u=.17*math.cos(t);v=.34*math.sin(t)
        points.append((-1.60,7.65+u*math.cos(tilt)-v*math.sin(tilt),F+1.95+u*math.sin(tilt)+v*math.cos(tilt)))
    for a,b in zip(points,points[1:]):beam('Reception_neon_orbit',a,b,.012,(.12,.72,.84,1))
for i in range(3):
    box('Reception_art_frame',(2.7+i*1.3,2.59,F+1.0),(3.75+i*1.3,2.66,F+2.3),WOOD)
    box('Reception_art',(2.76+i*1.3,2.67,F+1.06),(3.69+i*1.3,2.68,F+2.24),[(.22,.38,.29,1),(.1,.14,.15,1),(.71,.58,.21,1)][i])

# Classroom preserves every selected prop at one rigid offset, no uniform scaling.
current='Classroom'
floor('Classroom_carpet',-21.45,-4.6,-1.89,5.32,F+.008,(.18,.19,.18,1))
wallx('Classroom_west',-21.5,-4.75,5.4)
wally('Classroom_back',5.4,-21.5,-1.8)
# Single classroom portal is in reception west wall; no duplicate glass pair.
current='Small_Room'
floor('Small_room_floor',-7,5.4,-1.8,8.1,F+.008)
wallx('Small_room_west',-7,5.4,8.1)
wally('Small_room_back',8.1,-12,-1.8,doors=())
table('Small_room_table',-4.6,6.7,w=1.5,d=.7)
for x in [-5.15,-4.05]:chair('Small_room_chair',x,7.3)
current='Larger_Room'
floor('Larger_room_floor',-12,8.1,0,11.0,F+.008)
wallx('Larger_room_west',-12,8.1,11)
wallx('Larger_room_east',0,8.1,11)
wally('Larger_room_back',11,-12,0)
# West room boundary stops at x0; landing remains entirely separate.
for x in [-9,-5]:
    table('Larger_room_table',x,9.5,w=2,d=.7)
    for dx in [-.6,.6]:chair('Larger_room_chair',x+dx,10.2)

# Internal hall beside classroom/chair, independent of outer restroom corridor.
current='Internal_Hall'
floor('Internal_hall_finish',0,-2.5,8.5,2.5,F+.008)
# A short approach from reception turns into the photographed passage. Looking
# toward commons, blue is on the left and black meeting-room glazing on right.
wally('Hall_blue_side',-2.5,0,8.5,color=BLUE)
wallx('Hall_approach_blue',0,-2.5,2.5,color=BLUE)
wally('Meeting_room_front',-.5,2,8.5,doors=[(3.6,4.9),(6.1,7.4)],color=INK)
for x in [4.25,6.75]:portal('Meeting_room_glass_door',x,-.5,1.3,along_x=True,open=False)
for a,b in [(2,3.4),(5.0,5.95),(7.5,8.4)]:glazing_y('Meeting_room_glass',-.6,a,b,F+.5,F+2.6)
for x in [3,6]:
    table('Meeting_room_worktable',x,1.2,w=1.5,d=.7)
    chair('Meeting_room_chair',x,.55,heading=math.pi)
wallx('Meeting_room_divider',5.2,-.5,2.5)

# Commons: continuous blue side, long window wall, kitchen, island and seating.
current='Commons'
floor('Commons_polished_floor',8.5,-4.6,24.8,8.1,F+.008,(.58,.58,.53,1))
wally('Commons_blue_wall',8.1,8.5,25,color=BLUE)
wallx('Commons_entry_wall',8.5,-4.6,8.1,doors=[(-2.5,-.5)],color=BLUE,door_height=3.5)
# Kitchen is at the east end, perpendicular to windows and the long blue wall.
# Construct it in a local working orientation, then turn its whole furnishing set.
kitchen_start=set(collections[current].objects)
box('Kitchen_charcoal_backing',(13.8,8.0,F),(21.8,8.08,TOP),(.035,.04,.04,1))
for x in [14,15,16,17,18,19]:
    box('Kitchen_base',(x,7.25,F),(x+.94,8.0,F+.88),WHITE)
    box('Kitchen_upper',(x,7.65,F+1.55),(x+.94,8.0,F+2.3),WHITE)
    beam('Cabinet_handle',(x+.72,7.62,F+1.7),(x+.72,7.62,F+2.05),.012,STEEL)
box('Kitchen_worktop',(14,7.18,F+.88),(20.0,8.02,F+.94),(.78,.77,.7,1))
box('Fridge',(20.25,7.0,F),(21.55,7.95,F+2.2),STEEL,metal=.8)
for x in [20.88,20.96]:beam('Fridge_handle',(x,6.96,F+.7),(x,6.96,F+1.6),.018,INK)
box('Fridge_door_seam',(20.89,6.95,F+.03),(20.91,6.98,F+2.17),INK)
box('Microwave',(14.2,7.3,F+.95),(14.85,7.85,F+1.35),INK)
box('Microwave_screen',(14.24,7.275,F+1.0),(14.66,7.3,F+1.3),(.13,.17,.17,1))
box('Sink',(17.1,7.28,F+.945),(18.0,7.85,F+.96),STEEL,metal=.8)
beam('Sink_tap',(17.65,7.85,F+.95),(17.65,7.85,F+1.24),.022,STEEL)
beam('Sink_spout',(17.65,7.85,F+1.24),(17.65,7.55,F+1.24),.022,STEEL)
# White island has open cubbies and thin counter, not a solid room blocker.
box('Island_top',(14.2,4.5,F+.94),(19.0,5.5,F+1.0),(.86,.85,.79,1))
box('Island_base',(14.3,4.6,F+.08),(18.9,5.4,F+.15),WHITE)
for x in [14.3,15.45,16.6,17.75,18.9]:box('Island_divider',(x-.035,4.6,F+.15),(x+.035,5.4,F+.94),WHITE)
box('Island_shelf',(14.3,4.6,F+.47),(18.9,5.4,F+.51),WHITE)
for x in [15,16.2,17.4,18.5]:
    cyl('Island_stool_seat',(x,3.95,F+.68),.22,.055,WHITE)
    for dx in [-.13,.13]:beam('Island_stool_leg',(x+dx,3.8,F),(x+dx,3.95,F+.65),.018,STEEL)
# Rigid placement changes orientation without scaling cabinetry or appliances.
bpy.context.view_layer.update()
turn=Matrix.Translation((16.85,17.5,0)) @ Matrix.Rotation(-math.pi/2,4,'Z')
for ob in set(collections[current].objects)-kitchen_start:ob.matrix_world=turn @ ob.matrix_world
for x in [12,15]:
    table('Commons_dining_table',x,1.3,w=1.65,d=.85,color=INK)
    for y in [.65,1.95]:
        for dx in [-.5,.5]:chair('Commons_folding_chair',x+dx,y,heading=math.pi if y<1 else 0)
sofa('Commons_couch',17.2,.2,w=2.2)
sofa('Commons_armchair',19.5,.2,w=.85)
table('Commons_coffee_table',18,1.7,w=1.7,d=.8,h=.42,color=WOOD)
cyl('Commons_round_rug',(18,1.7,F+.016),1.65,.015,(.36,.31,.21,1),32)
for x in [16.6,19.4]:cyl('Commons_pouf',(x,2.5,F+.2),.28,.4,GREY)
# Window workstations and a low back to the lounge remain below sightlines.
for x in [10,13,16,19]:
    table('Window_worktable',x,-3.4,w=2,d=.65)
    chair('Window_workchair',x,-2.65)
box('Lounge_divider',(15,-1.4,F),(20,-1.2,F+1.1),GREY)
for x in [10,12.6,15.2]:
    box('Privacy_booth_side',(x,6.35,F),(x+.07,7.8,F+2.2),WOOD)
    box('Privacy_booth_back',(x,7.73,F),(x+1.1,7.8,F+2.2),WOOD)
    glazing_y('Privacy_booth_front',6.35,x+.1,x+1.0,F+.1,F+2.15)
# Donation rack and shelving are on the approach side, clear of the hall.
for x in [17.5,19.2]:beam('Donation_rack_post',(x,7.4,F),(x,7.4,F+1.8),.025,STEEL)
beam('Donation_rack_bar',(17.5,7.4,F+1.8),(19.2,7.4,F+1.8),.025,STEEL)
for i in range(7):box('Donated_clothing',(17.6+i*.2,7.25,F+.6),(17.72+i*.2,7.55,F+1.7),[BLUE,GREY,WOOD,WHITE][i%4])
plant('Commons_plant',24,7.0)
current='Side_Workspace'
# Side recess is kept visually legible but not claimed as a surveyed extra room.
wallx('Telephone_closet_wall',23.1,5.4,8.0,doors=[(6.0,7.1)])
portal('Telephone_closet',23.1,6.55,1.1,open=False)
table('Side_workstation',24,4.1,w=1.0,d=.6)
chair('Side_workspace_chair',24,4.9)

# Photographed columns, red services and silver ducts unify the upper spaces.
current='Upper_Circulation'
for x,y in [(-1.7,5.5),(10.5,-.4),(16,-.4),(21.5,-.4),(10.5,6.5),(22,6.5)]:
    # Avoid the two-metre internal circulation strip.
    cyl('Structural_column',(x,y,F+1.9),.27,3.8,BLUE if y>2.5 and x<8 else WHITE)
for x0,x1,y in [(-20,6,4.8),(0,24,3.0),(8.8,24,6.7)]:
    box('Silver_main_duct',(x0,y-.28,TOP-.6),(x1,y+.28,TOP-.18),STEEL,metal=.65)
    for x in range(math.ceil(x0),math.floor(x1),2):box('Duct_joint',(x-.018,y-.29,TOP-.61),(x+.018,y+.29,TOP-.17),(.47,.51,.52,1),metal=.6)
for y in [-3.5,6.2]:beam('Sprinkler_main',(-22,y,TOP-.12),(24,y,TOP-.12),.035,RED)
for x in [-18,-12,-6,0,6,12,18,24]:
    beam('Sprinkler_branch',(x,-4.5,TOP-.12),(x,8.0,TOP-.12),.018,RED)
for x in [-19,-13,-7,0,5,10,15,20,24]:
    for y in [-2.3,4.3,7.0,9.1]:
        if x<0 and y>5.1:continue
        box('Pendant_light',(x-.85,y-.06,TOP-.45),(x+.85,y+.06,TOP-.38),(.86,.83,.66,1),emission=1.8)
        for dx in [-.65,.65]:beam('Light_suspension',(x+dx,y,TOP-.38),(x+dx,y,TOP-.02),.005,INK)

# Exterior main white four-storey block and adjacent dark industrial frontage.
current='Exterior_Main'
front=-4.75
# Ground entrance opening exactly agrees with puzzle anchor; windows in side bays.
for a,b in [(-12,-1.52),(1.52,20)]:
    box('Ground_front_base',(a,front-.14,0),(b,front+.02,.65),(.38,.38,.35,1))
    box('Ground_front_head',(a,front-.14,3.55),(b,front+.02,4.85),WHITE)
    for x in [a+i*3.8 for i in range(int((b-a)/3.8)+1)]:
        end=min(x+3.8,b)
        if end-x<.4:continue
        glazing_y('Ground_facade_window',front,x+.12,end-.12,.65,3.55)
        for zz in [1.5,2.55]:box('Ground_window_crossbar',(x+.1,front-.065,zz-.025),(end-.1,front+.015,zz+.025),INK)
# Tall entry transom and full facade shell above gameplay volumes.
glazing_y('Entry_transom',front,-1.46,1.46,2.7,4.0)
box('Entry_head',(-1.52,front-.14,4),(1.52,front+.02,4.85),WHITE)
for x in [-1.52,1.52]:box('Entry_pier',(x-.10,front-.22,0),(x+.10,front+.02,4.85),(.38,.38,.35,1))
for z0,z1 in zip(LAYOUT['levels']['facade_storeys'][1:-1],LAYOUT['levels']['facade_storeys'][2:]):
    # First such facade band encloses the playable upper level too.
    box('Facade_horizontal_band',(-12,front-.22,z0),(20,front+.05,z0+.9),WHITE)
    for i in range(8):
        x=-12+i*4.0; end=x+4.0
        glazing_y('Upper_facade_window',front+.04,x+.32,end-.32,z0+.9,z1-.5,GLASS if z0<8 else (.10,.17,.20,1))
        for zz in [z0+1.65,z0+2.55]:box('Window_crossbar',(x+.22,front-.07,zz-.025),(end-.22,front+.01,zz+.025),INK)
        box('Facade_pier',(x-.20,front-.30,z0),(x+.20,front+.18,z1),WHITE)
        box('Window_mullion',(x+1.98,front-.07,z0+.72),(x+2.02,front+.01,z1-.35),INK)
# Rear/side outer shell above interior ceiling prevents sky gaps.
for x in [-23,25]:box('High_side_wall',(x-.08,front,TOP),(x+.08,17.5,17.6),WHITE)
box('High_rear_wall',(-23,17.4,TOP),(25,17.56,17.6),WHITE)
box('Roof',(-23.2,front-.2,17.6),(25.2,17.6,17.8),(.39,.39,.36,1))
for z in [17.2,17.45,17.7]:box('Cornice',(-12.3,front-.42,z),(20.3,front+.12,z+.1),WHITE)
text('Street_address','47-10   47-16',(0,front-.20,3.7),.24,WHITE)
# Adjacent near dark block uses a distinct cadence/material instead of pastel houses.
def frontage(name,x0,x1,y,h,levels,color,faces_street=True):
    # Neighbour frontage is scenery, with enough depth to hide map edges.
    sign=-1 if faces_street else 1
    back=y-sign*10
    hollow=name.startswith('Near_')
    if not hollow:box(name+'_mass',(x0,min(y,back),0),(x1,max(y,back),h),color)
    bays=max(1,round((x1-x0)/3.5));bw=(x1-x0)/bays
    fh=h/levels
    for level in range(levels):
        z=level*fh+.8
        if hollow:box(name+'_spandrel',(x0,y-.14,level*fh),(x1,y+.02,z),color)
        for i in range(bays):
            a=x0+i*bw+.18;b=x0+(i+1)*bw-.18
            yy=y+sign*.025
            glazing_y(name+'_window',yy,a,b,z,min(z+fh-1.05,h-.25),GLASS if hollow and level<2 else (.16,.26,.31,1))
            for zz in [z+.8,z+1.6]:box(name+'_crossbar',(a,yy-.035,zz),(b,yy+.035,zz+.035),INK)
            box(name+'_mullion',((a+b)/2-.02,yy-.04,z),((a+b)/2+.02,yy+.04,min(z+fh-1.05,h-.25)),INK)
            box(name+'_pier',(a-.18,y-.08,level*fh),(a-.04,y+.08,(level+1)*fh),color)
frontage('Near_dark_industrial',-51,-12.2,front,17.5,4,(.16,.17,.17,1))
frontage('Near_white_neighbor',20.2,52,front,17.5,4,(.67,.65,.59,1))
current='Exterior_Opposite'
frontage('Opposite_white_factory',-48,38,-24,18,4,(.71,.70,.64,1),False)
# Distinct glazed roof pavilion seen on opposite building.
box('Opposite_roof_pavilion',(-43,-31,18),(29,-25.5,21.0),(.10,.19,.22,1))
for x in range(-43,30,3):glazing_y('Pavilion_glass',-25.45,x,x+2.95,18.1,20.9,(.22,.34,.38,1))
frontage('Opposite_end_block',38.1,55,-24,12.2,3,(.36,.28,.23,1),False)
# Neighbour viewed through upper landing end window.
frontage('Rear_court_facade',-6,15,23.5,16,4,(.58,.53,.46,1),True)

current='Streetscape'
floor('Ground_plane',-120,-100,120,80,-.32,(.21,.21,.20,1))
floor('Asphalt',-65,-22,65,-8.3,-.20,(.12,.13,.14,1))
floor('Near_sidewalk',-55,-8.3,55,-4.75,0,(.50,.50,.46,1))
floor('Far_sidewalk',-55,-24,55,-22,0,(.50,.50,.46,1))
for x in range(-54,55,3):box('Sidewalk_joint',(x-.012,-8.3,.001),(x+.012,-4.75,.004),(.34,.35,.33,1))
# Street trees use simple branching crowns and contact-ground planters.
for x in [-39,-26,-14,9,24,39]:
    y=-22.7
    box('Tree_bed',(x-.65,y-.55,.01),(x+.65,y+.55,.07),(.24,.20,.13,1))
    cyl('Street_tree_trunk',(x,y,1.6),.10,3.2,(.24,.17,.10,1))
    for i in range(5):
        angle=i*math.tau/5
        tip=(x+math.cos(angle)*.65,y+math.sin(angle)*.6,3.2+.2*(i%2))
        beam('Street_tree_branch',(x,y,2.2),tip,.045,(.24,.17,.10,1))
        crown=cyl('Street_tree_crown',tip,.85,1.5,(.23,.32,.11,1),9)
# Static parked cars: readable silhouettes, not new driveable gameplay.
for i,x in enumerate([-33,-20,-8,5,18,31,43]):
    y=-21.0 if i%2 else -9.5
    color=[(.12,.14,.17,1),(.62,.63,.61,1),(.22,.26,.29,1)][i%3]
    box('Parked_car_body',(x-1.9,y-.8,.10),(x+1.9,y+.8,.72),color)
    box('Parked_car_cabin',(x-.95,y-.7,.72),(x+1.1,y+.7,1.37),(.08,.14,.17,1))
    for dx in [-1.25,1.25]:
        for dy in [-.78,.78]:
            wheel=cyl('Car_wheel',(x+dx,y+dy,.15),.32,.16,INK,12);wheel.rotation_euler.x=math.pi/2
# Place the upstairs room plan with the photo's handedness. Structural surfaces
# may be reflected and rebaked, but retained classroom objects receive a proper
# rigid rotation, never a reflection or a negative/non-uniform object scale.
bpy.context.view_layer.update()
reflection=Matrix(((-1,0,0,3),(0,1,0,0),(0,0,1,0),(0,0,0,1)))
local_reflection=Matrix.Diagonal((-1,1,1,1))
classroom_rigid=Matrix.Translation((3,.8,0)) @ Matrix.Rotation(math.pi,4,'Z')
room_ids={'Reception','Classroom','Small_Room','Larger_Room','Internal_Hall','Commons','Side_Workspace'}
circulation_prefixes=('External_corridor_','External_glass_return','Restroom_','Structural_column','Silver_main_duct','Duct_joint','Sprinkler_','Pendant_light','Light_suspension')
mirrored_meshes={}
for ob in list(scene.objects):
    ident=ob.get('module_id','')
    if ob.type not in ('MESH','FONT'):continue
    if ident not in room_ids and not (ident=='Upper_Circulation' and ob.name.startswith(circulation_prefixes)):continue
    if ob.get('retained_source_kind')=='classroom':
        ob.matrix_world=classroom_rigid @ ob.matrix_world
    else:
        # Bake the reflection into this object's geometry; reverse winding once.
        # Preserve shared originals used by unreflected objects.
        world=ob.matrix_world.copy()
        ob.matrix_world=reflection @ world @ local_reflection
        if ob.type=='FONT':continue  # readable glyphs use the proper rotation
        source_data=ob.data;identity=source_data.as_pointer()
        if identity not in mirrored_meshes:
            data=source_data.copy();data.transform(local_reflection)
            import bmesh
            bm=bmesh.new();bm.from_mesh(data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
            data.update();mirrored_meshes[identity]=data
        ob.data=mirrored_meshes[identity]
for exception in LAYOUT.get('placement_exceptions',[]):
    move=Matrix.Translation(Vector(exception['to'])) @ Matrix.Rotation(math.radians(exception['rotation_z_degrees']),4,'Z') @ Matrix.Translation(-Vector(exception['from']))
    for name in exception['names']:
        ob=bpy.data.objects[name];ob.matrix_world=move @ ob.matrix_world
        ob['placement_exception']=exception['reason']
# Anchor empties are export-visible and include roles, avoiding guessed attachment.
for name,position in LAYOUT['anchors'].items():
    ident='Ground_Core' if position[2]<1 else 'Upper_Circulation'
    ob=bpy.data.objects.new('ANCHOR_'+name,None);collections[ident].objects.link(ob);ob.parent=modules[ident]
    ob.location=Vector(position)-Vector(LAYOUT_MODULE_ORIGINS[ident]);ob['anchor_id']=name
# Helpful collections are Blender assets; the exported assembly retains parent roots.
for ident,col in collections.items():
    col.asset_mark();col.asset_data.description='Pursuit module; estimated scale; reference photos '+col['reference_photos']
scene['assembly_manifest_sha256']=hashlib.sha256(LAYOUT_PATH.read_bytes()).hexdigest()
# Ensure no inherited path metadata or unrelated linked images survives.
for keyname in list(scene.keys()):
    if keyname!='assembly_manifest_sha256': del scene[keyname]
for image in bpy.data.images:
    if image.has_data and not image.packed_file:image.pack()
# Native review cameras preserve the exported assembly's spatial context.
for name,eye,target in [
    ('Exterior',(15,-19,2),(-2,-4.75,8.5)),
    ('Reception',(5.8,3.8,6.7),(-1.2,6.3,6.5)),
    ('Commons',(23,-1.5,6.7),(14.5,7,6.5)),
    ('Ground',(0,-3.5,1.65),(0,5,2.4))]:
    data=bpy.data.cameras.new(name);data.lens=22
    camera=bpy.data.objects.new('CAM_'+name,data);scene.collection.objects.link(camera)
    camera.location=eye;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    if name=='Exterior':scene.camera=camera
# Presentation camera/light are native-only; exported game geometry has no camera.
world=bpy.data.worlds.new('Environment');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.8,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6
light=bpy.data.lights.new('Sun','SUN');light.energy=2.5
sun=bpy.data.objects.new('Sun',light);scene.collection.objects.link(sun);sun.rotation_euler=(.5,-.5,-.4)
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
bpy.context.view_layer.update()
blend=OUT/'Pursuit Photo Redesign.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
for ob in scene.objects:
    if ob.type in ('MESH','FONT','EMPTY'):ob.select_set(True)
# Convert texts for a portable export; save master before this temporary conversion.
for ob in list(bpy.context.selected_objects):
    if ob.type=='FONT':
        bpy.context.view_layer.objects.active=ob;bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.ops.object.convert(target='MESH')
bpy.ops.object.select_all(action='DESELECT')
for ob in scene.objects:
    if ob.type in ('MESH','EMPTY'):ob.select_set(True)
glb=OUT/'pursuit-building.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False)
receipt={'schema':2,'blender':bpy.app.version_string,'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'manifest_sha256':hashlib.sha256(LAYOUT_PATH.read_bytes()).hexdigest(),'retained_meshes':len(kept),'modules':list(modules),'meshes':len([o for o in scene.objects if o.type=='MESH'])}
(OUT/'assembly-receipt.json').write_text(json.dumps(receipt,indent=2))
print('PHOTO_ENVIRONMENT_COMPLETE',json.dumps(receipt))
