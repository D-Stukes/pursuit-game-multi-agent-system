"""Rebuild the photo-reference environment in Blender; imported props stay separate.

Run with Blender --background --python tools/build_environment.py -- --output-dir ...
The manifest is the assembly contract. Native masters and images stay outside Git.
"""
import argparse, hashlib, json, math, subprocess, sys
from pathlib import Path
import bpy
from types import SimpleNamespace
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from environment_inputs import load_source_selection
LAYOUT_PATH = ROOT / 'godot/assets/building-layout.json'
LAYOUT_BYTES = LAYOUT_PATH.read_bytes()
LAYOUT = json.loads(LAYOUT_BYTES.decode('utf-8-sig'))
MANIFEST_SHA = hashlib.sha256(LAYOUT_BYTES).hexdigest()
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
selection=load_source_selection(ROOT,LAYOUT)

root=bpy.data.objects.new('Pursuit_Assembly',None); scene.collection.objects.link(root)
root['assembly_schema']=2; root['units']='metres'; root['source_sha256']=LAYOUT['source']['sha256']
root['dimensions']='Approved blueprint topology; dimensions estimated, not surveyed'
for item in LAYOUT['modules']:
    col=bpy.data.collections.new(item['id']); scene.collection.children.link(col)
    col.instance_offset=item['origin']; col['reference_photos']=','.join('IMG_'+str(n) for n in item['photos'])
    module=bpy.data.objects.new(item['id']+'_ROOT',None); col.objects.link(module)
    module.parent=root; module.location=item['origin']; module['module_id']=item['id']
    modules[item['id']]=module; collections[item['id']]=col
# Floor roots are explicit stacking references; vertical core remains independent.
for floor_name,height,ids in [
 ('Floor_Street',0,[item['id'] for item in LAYOUT['modules'] if item.get('level')=='street']),
 ('Floor_Upper',F,[item['id'] for item in LAYOUT['modules'] if item.get('level')=='upper'])]:
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
    if kind not in ('ground','bank','bank_trim','classroom','ground_furnishings'):continue
    if item['name'].startswith(('Left area west skirting','Left area north skirting','Left area south skirting','Left area suspended light','Left area light','Ground black bank base')):continue
    ob=exact_lookup.get(item['name']) or lookup.get(key(item['name']))
    assert ob is not None, item['name']
    ob.matrix_world=Matrix.Translation(Vector(item['delta'])) @ ob.matrix_world
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
    ob=mesh_object(name,verts,faces,color)
    for polygon in ob.data.polygons:polygon.use_smooth=polygon.index>=2
    ob.location=Vector(at)-Vector(LAYOUT_MODULE_ORIGINS[current]);return ob

def beam(name,a,b,r,color=STEEL):
    a,b=Vector(a),Vector(b);ob=cyl(name,(a+b)/2,r,(b-a).length,color,10)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return ob

def ellipsoid(name,at,radii,color):
    verts=[];faces=[];rings=10;segments=16
    for j in range(rings+1):
        phi=-math.pi/2+j*math.pi/rings
        for i in range(segments):
            theta=i*math.tau/segments
            verts.append((radii[0]*math.cos(phi)*math.cos(theta),radii[1]*math.cos(phi)*math.sin(theta),radii[2]*math.sin(phi)))
    for j in range(rings):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    ob=mesh_object(name,verts,faces,color)
    ob.location=Vector(at)-Vector(LAYOUT_MODULE_ORIGINS[current])
    for polygon in ob.data.polygons:polygon.use_smooth=True
    return ob

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
def glazing_x(name,x,y0,y1,z0,z1,color=GLASS):
    box(name+'_glass',(x-.025,y0,z0),(x+.025,y1,z1),color)
    for z in [z0,z1]:box(name+'_rail',(x-.045,y0,z-.025),(x+.045,y1,z+.025),STEEL)
    for y in [y0,y1]:box(name+'_jamb',(x-.045,y-.025,z0),(x+.045,y+.025,z1),STEEL)

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

