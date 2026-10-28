"""Reopen a character master in Blender and check construction and motion."""
import bpy
import bmesh
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

folder=Path(bpy.data.filepath).parent
receipt=json.loads((folder/'receipt.json').read_text())
checks=[]


def check(name,ok,detail=''):
    checks.append({'check':name,'pass':bool(ok),'detail':str(detail)})
    print('PASS' if ok else 'FAIL',name,detail)


check('saved master matches receipt',hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==receipt['native_sha256'])
check('metre authoring',bpy.context.scene.unit_settings.scale_length==1)
check('no external libraries',not bpy.data.libraries)
check('no unpacked image dependencies',all(i.packed_file for i in bpy.data.images if i.has_data))
assets=list(bpy.data.collections['ASSET'].objects)
meshes=[o for o in assets if o.type=='MESH']
arm=next(o for o in assets if o.type=='ARMATURE')
check('declared skeleton bone count',len(arm.data.bones)==receipt['bones'])
check('named clips retained',{t.name for t in arm.animation_data.nla_tracks}==set(receipt['clips']))
check('unit scale on asset objects',all((o.scale-Vector((1,1,1))).length<.001 for o in assets))
bad=0;max_influences=0
for ob in meshes:
    for v in ob.data.vertices:
        weights=[g.weight for g in v.groups if g.weight>1e-6]
        max_influences=max(max_influences,len(weights))
        if not weights or abs(sum(weights)-1)>.0001 or len(weights)>4:bad+=1
check('all skin vertices normalized with max4 influences',bad==0,{'bad':bad,'maximum':max_influences})
check('every mesh bound to the intended rig',all(any(m.type=='ARMATURE' and m.object==arm for m in o.modifiers) for o in meshes))
check('every mesh carries UV coordinates',all(o.data.uv_layers for o in meshes))
triangles=0
for ob in meshes:
    evaluated=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh();data.calc_loop_triangles();triangles+=len(data.loop_triangles);evaluated.to_mesh_clear()
print('EVALUATED_TRIANGLES',triangles)

if receipt['asset']=='mr_p':
    body=bpy.data.objects['MrP_Body'];bm=bmesh.new();bm.from_mesh(body.data);seen=set();components=0
    for v in bm.verts:
        if v in seen:continue
        components+=1;todo=[v];seen.add(v)
        while todo:
            a=todo.pop()
            for e in a.link_edges:
                b=e.other_vert(a)
                if b not in seen:seen.add(b);todo.append(b)
    check('deforming torso arms fingers and tail connected',components==1,components)
    check('deforming skin has no boundary holes',not any(e.is_boundary for e in bm.edges));bm.free()
    check('paired blink morphs retained',all(bpy.data.objects['Upper_lid_'+s].data.shape_keys.key_blocks.get('Blink') for s in ['L','R']))
    check('hat is independently tagged',sum(o.get('accessory_id')=='top_hat' for o in meshes)==3)
