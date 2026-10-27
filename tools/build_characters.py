"""Author Pursuit character masters and portable exports with installed Blender.

Original geometry, based on the three user-supplied October 27 character images.
Native masters/studio proofs stay in Creative; only runtime assets enter Git.
"""
import argparse
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

P=argparse.ArgumentParser(description=__doc__)
P.add_argument('--asset',choices=['mr-p'],required=True)
P.add_argument('--output-dir',type=Path,required=True)
P.add_argument('--render',action='store_true')
ARGS=P.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT=ARGS.output_dir.resolve();OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
S=bpy.context.scene;S.unit_settings.system='METRIC';S.unit_settings.scale_length=1
S.render.fps=24;S.render.engine='BLENDER_EEVEE'
ASSET=bpy.data.collections.new('ASSET');S.collection.children.link(ASSET)
STUDIO=bpy.data.collections.new('STUDIO');S.collection.children.link(STUDIO)
MATS={};BIND={};CLIPS={}


def material(name,color,metal=0,rough=.4,emission=0):
    if name in MATS:return MATS[name]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    MATS[name]=m;return m


def register(ob,mat=None,bone=None,part=None):
    for c in list(ob.users_collection):c.objects.unlink(ob)
    ASSET.objects.link(ob)
    if mat:ob.data.materials.append(mat)
    if bone:BIND[ob.name]=bone
    if part:ob['part_id']=part
    return ob


def smooth(ob):
    if ob.type=='MESH':
        for p in ob.data.polygons:p.use_smooth=True
    return ob


def sphere(name,at,scale,mat,bone=None,segments=40,rings=24,part=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=at)
    ob=bpy.context.object;ob.name=name;ob.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return smooth(register(ob,mat,bone,part))


def mesh(name,verts,faces,mat,bone=None,part=None):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
    ob=bpy.data.objects.new(name,d);ASSET.objects.link(ob);d.materials.append(mat)
    if bone:BIND[name]=bone
    if part:ob['part_id']=part
    return smooth(ob)


def box(name,at,size,mat,bevel=.03,bone=None,part=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    ob=bpy.context.object;ob.name=name;ob.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    register(ob,mat,bone,part)
    if bevel:
        b=ob.modifiers.new('Rounded_edges','BEVEL');b.width=bevel;b.segments=3
        bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=b.name)
    return smooth(ob)


def tube(name,points,radii,mat,bone=None,res=10):
    # Catmull-Rom stations with an explicit radius and stable cross sections.
    ps=[Vector(p) for p in points];samples=[]
    for i in range(len(ps)-1):
        a,b,c,d=ps[max(0,i-1)],ps[i],ps[i+1],ps[min(len(ps)-1,i+2)]
        steps=8 if len(ps)<12 else 1
        for j in range(steps):
            t=j/steps
            pos=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
            r=radii[i]*(1-t)+radii[i+1]*t;samples.append((pos,r))
    samples.append((ps[-1],radii[-1]));verts=[]
    for i,(p,r) in enumerate(samples):
        tangent=samples[min(i+1,len(samples)-1)][0]-samples[max(0,i-1)][0]
        tangent.normalize();ref=Vector((0,1,0))
        if abs(tangent.dot(ref))>.95:ref=Vector((1,0,0))
        u=tangent.cross(ref).normalized();v=tangent.cross(u).normalized()
        for j in range(res):verts.append(p+r*(u*math.cos(j*math.tau/res)+v*math.sin(j*math.tau/res)))
    faces=[]
    for i in range(len(samples)-1):
        for j in range(res):
            a=i*res+j;b=i*res+(j+1)%res;faces.append((a,b,b+res,a+res))
    faces.extend([tuple(reversed(range(res))),tuple((len(samples)-1)*res+j for j in range(res))])
    return mesh(name,verts,faces,mat,bone)