def framed(frame,factory):
    """Construct one part directly in an explicit assembly frame."""
    def create(*args,**kwargs):
        ob=factory(*args,**kwargs)
        bpy.context.view_layer.update()
        ob.matrix_world=frame @ ob.matrix_world
        return ob
    return create

def sofa(name,x,y,w=2,z=F,color=GREY,heading=0):
    create=box
    if heading:
        frame=Matrix.Translation((x,y,0)) @ Matrix.Rotation(heading,4,'Z') @ Matrix.Translation((-x,-y,0))
        create=framed(frame,box)
    create(name+'_base',(x-w/2,y-.42,z+.12),(x+w/2,y+.42,z+.46),color)
    for dx in (-w/2+.15,w/2-.15):
        for dy in (-.28,.28):
            create(name+'_foot',(x+dx-.05,y+dy-.05,z),(x+dx+.05,y+dy+.05,z+.14),INK)
    create(name+'_back',(x-w/2,y+.3,z+.46),(x+w/2,y+.46,z+.9),color)
    for dx in [-w/2,w/2]:create(name+'_arm',(x+dx-.08,y-.42,z+.28),(x+dx+.08,y+.42,z+.72),color)
    for dx in [-w*.32,w*.32]:create(name+'_cushion',(x+dx-.22,y-.05,z+.48),(x+dx+.22,y+.28,z+.72),(.55,.57,.25,1))

def plant(name,x,y,z=F):
    cyl(name+'_pot',(x,y,z+.25),.23,.5,(.61,.57,.44,1))
    for i in range(7):
        angle=i*math.tau/7
        beam(name+'_stem',(x,y,z+.4),(x+.18*math.cos(angle),y+.18*math.sin(angle),z+.85+.1*(i%3)),.018,(.10,.22,.065,1))
        ob=cyl(name+'_leaf',(x+.2*math.cos(angle),y+.2*math.sin(angle),z+.85+.1*(i%3)),.11,.035,(.13,.30,.08,1),8)
        ob.rotation_euler=(.5*math.cos(angle),.5*math.sin(angle),angle)

def egg_chair(name,x,y,z=F):
    verts=[];faces=[];rings=16;segments=24
    for j in range(rings+1):
        phi=-1.1+j*2.6/rings
        for i in range(segments+1):
            theta=i*math.pi/segments
            verts.append((.48*math.cos(phi)*math.cos(theta),.43*math.cos(phi)*math.sin(theta),.78*math.sin(phi)))
    for j in range(rings):
        for i in range(segments):
            a=j*(segments+1)+i;faces.append((a,a+1,a+segments+2,a+segments+1))
    shell=mesh_object(name+'_shell',verts,faces,GREY)
    shell.location=Vector((x,y,z+.95))-Vector(LAYOUT_MODULE_ORIGINS[current])
    modifier=shell.modifiers.new('Upholstery_shell','SOLIDIFY');modifier.thickness=.055
    for face in shell.data.polygons:face.use_smooth=True
    box(name+'_cushion',(x-.35,y-.23,z+.47),(x+.35,y+.23,z+.61),(.28,.27,.22,1))
    cyl(name+'_pedestal',(x,y,z+.23),.045,.46,STEEL)
    cyl(name+'_base',(x,y,z+.035),.34,.07,STEEL)

# The approved blueprint owns room connections; photos supply finishes.
def set_module(ident):
    global current
    current=ident

sys.path.insert(0,str(ROOT/'tools'))
from environment_blueprint import build_blueprint
builders=SimpleNamespace(box=box,floor=floor,wallx=wallx,wally=wally,
    cyl=cyl,beam=beam,text=text,glazing_x=glazing_x,glazing_y=glazing_y,
    table=table,chair=chair,sofa=sofa,plant=plant,egg_chair=egg_chair,framed=framed)
build_blueprint(LAYOUT,builders,set_module)

# One owner for the closed, photo-derived facade and scenery shells.
sys.path.insert(0,str(ROOT/'tools'))
from environment_facades import build_facades