else:
    expected={'torso','head','power_core','left_arm','right_arm','left_leg','right_leg'}
    check('seven independent robot mesh modules',len(meshes)==7 and {o.get('part_id') for o in meshes}==expected)
    sockets=[o for o in assets if o.type=='EMPTY' and o.name.startswith('SOCKET_')]
    check('seven named bind-pose sockets',len(sockets)==7 and {o.get('part_id') for o in sockets}==expected)
    check('socket target bones are valid',all(o.get('target_bone') in arm.data.bones and o.get('socket_space')=='bind_pose_metres' for o in sockets))
    manifest=json.loads((folder/'parts/parts.json').read_text())
    union=bytearray(768*1024);complete=None
    for part,entry in manifest['images'].items():
        path=folder/'parts'/entry['file'];check('layer hash '+part,hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'])
        image=bpy.data.images.load(str(path),check_existing=False)
        check('registered canvas '+part,tuple(image.size)==(768,1024) and image.channels==4)
        alpha=image.pixels[3::4];mask=bytearray(int(a>.1) for a in alpha)
        check('transparent nonempty layer '+part,0 in mask and 1 in mask)
        if part=='complete':complete=mask
        else:
            for i,value in enumerate(mask):union[i]=union[i] or value
        bpy.data.images.remove(image)
    check('seven part silhouettes reconstruct complete silhouette',complete is not None and union==complete)

motion={}
for clip,length in receipt['clips'].items():
    for t in arm.animation_data.nla_tracks:t.mute=t.name!=clip
    first=None;previous=None;maximum=0;finite=True;feet_first=None;foot_drift=0
    for frame in range(1,length+1):
        bpy.context.scene.frame_set(frame)
        positions=[(arm.matrix_world @ p.matrix).translation.copy() for p in arm.pose.bones]
        finite=finite and all(math.isfinite(v) for p in positions for v in p)
        if previous:maximum=max(maximum,max((a-b).length for a,b in zip(positions,previous)))
        if first is None:first=positions
        previous=positions
        if receipt['asset']=='robot' and clip in ('Idle','PowerOn'):
            feet=[(arm.matrix_world @ arm.pose.bones['foot_'+s].matrix).translation.copy() for s in ['L','R']]
            if feet_first is None:feet_first=feet
            foot_drift=max(foot_drift,max((a-b).length for a,b in zip(feet,feet_first)))
    seam=max((a-b).length for a,b in zip(first,previous))
    motion[clip]={'max_bone_step_metres':maximum,'endpoint_difference_metres':seam}
    check(clip+' finite poses through every frame',finite)
    check(clip+' no abrupt bone-position jumps',maximum<.16,maximum)
    if clip=='Idle':check('Idle closes at identical bone positions',seam<.001,seam)
    if receipt['asset']=='robot' and clip in ('Idle','PowerOn'):check(clip+' keeps mechanical feet planted',foot_drift<.001,foot_drift)
    if receipt['asset']=='robot' and clip=='Assemble':
        check('Assemble ends at bind-pose attachment transforms',all((p.matrix.translation-arm.data.bones[p.name].matrix_local.translation).length<.001 for p in arm.pose.bones))
for t in arm.animation_data.nla_tracks:t.mute=t.name!='Idle'
bpy.context.scene.frame_set(1)
if receipt['asset']=='mr_p':
    bpy.context.scene.frame_set(46);deps=bpy.context.evaluated_depsgraph_get()
    def world_bvh(ob):
        e=ob.evaluated_get(deps);data=e.to_mesh();verts=[ob.matrix_world @ v.co for v in data.vertices]
        tree=BVHTree.FromPolygons(verts,[tuple(p.vertices) for p in data.polygons]);e.to_mesh_clear();return tree,verts
    for side in ['L','R']:
        lid,_=world_bvh(bpy.data.objects['Upper_lid_'+side]);pupil,verts=world_bvh(bpy.data.objects['Pupil_'+side])
        x0,x1=min(v.x for v in verts),max(v.x for v in verts);z0,z1=min(v.z for v in verts),max(v.z for v in verts)
        hits=0;exposed=0
        for i in range(21):
            for j in range(21):
                origin=Vector((x0+(x1-x0)*i/20,-2,z0+(z1-z0)*j/20));direction=Vector((0,1,0))
                ph=pupil.ray_cast(origin,direction,10);lh=lid.ray_cast(origin,direction,10)
                if ph[0] is not None:
                    hits+=1
                    if lh[0] is None or lh[3]>ph[3]+.0001:exposed+=1
        check('fully closed '+side+' lid covers pupil from front',hits>100 and exposed==0,{'pupil_rays':hits,'exposed':exposed})
    bpy.context.scene.frame_set(1)
result={'native_sha256':receipt['native_sha256'],'glb_sha256':receipt['glb_sha256'],'checks':checks,'failures':sum(not c['pass'] for c in checks),'evaluated_triangles':triangles,'motion':motion}
(folder/'native-verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('NATIVE_CHARACTER_RESULT',len(checks),result['failures'])
if result['failures']:raise RuntimeError('Character construction or motion check failed')
