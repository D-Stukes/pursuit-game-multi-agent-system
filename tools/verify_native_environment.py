"""Read-only validation of saved native assembly against the shared manifest."""
import bpy,hashlib,json,sys
from pathlib import Path
from mathutils import Vector,Matrix
import math
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'godot/assets/building-layout.json').read_text(encoding='utf-8-sig'))
checks=[]
def check(name,ok):
 checks.append((name,bool(ok)));print('PASS' if ok else 'FAIL',name)
check('native manifest identity',bpy.context.scene.get('assembly_manifest_sha256')==hashlib.sha256((root/'godot/assets/building-layout.json').read_bytes()).hexdigest())
check('metre scale',bpy.context.scene.unit_settings.scale_length==1)
check('no external libraries',not bpy.data.libraries)
check('all images packed',all(im.packed_file for im in bpy.data.images if im.has_data))
check('native review cameras use the shared photo viewpoints',all(
 (camera:=bpy.data.objects.get('CAM_'+view['id'])) is not None
 and (camera.location-Vector(view['position'])).length<.0001
 and (-camera.matrix_world.to_3x3().col[2]).normalized().dot(
     (Vector(view['target'])-camera.location).normalized())>.9999
 for view in m['review_views']))
for module in m['modules']:
 ob=bpy.data.objects.get(module['id']+'_ROOT')
 check('module '+module['id'],ob is not None and (ob.matrix_world.translation-Vector(module['origin'])).length<.0001 and (ob.scale-Vector((1,1,1))).length<.0001)
for name,point in m['anchors'].items():
 ob=bpy.data.objects.get('ANCHOR_'+name)
 check('anchor '+name,ob is not None and (ob.matrix_world.translation-Vector(point)).length<.0001)
props=[o for o in bpy.context.scene.objects if o.get('retained_source_kind')=='classroom']
core=[o for o in bpy.context.scene.objects if o.get('retained_source_kind') in ('ground','bank')]
reviewed_core={o.name:o for o in core}
check('646 retained classroom props',len(props)==646)
check('retained classroom no nonuniform stretch',all(abs(o.scale.x-o.scale.y)<.001 and abs(o.scale.z-o.scale.y)<.001 for o in props))
bounds=next(r['bounds'] for r in m['modules'] if r['id']=='Classroom')
check('retained classroom props fit room footprint',all(bounds[0]-.05<=p.x<=bounds[2]+.05 and bounds[1]-.05<=p.y<=bounds[3]+.05 for o in props for p in [o.matrix_world @ Vector(v) for v in o.bound_box]))
for group in m.get('classroom_assemblies',[]):
 members=[o for o in props if any(o.name.startswith(prefix) for prefix in group['prefixes'])]
 check('complete rigid classroom assembly '+group['id'],len(members)==group['expected_meshes'] and all(o.get('placement_assembly')==group['id'] for o in members))
def world_bounds(ob):
 points=[ob.matrix_world @ Vector(corner) for corner in ob.bound_box]
 return tuple(min(p[i] for p in points) for i in range(3)),tuple(max(p[i] for p in points) for i in range(3))
foliage=[world_bounds(o) for o in props if o.name.startswith('Classroom | Stylized foliage ')]
chair_backs=[world_bounds(o) for o in props if ' chair ' in o.name and o.name.endswith(' back')]
check('classroom foliage clears every chair back',bool(foliage) and bool(chair_backs) and all(
 any(a[1][i]+.05<b[0][i] or b[1][i]+.05<a[0][i] for i in range(3))
 for a in foliage for b in chair_backs))
check('all meshes parented to declared module',all(o.parent and o.parent.get('module_id')==o.get('module_id') for o in bpy.context.scene.objects if o.type=='MESH'))
# Constructed convex surfaces must point away from their geometric centroid.
# The cabin loft is offset above its origin, so object origin is not a valid
# orientation reference for every primitive.
constructed=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.get('retained_source_kind')]
centroids={o.name:sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices) for o in constructed}
inward=[(o.name,p.index) for o in constructed for p in o.data.polygons if p.normal.dot(p.center-centroids[o.name])<=0]
if inward:print('INWARD_CONSTRUCTED_FACES',inward[:20])
check('constructed convex surfaces face outward',not inward)
# Prove re-placement from a collection asset origin rather than trusting names.
col=bpy.data.collections['Reception']
probe=bpy.data.objects.new('INSTANCE_ORIGIN_PROBE',None)
probe.instance_type='COLLECTION';probe.instance_collection=col;probe.location=(40,40,0)
bpy.context.scene.collection.objects.link(probe)
bpy.context.view_layer.update()
seen=0;error=0
for instance in bpy.context.evaluated_depsgraph_get().object_instances:
 if instance.is_instance and instance.parent and instance.parent.original==probe and instance.object.type=='MESH':
  original=instance.object.original
  expected=original.matrix_world.translation-Vector(col.instance_offset)+probe.location
  error=max(error,(instance.matrix_world.translation-expected).length);seen+=1
