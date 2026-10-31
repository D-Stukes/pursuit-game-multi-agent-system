"""Approved-blueprint relationships, independently specified from the drawing."""
import json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BLUEPRINT_SHA='5c6c8e0ccc3570f657fed3fab3d61117e700905134969d7b915eb93a438c66d4'

class AssemblyContractTests(unittest.TestCase):
 def setUp(self):
  self.m=json.loads((ROOT/'godot/assets/building-layout.json').read_text())
  self.rooms={x['id']:x for x in self.m['modules']}
 def test_reference_authority_and_module_identity(self):
  self.assertEqual(self.m['blueprint']['reference_sha256'],BLUEPRINT_SHA)
  self.assertEqual(len(self.rooms),len(self.m['modules']))
  self.assertEqual({n for x in self.rooms.values() for n in x['photos']},set(range(4770,4804)))
  self.assertEqual(self.m['units'],'metres')
 def test_portals_fit_connected_spaces(self):
  for p in self.m['portals']:
   a=self.m['anchors'][p['anchor']]
   self.assertGreaterEqual(p['width'],1)
   self.assertEqual(len(p['normal']),3)
   for room_id in [p['from'],p['to']]:
    if 'bounds' not in self.rooms[room_id]:continue
    footprints=self.rooms[room_id].get('footprints',[self.rooms[room_id]['bounds']])
    fits=False
    for x0,y0,x1,y1 in footprints:
     inside=x0-.001<=a[0]<=x1+.001 and y0-.001<=a[1]<=y1+.001
     edge=min(abs(a[0]-x0),abs(a[0]-x1),abs(a[1]-y0),abs(a[1]-y1))<.001
     fits=fits or (inside and edge)
    self.assertTrue(fits,(p['id'],room_id,a))
 def test_room_assets_attach_at_declared_floor_corner(self):
  for room in self.rooms.values():
   if room.get('bounds'):
    self.assertEqual(room['origin'][:2],room['bounds'][:2],room['id'])
    self.assertEqual(room['origin'][2],self.m['levels']['upper'],room['id'])
 def test_original_forward_ramp_hall_and_fixed_banks(self):
  a=self.m['anchors']
  self.assertEqual(a['lift_ground'],[-.95,12.1,.85])
  self.assertEqual(a['lift_upper'],[-.95,12.1,5.05])
  self.assertEqual(a['ramp_top'][:2],[2.35,6.6])
  self.assertEqual(a['ground_hall_mid'][:2],[2.35,9.4])
  self.assertGreater(a['lift_ground_exit'][0],0)
  self.assertEqual(a['lift_ground_exit'][:2],a['lift_upper_exit'][:2])
 def test_blueprint_room_connections_and_open_area(self):
  direct={(p['from'],p['to']) for p in self.m['portals']}
  for edge in [('Reception','Classroom'),('Reception','Small_Room'),('Reception','Larger_Room'),('Reception','Internal_Hall'),('Internal_Hall','Commons')]:
   self.assertIn(edge,direct)
  self.assertNotIn(('Upper_Circulation','Commons'),direct)
  self.assertEqual(self.m['blueprint']['additional_room_access'],'direct door from Reception; confirmed by Dennis 2026-10-28')
 def test_approved_door_inventory_and_access_states(self):
  expected={'reception':('Upper_Circulation','Reception',False),
   'classroom':('Reception','Classroom',False),
   'additional_room':('Reception','Small_Room',True),
   'separate':('Reception','Larger_Room',True),
   'hall_room_1':('Internal_Hall','Hall_Room_1',True),
   'hall_room_2':('Internal_Hall','Hall_Room_2',True),
   'other_room':('Upper_Circulation','Other_Room',True)}
  actual={p['id']:p for p in self.m['portals'] if p['kind']=='door'}
  self.assertEqual(set(actual),set(expected))
  self.assertEqual(len({p['mesh_prefix'] for p in actual.values()}),len(expected))
  for key,contract in expected.items():
   p=actual[key];self.assertEqual((p['from'],p['to'],p['closed']),contract)
  self.assertTrue(actual['separate']['glazed'])
 def test_reception_depth_and_hall_width_are_usable(self):
  x0,y0,x1,y1=self.rooms['Reception']['bounds']
  self.assertGreaterEqual(x1-x0,9)
  self.assertGreaterEqual(y1-y0,5.5)
  hallway_front=self.rooms['Hall_Room_1']['bounds'][1]
  self.assertGreaterEqual(hallway_front-self.rooms['Classroom']['bounds'][3]-.16,3)
  classroom=self.rooms['Classroom']['bounds']
  self.assertGreaterEqual((classroom[2]-classroom[0])*(classroom[3]-classroom[1]),160)
 def test_two_rooms_stop_at_hallway_one_end(self):
  end=self.m['blueprint']['hallway_1_bounds'][0]
  for name in ['Hall_Room_1','Hall_Room_2']:
   room=self.rooms[name]['bounds']
   self.assertGreaterEqual(room[0],end)
   self.assertLessEqual(room[3],self.rooms['Commons']['bounds'][1])
  self.assertEqual(self.rooms['Bathrooms']['bounds'][2],-2.5)
  self.assertGreaterEqual(self.rooms['Bathrooms']['bounds'][1],11.2)
 def test_classroom_and_source_are_not_reflected(self):
  self.assertEqual(self.m['recipe_plan_transform']['classroom_rotation_z_degrees'],0)
  self.assertEqual(self.m['recipe_plan_transform']['classroom_translation'],[0,0,0])
  self.assertIn('Estimated',self.m['dimensions_status'])
 def test_distinct_rooms_do_not_overlap(self):
  rooms=[r for r in self.rooms.values() if r.get('bounds')]
  for index,a in enumerate(rooms):
   for b in rooms[index+1:]:
    if a.get('level')!=b.get('level'):continue
    for x0,y0,x1,y1 in a.get('footprints',[a['bounds']]):
     for u0,v0,u1,v1 in b.get('footprints',[b['bounds']]):
      width=max(0,min(x1,u1)-max(x0,u0));depth=max(0,min(y1,v1)-max(y0,v0))
      self.assertLess(width*depth,.000001,(a['id'],b['id']))

if __name__=='__main__':unittest.main()
