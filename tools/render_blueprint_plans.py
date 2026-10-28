"""Render actual saved geometry as labelled plan cutaways; never save changes.

Run Blender with the candidate .blend then --python this.py -- --output-dir ...
Labels and cutaway visibility exist only in these proof images.
"""
import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Vector

parser=argparse.ArgumentParser()
parser.add_argument('--output-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
args.output_dir.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
originals=list(scene.objects)
upper={c.name for c in bpy.data.collections if c.name not in
       ('Ground_Core','Lift_Banks','Exterior_Main','Exterior_Opposite','Streetscape')}
camera_data=bpy.data.cameras.new('PLAN_PROOF_CAMERA')
camera_data.type='ORTHO';camera_data.ortho_scale=52
camera=bpy.data.objects.new('PLAN_PROOF_CAMERA',camera_data)
scene.collection.objects.link(camera)
camera.location=(1,6.325,60);camera.rotation_euler=(0,0,0)
scene.camera=camera
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1800;scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
material=bpy.data.materials.new('PLAN_LABEL_INK')
material.diffuse_color=(.015,.035,.065,1)
material.use_nodes=True
nodes=material.node_tree.nodes;nodes.clear()
emission=nodes.new('ShaderNodeEmission')
emission.inputs['Color'].default_value=(.015,.035,.065,1)
output=nodes.new('ShaderNodeOutputMaterial')
material.node_tree.links.new(emission.outputs[0],output.inputs['Surface'])
for ob in scene.objects:
    if ob.type=='LIGHT':ob.data.use_shadow=False
labels=[]
for floor in ('ground','upper'):
    for ob in originals:
        if ob.type not in ('MESH','FONT'):continue
        module=ob.get('module_id','')
        low=min((ob.matrix_world @ Vector(corner)).z for corner in ob.bound_box)
        high=max((ob.matrix_world @ Vector(corner)).z for corner in ob.bound_box)
        allowed=(module=='Ground_Core' or (module=='Lift_Banks' and high<4.9)) if floor=='ground' else (module in upper or (module=='Lift_Banks' and low>4.8))
        overhead=any(t in ob.name.lower() for t in ('ceiling','pendant','duct','sprinkler','light suspension','light_suspension','diffuser','room_fire_main','plenum','upholstery'))
        ob.hide_render=not allowed or overhead or ob.type=='FONT'
    for ob in labels:bpy.data.objects.remove(ob,do_unlink=True)
    labels=[]
    positions=(
        [('LEFT ROOM',-14,10),('BROWN-DOOR\nL ROOM',-4.8,12.3),('ELEVATORS',-1,14.4),
         ('HALLWAY',2.4,9.2),('RAMP',2.4,1),('STAIRS',-.5,1),('RIGHT ROOM / BAKERY',13,11),('ONE ENTRANCE',0,-4)]
        if floor=='ground' else
        [('CLASSROOM',-5.3,.2),('RECEPTION',2,7.2),('SEPARATE ROOM',15,2),
         ('ADDITIONAL\nRECEPTION DOOR',5.65,1.8),('HALLWAY 2',-11,5.3),
         ('ROOM 1',-5.05,8),('ROOM 2',-2.55,8),('HALLWAY 1',-3.5,10),
         ('BATHROOMS',-4.35,14.2),('LANDING',2.4,14.4),('OTHER ROOM',14,13),('OPEN INDOOR AREA',-15,10.5)]
    )
    for value,x,y in positions:
        data=bpy.data.curves.new('PROOF_LABEL','FONT')
        data.body=value;data.size=.38 if len(value)>12 else .45
        data.align_x='CENTER';data.align_y='CENTER'
        ob=bpy.data.objects.new('PROOF_LABEL',data)
        scene.collection.objects.link(ob);data.materials.append(material)
        ob.location=(x,y,5.2 if floor=='ground' else 9.2)
        labels.append(ob)
    scene.render.filepath=str(args.output_dir/(floor+'-blueprint-plan.png'))
    bpy.ops.render.render(write_still=True)
    print('BLUEPRINT_PLAN_RENDERED',floor)