def rig(name,bones):
    data=bpy.data.armatures.new(name);ob=bpy.data.objects.new(name,data);ASSET.objects.link(ob)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for ident,head,tail,parent in bones:
        b=data.edit_bones.new(ident);b.head=head;b.tail=tail;b.align_roll(Vector((0,-1,0)))
        if parent:b.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');ob.show_in_front=True
    for p in ob.pose.bones:p.rotation_mode='XYZ'
    return ob


def bind(ob,arm,bone):
    ob.parent=arm
    if isinstance(bone,str):
        g=ob.vertex_groups.new(name=bone);g.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    else:
        groups={b:ob.vertex_groups.new(name=b) for b in arm.data.bones.keys()}
        for v in ob.data.vertices:
            for name,weight in bone(ob.matrix_world @ v.co).items():
                if weight>0:groups[name].add([v.index],weight,'REPLACE')
    mod=ob.modifiers.new('Character_skin','ARMATURE');mod.object=arm


def add_clip(arm,name,length,pose):
    action=bpy.data.actions.new(name);action.use_fake_user=True;arm.animation_data_create();arm.animation_data.action=action
    for frame in range(1,length+1,3):
        t=(frame-1)/(length-1)
        for p in arm.pose.bones:p.location=(0,0,0);p.rotation_euler=(0,0,0)
        pose(arm,t)
        for p in arm.pose.bones:
            p.keyframe_insert('location',frame=frame,group=p.name);p.keyframe_insert('rotation_euler',frame=frame,group=p.name)
    # Identical endpoint makes the idle seam explicit rather than relying on wrap.
    pose(arm,1)
    for p in arm.pose.bones:
        p.keyframe_insert('location',frame=length,group=p.name);p.keyframe_insert('rotation_euler',frame=length,group=p.name)
    track=arm.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,action);strip.action_frame_start=1;strip.action_frame_end=length
    track.mute=name!='Idle';CLIPS[name]=length;arm.animation_data.action=None