check('Reception collection reinstances at declared origin',seen>0 and error<.001)
bpy.data.objects.remove(probe,do_unlink=True)
# Independently import the pinned source again and compare evaluated world
# vertices after the declared rigid relocation, plus material parameters.
# Counts alone cannot establish preserved shape or placement.
reviewed={o.name:o for o in props}
for index,ob in enumerate(list(bpy.context.scene.objects)):ob.name='REVIEWED_'+str(index)
source_scene=bpy.data.scenes.new('SOURCE_COMPARISON_ONLY');bpy.context.window.scene=source_scene
source_path=Path(bpy.data.filepath).parent/'source-cache.glb'
bpy.ops.import_scene.gltf(filepath=str(source_path))
source_objects={o.name:o for o in source_scene.objects if o.type=='MESH'}
selection=json.loads((root/m['source']['selection']).read_text())['meshes']
source_items={s['name']:s for s in selection if s['kind']=='classroom'}
placement=m['recipe_plan_transform']
rigid=Matrix.Translation(Vector(placement['classroom_translation'])) @ Matrix.Rotation(math.radians(placement['classroom_rotation_z_degrees']),4,'Z')
max_error=0;shape_ok=True;material_ok=True
def signature(material):
 if material is None:return None
 p=material.node_tree.nodes.get('Principled BSDF') if material.use_nodes else None
 return tuple(round(v,5) for v in material.diffuse_color)+(round(p.inputs['Metallic'].default_value,5),round(p.inputs['Roughness'].default_value,5)) if p else tuple(material.diffuse_color)
for name,actual in reviewed.items():
 original=source_objects.get(name)
 item=source_items.get(name)
 if original is None or item is None:shape_ok=False;continue
 expected=rigid @ Matrix.Translation(Vector(item['delta'])) @ original.matrix_world
 for group in m.get('classroom_assemblies',[]):
  if any(name.startswith(prefix) for prefix in group['prefixes']):
   expected=Matrix.Translation(Vector(group['translation'])) @ expected
 for exception in m.get('placement_exceptions',[]):
  if name in exception['names']:
   expected=Matrix.Translation(Vector(exception['to'])) @ Matrix.Rotation(math.radians(exception['rotation_z_degrees']),4,'Z') @ Matrix.Translation(-Vector(exception['from'])) @ expected
 if len(actual.data.vertices)!=len(original.data.vertices):shape_ok=False;continue
 for av,sv in zip(actual.data.vertices,original.data.vertices):
  max_error=max(max_error,(actual.matrix_world @ av.co-expected @ sv.co).length)
 material_ok=material_ok and [signature(s.material) for s in actual.material_slots]==[signature(s.material) for s in original.material_slots]
check('all classroom source world vertices match rigid relocation',shape_ok and max_error<.0001)
check('all classroom source material parameters preserved',material_ok)
source_core={s['name']:s for s in selection if s['kind'] in ('ground','bank')}
core_error=0;core_ok=True;core_materials=True
for name,actual in reviewed_core.items():
 original=source_objects.get(name);item=source_core.get(name)
 if original is None or item is None:core_ok=False;continue
 expected=Matrix.Translation(Vector(item['delta'])) @ original.matrix_world
 for exception in m.get('placement_exceptions',[]):
  if name in exception['names']:
   expected=Matrix.Translation(Vector(exception['to'])) @ Matrix.Rotation(math.radians(exception['rotation_z_degrees']),4,'Z') @ Matrix.Translation(-Vector(exception['from'])) @ expected
 if len(actual.data.vertices)!=len(original.data.vertices):core_ok=False;continue
 for av,sv in zip(actual.data.vertices,original.data.vertices):
  core_error=max(core_error,(actual.matrix_world @ av.co-expected @ sv.co).length)
 core_materials=core_materials and [signature(s.material) for s in actual.material_slots]==[signature(s.material) for s in original.material_slots]
check('retained ground and bank vertices match declared rigid poses',core_ok and core_error<.0001)
check('retained original ground and bank materials preserved',core_materials)
print('ORIGINAL_CORE_VERTEX_ERROR',core_error,'objects',len(reviewed_core))
print('CLASSROOM_MAX_VERTEX_ERROR',max_error)
fail=sum(not ok for _,ok in checks)
print('NATIVE_ASSEMBLY_RESULT',len(checks),fail)
if fail:raise RuntimeError('Native assembly verification failed')