build_facades(LAYOUT,box,glazing_y,text,beam,set_module)
from environment_streets import build_street_extensions
build_street_extensions(LAYOUT,box,floor,text,set_module)

current='Streetscape'
floor('Ground_plane',-120,-100,120,80,-.32,(.21,.21,.20,1))
floor('Asphalt',-65,-22,65,-8.3,-.20,(.12,.13,.14,1))
floor('Near_sidewalk',-55,-8.3,55,-4.75,0,(.50,.50,.46,1))
floor('Far_sidewalk',-55,-24,55,-22,0,(.50,.50,.46,1))
for x in range(-54,55,3):box('Sidewalk_joint',(x-.012,-8.3,.001),(x+.012,-4.75,.004),(.34,.35,.33,1))
for y in [-8.3,-22]:box('Continuous_curb',(-55,y-.09,-.22),(55,y+.09,.012),(.45,.45,.42,1))
# Layered rounded foliage follows the photographed mature street trees. Repeated
# crown meshes share data; branches connect continuously to trunk and foliage.
for x,y in [(x,y) for x in [-39,-26,-14,9,24,39] for y in [-22.7,-7.4]]:
    box('Tree_bed',(x-.65,y-.55,.01),(x+.65,y+.55,.07),(.24,.20,.13,1))
    cyl('Street_tree_trunk',(x,y,1.6),.10,3.2,(.24,.17,.10,1))
    for i in range(5):
        angle=i*math.tau/5
        tip=(x+math.cos(angle)*.80,y+math.sin(angle)*.72,3.6+.25*(i%2))
        beam('Street_tree_branch',(x,y,2.2),tip,.045,(.24,.17,.10,1))
        ellipsoid('Street_tree_crown',tip,(1.15,.98,.85),[(.20,.27,.07,1),(.29,.34,.10,1),(.35,.31,.075,1)][i%3])
    ellipsoid('Street_tree_top',(x,y,4.3),(1.15,1.0,.8),(.26,.32,.085,1))