def mr_p():
    skin=material('MrP_Purple',(.15,.045,.27),rough=.53)
    lip=material('MrP_Lip',(.20,.065,.32),rough=.48)
    black=material('MrP_Black',(.014,.011,.022),rough=.44)
    band=material('Hat_Satin_Purple',(.18,.025,.30),metal=.17,rough=.27)
    gold=material('Eyes_Yellow',(.78,.67,.24),rough=.3)
    pupil=material('Pupils',(.006,.009,.008),rough=.18)
    teeth=material('Ivory_Teeth',(.83,.84,.79),rough=.28)
    cavity=material('Mouth_Cavity',(.027,.006,.035),rough=.85)
    # Continuous loft with a pointed S tail; no stacked spheres down the silhouette.
    stations=[(.10,.01,.007),(.25,.08,.025),(.42,-.02,.05),(.59,-.20,.075),(.78,-.12,.10),(.96,.18,.14),(1.14,.25,.17),(1.34,.13,.22),(1.55,.02,.30),(1.79,0,.35),(1.99,0,.31),(2.14,0,.19),(2.23,0,.13)]
    verts=[];faces=[];rings=72;segments=40
    for j in range(rings+1):
        z=.10+j*(2.23-.10)/rings
        k=next((i for i in range(len(stations)-1) if stations[i][0]<=z<=stations[i+1][0]),len(stations)-2)
        a,b=stations[k],stations[k+1];t=(z-a[0])/(b[0]-a[0])
        before=stations[max(k-1,0)];after=stations[min(k+2,len(stations)-1)]
        def interpolate(component):
            span=b[0]-a[0]
            ma=(b[component]-before[component])/(b[0]-before[0])*span
            mb=(after[component]-a[component])/(after[0]-a[0])*span
            return (2*t**3-3*t*t+1)*a[component]+(t**3-2*t*t+t)*ma+(-2*t**3+3*t*t)*b[component]+(t**3-t*t)*mb
        x=interpolate(1);r=max(.005,interpolate(2))
        for i in range(segments):
            angle=i*math.tau/segments
            depth=.16*math.sin(math.tau*z/1.2)*min(1,max(0,(1.6-z)/.7))
            verts.append((x+r*math.cos(angle),depth+.70*r*math.sin(angle),z))
    for j in range(rings):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
    faces.extend([tuple(reversed(range(segments))),tuple(rings*segments+i for i in range(segments))])
    body=mesh('MrP_Body',verts,faces,skin);skin_parts=[body]
    for side,label in [(1,'L'),(-1,'R')]:
        arm=tube('Arm_'+label,[(side*.10,0,2.02),(side*.36,0,2.035),(side*.64,-.01,2.01),(side*.85,-.02,2.0)],[.17,.135,.085,.065],skin,res=14);skin_parts.append(arm)
        skin_parts.append(sphere('Shoulder_transition_'+label,(side*.26,0,2.025),(.18,.14,.16),skin))
        skin_parts.append(sphere('Palm_'+label,(side*.91,-.025,2.0),(.10,.057,.08),skin))
        for finger,z in enumerate([-.055,-.018,.022,.06]):
            length=[.095,.14,.15,.115][finger]
            skin_parts.append(tube('Finger_'+label+str(finger),[(side*.96,-.025,2+z),(side*(1.00+length*.5),-.035,2+z*1.15),(side*(.98+length),-.025,2+z*1.3)],[.023,.020,.012],skin,res=8))
        skin_parts.append(tube('Thumb_'+label,[(side*.88,-.05,1.965),(side*.91,-.09,1.90),(side*.96,-.10,1.91)],[.035,.025,.012],skin,res=8))
    # Voxel union removes intersections at shoulders/fingers; smooth + decimate
    # produces one deforming surface. Its actual bends are verified downstream.
    bpy.ops.object.select_all(action='DESELECT')
    for ob in skin_parts:ob.select_set(True)
    bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
    remesh=body.modifiers.new('Unified_skin','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.013
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    sm=body.modifiers.new('Skin_relax','SMOOTH');sm.factor=.8;sm.iterations=8;bpy.ops.object.modifier_apply(modifier=sm.name)
    dec=body.modifiers.new('Runtime_density','DECIMATE');dec.ratio=.38;bpy.ops.object.modifier_apply(modifier=dec.name);smooth(body)
    # The sub-voxel tail tip can leave tiny disconnected sampling islands.
    # Keep the single connected character surface, never detached voxel debris.
    bm=bmesh.new();bm.from_mesh(body.data);seen=set();components=[]
    for vertex in bm.verts:
        if vertex in seen:continue
        todo=[vertex];seen.add(vertex);component=[]
        while todo:
            a=todo.pop();component.append(a)
            for edge in a.link_edges:
                b=edge.other_vert(a)
                if b not in seen:seen.add(b);todo.append(b)
        components.append(component)
    for component in sorted(components,key=len,reverse=True)[1:]:bmesh.ops.delete(bm,geom=component,context='VERTS')
    bm.to_mesh(body.data);bm.free()
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
    head=sphere('MrP_Head',(0,0,2.59),(.43,.32,.445),skin,'head',segments=48,rings=32)
    head_parts=[head]
    # Sculpted cheek mass and nose support the grin/moustache, rather than a flat decal.
    for side in [-1,1]:head_parts.append(sphere('Cheek_'+str(side),(side*.24,-.195,2.43),(.18,.14,.18),skin))
    head_parts.append(sphere('Supported_jaw_chin',(0,-.15,2.30),(.29,.23,.18),skin))
    head_parts.append(sphere('Nose',(0,-.315,2.57),(.080,.105,.100),skin))
    for side in [-1,1]:head_parts.append(sphere('Nostril_wing_'+str(side),(side*.057,-.345,2.525),(.049,.055,.038),skin,segments=24,rings=16))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in head_parts:ob.select_set(True)
    bpy.context.view_layer.objects.active=head;bpy.ops.object.join()
    remesh=head.modifiers.new('Unified_face','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.009;bpy.ops.object.modifier_apply(modifier=remesh.name)
    sm=head.modifiers.new('Face_relax','SMOOTH');sm.factor=.8;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
    dec=head.modifiers.new('Face_density','DECIMATE');dec.ratio=.35;bpy.ops.object.modifier_apply(modifier=dec.name);smooth(head)
    cutter=sphere('Mouth_cutter',(0,-.29,2.375),(.285,.22,.125),cavity,segments=48,rings=24)
    bpy.context.view_layer.objects.active=head
    cut=head.modifiers.new('Actual_mouth_recess','BOOLEAN');cut.operation='DIFFERENCE';cut.object=cutter;bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    bpy.context.view_layer.objects.active=head;head.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
    sphere('Mouth_dark_interior',(0,-.13,2.375),(.265,.025,.12),cavity,'head')
    points=[(.29*math.cos(i*math.tau/48),-.25-.10*math.sin(i*math.tau/48)**2,2.375+.14*math.sin(i*math.tau/48)) for i in range(49)]
    tube('Grin_lip',points,[.022]*len(points),lip,'head',res=8)
    for row,z in enumerate([2.408,2.338]):
        for i in range(8):
            x=(i-3.5)*.057;y=-.32+1.6*x*x
            ob=box('Tooth_%d_%02d'%(row,i),(x,y,z+(.65 if row else .40)*x*x),(.052,.056,.066),teeth,.009,'head')
            ob.rotation_euler.z=-math.atan(3.2*x)
    for side,label in [(1,'L'),(-1,'R')]:
        sphere('Eye_'+label,(side*.165,-.210,2.675),(.112,.103,.119),gold,'head',segments=32,rings=20)
        sphere('Pupil_'+label,(side*.158,-.308,2.65),(.050,.024,.062),pupil,'head',segments=24,rings=16)
        sphere('Eye_glint_'+label,(side*.148-.012,-.332,2.676),(.010,.005,.012),teeth,'head',segments=12,rings=8)
        # Upper lid is a conforming curved surface; a morph closes it over the eye.
        vs=[];fs=[]
        for j in range(9):
            phi=.25+(math.pi/2-.25)*j/8
            for i in range(25):
                theta=-math.pi+i*math.pi/24
                vs.append((side*.165+.116*math.cos(phi)*math.cos(theta),-.210+.110*math.cos(phi)*math.sin(theta)-.018,2.675+.123*math.sin(phi)))
        for j in range(8):
            for i in range(24):
                a=j*25+i;fs.append((a,a+1,a+26,a+25))
        lid=mesh('Upper_lid_'+label,vs,fs,skin,'head');lid.shape_key_add(name='Basis');blink=lid.shape_key_add(name='Blink')
        for j in range(9):
            phi=-1.48+(math.pi/2+1.48)*j/8
            for i in range(25):
                theta=-math.pi+i*math.pi/24;blink.data[j*25+i].co=(side*.165+.116*math.cos(phi)*math.cos(theta),-.210+.110*math.cos(phi)*math.sin(theta)-.044,2.675+.123*math.sin(phi))
        data=lid.data.shape_keys;data.animation_data_create();action=bpy.data.actions.new('Blink_'+label);data.animation_data.action=action
        for f,value in [(1,0),(43,0),(46,1),(49,0),(96,0)]:blink.value=value;blink.keyframe_insert('value',frame=f)
        tr=data.animation_data.nla_tracks.new();tr.name='Idle';tr.strips.new('Idle',1,action);data.animation_data.action=None
        points=[]
        for x,z in [(.065,2.80),(.16,2.84),(.25,2.89),(.30,2.865)]:
            y=-.32*math.sqrt(max(.02,1-(x/.43)**2-((z-2.59)/.445)**2))-.012
            points.append((side*x,y,z))
        tube('Brow_'+label,points,[.024,.035,.025,.006],black,'head',res=10)
        points=[(side*.025,-.448,2.50),(side*.125,-.474,2.515),(side*.27,-.46,2.43),(side*.43,-.42,2.365),(side*.52,-.40,2.40),(side*.535,-.40,2.49),(side*.49,-.40,2.495)]
        tube('Curled_moustache_'+label,points,[.026,.047,.048,.034,.023,.013,.004],black,'head',res=12)
    # Removable hat shell/band retain separate materials and edit ownership.
    hat_objects=[]
    brim=sphere('Hat_brim',(0,.01,3.035),(.49,.34,.05),black,'head',segments=64,rings=16);hat_objects.append(brim)
    vv=[];ff=[];n=64
    for z,r in [(3.045,.275),(3.10,.28),(3.57,.335),(3.60,.33)]:
        for i in range(n):
            t=i*math.tau/n;vv.append((r*math.cos(t),r*.87*math.sin(t),z))
    for j in range(3):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;ff.append((a,b,b+n,a+n))
    ff.extend([tuple(reversed(range(n))),tuple(3*n+i for i in range(n))])
    hat_objects.append(mesh('Hat_crown',vv,ff,black,'head'))
    vv=[];ff=[]
    for z,r in [(3.08,.285),(3.18,.297)]:
        for i in range(n):t=i*math.tau/n;vv.append((r*math.cos(t),r*.87*math.sin(t),z))
    for i in range(n):a=i;b=(i+1)%n;ff.append((a,b,b+n,a+n))
    hat_objects.append(mesh('Hat_satin_band',vv,ff,band,'head'))
    for ob in hat_objects:ob['accessory_id']='top_hat'
    bones=[('root',(0,0,1.65),(0,0,1.80),None),('torso',(0,0,1.80),(0,0,2.17),'root'),('head',(0,0,2.17),(0,0,2.90),'torso'),
           ('tail_01',(0,0,1.65),(.22,0,1.15),'root'),('tail_02',(.22,0,1.15),(-.12,0,.76),'tail_01'),('tail_03',(-.12,0,.76),(.02,0,.40),'tail_02'),('tail_tip',(.02,0,.40),(.01,0,.10),'tail_03')]
    for side,label in [(1,'L'),(-1,'R')]:
        bones += [('upper_arm_'+label,(side*.27,0,2.05),(side*.62,-.01,2.01),'torso'),('forearm_'+label,(side*.62,-.01,2.01),(side*.86,-.02,2.0),'upper_arm_'+label),('hand_'+label,(side*.86,-.02,2),(side*1.07,-.02,2),'forearm_'+label)]
    arm=rig('MrP_Rig',bones)
    def weights(p):
        x,z=abs(p.x),p.z;label='L' if p.x>=0 else 'R'
        if x>.26 and z>1.72:
            vertical=min(1,max(0,(z-1.72)/.23));vertical=vertical*vertical*(3-2*vertical)
            shoulder=min(1,max(0,(x-.26)/.20));shoulder=shoulder*shoulder*(3-2*shoulder)
            amount=vertical*shoulder
            if x<.55:return {'torso':1-amount,'upper_arm_'+label:amount}
            if x<.69:
                w=(x-.55)/.14;return {'upper_arm_'+label:1-w,'forearm_'+label:w}
            if x<.82:return {'forearm_'+label:1}
            if x<.92:
                w=(x-.82)/.10;return {'forearm_'+label:1-w,'hand_'+label:w}
            return {'hand_'+label:1}
        if z>1.50:return {'torso':1}
        centers=[(1.48,'tail_01'),(.99,'tail_02'),(.58,'tail_03'),(.20,'tail_tip')]
        if z>=centers[0][0]:return {'tail_01':1}
        if z<=centers[-1][0]:return {'tail_tip':1}
        for (za,a),(zb,b) in zip(centers,centers[1:]):
            if zb<=z<=za:w=(za-z)/(za-zb);return {a:1-w,b:w}
        return {'tail_tip':1}
    bind(body,arm,weights)
    for name,bone in list(BIND.items()):
        ob=bpy.data.objects.get(name)
        if ob:bind(ob,arm,bone)
    def idle(a,t):
        a.pose.bones['root'].location.y=.035*math.sin(math.tau*t)
        a.pose.bones['head'].rotation_euler.y=.025*math.sin(math.tau*t)
        for side,label in [(1,'L'),(-1,'R')]:a.pose.bones['upper_arm_'+label].rotation_euler.z=-side*(.50+.035*math.sin(math.tau*t))
        for i,b in enumerate(['tail_01','tail_02','tail_03','tail_tip']):a.pose.bones[b].rotation_euler.y=.045*math.sin(math.tau*t+i*.5)
    def wave(a,t):
        idle(a,t);lift=math.sin(math.pi*t)**2
        a.pose.bones['upper_arm_L'].rotation_euler.z=-.5+1.4*lift
        a.pose.bones['forearm_L'].rotation_euler.z=.55*lift
        a.pose.bones['hand_L'].rotation_euler.x=.22*math.sin(t*math.tau*3)*lift
    def guide(a,t):
        idle(a,t);amount=math.sin(math.pi*t)
        a.pose.bones['upper_arm_R'].rotation_euler.z=.5-.72*amount
        a.pose.bones['forearm_R'].rotation_euler.z=-.25*amount
        a.pose.bones['head'].rotation_euler.z=-.08*amount
    add_clip(arm,'Idle',96,idle);add_clip(arm,'Welcome',72,wave);add_clip(arm,'Guide',72,guide)
    return arm


def studio(height):
    world=bpy.data.worlds.new('Studio_world');S.world=world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.25,.30,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35
    for name,loc,power,size in [('Key',(-3,-4,5.5),500,4),('Fill',(3,-2,3),260,3),('Rim',(1,3,4.5),650,3)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
        ob=bpy.data.objects.new(name,d);STUDIO.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,height*.6))-ob.location).to_track_quat('-Z','Y').to_euler()
    for name,eye in [('front',(0,-8,height*.52)),('profile',(8,0,height*.52)),('back',(0,8,height*.52)),('three-quarter',(5,-8,height*.65))]:
        d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=height*1.13
        ob=bpy.data.objects.new('CAM_'+name,d);STUDIO.objects.link(ob);ob.location=eye
        ob.rotation_euler=(Vector((0,0,height*.5))-ob.location).to_track_quat('-Z','Y').to_euler()
        if name=='front':S.camera=ob
    S.render.resolution_x=640;S.render.resolution_y=800;S.render.resolution_percentage=100
    S.render.image_settings.file_format='PNG';S.render.film_transparent=True;S.view_settings.view_transform='AgX'


start=time.monotonic();arm=mr_p();S.frame_start=1;S.frame_end=96;S.frame_set(1)
studio(3.65)
for ob in ASSET.objects:
    ob['asset_id']='mr_p';ob['authoring_front']='-Y';ob['units']='metres'
ASSET.asset_mark();ASSET.asset_data.description='Mr. P, original geometry from user character references; animation-ready source.'
native=OUT/'Mr P.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
# Export all named clips; presentation lights/cameras remain in the native master.
for track in arm.animation_data.nla_tracks:track.mute=False
bpy.ops.object.select_all(action='DESELECT')
for ob in ASSET.objects:ob.select_set(True)
export=OUT/'mr-p.glb'
bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_extras=True,export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_force_sampling=True)
for track in arm.animation_data.nla_tracks:track.mute=track.name!='Idle'
S.frame_set(1)
receipt={'asset':'mr_p','blender':bpy.app.version_string,'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(export.read_bytes()).hexdigest(),'clips':CLIPS,'bones':len(arm.data.bones),'method':'Original mesh lofts, sculpted/boolean facial volume, voxel-unified deforming body, named skeleton and keyframed actions','front':'Blender -Y / glTF +Z','units':'metres','reference':'User-supplied Dandy Jinn sheet and Mr. P portrait, October 27 conversation attachments','build_seconds':round(time.monotonic()-start,2)}
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('CHARACTER_EXPORTED',json.dumps(receipt))
if ARGS.render:
    for view in ['front','profile','three-quarter']:
        S.camera=bpy.data.objects['CAM_'+view];S.render.filepath=str(OUT/('mr-p-'+view+'.png'));bpy.ops.render.render(write_still=True)