# Static parked cars: readable silhouettes, not new driveable gameplay.
for i,x in enumerate([-33,-24,-8,5,22.5,31,43]):
    y=-21.0 if i%2 else -9.5
    color=[(.12,.14,.17,1),(.62,.63,.61,1),(.22,.26,.29,1)][i%3]
    body=box('Parked_car_body',(x-1.9,y-.8,.07),(x+1.9,y+.8,.72),color)
    bevel=body.modifiers.new('Rounded_bodywork','BEVEL');bevel.width=.18;bevel.segments=3
    # Sloped windscreen/rear window and painted roof, not a floating cabin cube.
    verts=[(-1.1,-.71,.70),(-1.1,.71,.70),(1.18,.71,.70),(1.18,-.71,.70),
           (-.65,-.57,1.35),(-.65,.57,1.35),(.72,.57,1.35),(.72,-.57,1.35)]
    cabin_faces=[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
    cabin=mesh_object('Parked_car_cabin',verts,[tuple(reversed(face)) for face in cabin_faces],(.045,.075,.085,1))
    cabin.location=Vector((x,y,0))-Vector(LAYOUT_MODULE_ORIGINS[current])
    box('Car_roof',(x-.66,y-.59,1.34),(x+.73,y+.59,1.39),color)
    for dy in [-.72,.72]:
        beam('Car_window_pillar',(x+.04,y+dy,.71),(x+.04,y+dy*.80,1.35),.025,color)
        box('Car_door_handle',(x+.45,y+dy*1.12,.61),(x+.65,y+dy*1.12+.015,.64),STEEL)
    for dx in [-1.91,1.86]:
        for dy in [-.55,.55]:box('Car_lamp',(x+dx,y+dy-.12,.39),(x+dx+.05,y+dy+.12,.51),(.8,.78,.65,1) if dx<0 else RED)
    for dx in [-1.25,1.25]:
        for dy in [-.78,.78]:
            wheel=cyl('Car_wheel',(x+dx,y+dy,.12),.32,.16,INK,24);wheel.rotation_euler.x=math.pi/2
            hub=cyl('Car_hub',(x+dx,y+dy*1.12,.12),.17,.018,STEEL,16);hub.rotation_euler.x=math.pi/2
# The bank and ground core keep their source coordinates. Classroom props use
# the declared proper rigid placement, never a reflected/non-uniform fit.
classroom_placement=LAYOUT['recipe_plan_transform']
classroom_rigid=(Matrix.Translation(Vector(classroom_placement['classroom_translation'])) @
    Matrix.Rotation(math.radians(classroom_placement['classroom_rotation_z_degrees']),4,'Z'))
for ob in list(scene.objects):
    if ob.get('retained_source_kind')=='classroom':
        ob.matrix_world=classroom_rigid @ ob.matrix_world
        groups=[group for group in LAYOUT.get('classroom_assemblies',[])
                if any(ob.name.startswith(prefix) for prefix in group['prefixes'])]
        assert len(groups)<=1, 'Overlapping classroom assembly membership: '+ob.name
        if groups:
            ob.matrix_world=Matrix.Translation(Vector(groups[0]['translation'])) @ ob.matrix_world
            ob['placement_assembly']=groups[0]['id']
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
scene['assembly_manifest_sha256']=MANIFEST_SHA
# Ensure no inherited path metadata or unrelated linked images survives.
for keyname in list(scene.keys()):
    if keyname!='assembly_manifest_sha256': del scene[keyname]
for image in bpy.data.images:
    if image.has_data and not image.packed_file:image.pack()
# Small manufactured edge radii give furniture readable highlights. Retained
# classroom meshes are protected; walls and tiny architectural seams stay exact.
bpy.context.view_layer.update()
for ob in scene.objects:
    if ob.type!='MESH' or ob.get('retained_source_kind'):continue
    if ob.name.startswith(('Reception_counter','Commons_couch','Commons_armchair','Commons_coffee',
        'Kitchen_base','Kitchen_upper','Kitchen_worktop','Island_top','Fridge',
        'Microwave','Commons_dining_table','Window_worktable')):
        bevel=ob.modifiers.new('Manufactured_edge_radius','BEVEL')
        bevel.width=min(.025,min(ob.dimensions)*.2);bevel.segments=3
        normal=ob.modifiers.new('Face_normals','WEIGHTED_NORMAL');normal.keep_sharp=True
# Native review cameras preserve the exported assembly's spatial context.
for view in LAYOUT['review_views']:
    data=bpy.data.cameras.new(view['id']);data.sensor_fit='HORIZONTAL'
    data.lens=36/(2*math.tan(math.radians(view.get('fov',72))/2)*(16/9))
    camera=bpy.data.objects.new('CAM_'+view['id'],data);scene.collection.objects.link(camera)
    camera.location=view['position']
    camera.rotation_euler=(Vector(view['target'])-camera.location).to_track_quat('-Z','Y').to_euler()
    if view['id']=='main-facade':scene.camera=camera
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
assert hashlib.sha256(LAYOUT_PATH.read_bytes()).hexdigest()==MANIFEST_SHA, 'Manifest changed during build; rebuild the candidate'
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
receipt={'schema':2,'blender':bpy.app.version_string,'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'manifest_sha256':MANIFEST_SHA,'retained_meshes':sum(bool(o.get('retained_source_kind')) for o in scene.objects if o.type=='MESH'),'modules':list(modules),'meshes':len([o for o in scene.objects if o.type=='MESH'])}
receipt['blueprint_sha256']=LAYOUT['blueprint']['reference_sha256']
receipt['commons_recipe_sha256']=hashlib.sha256((ROOT/'tools/environment_commons.py').read_bytes()).hexdigest()
(OUT/'assembly-receipt.json').write_text(json.dumps(receipt,indent=2))
print('PHOTO_ENVIRONMENT_COMPLETE',json.dumps(receipt))
