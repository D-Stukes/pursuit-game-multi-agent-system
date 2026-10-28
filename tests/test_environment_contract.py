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
  for edge in [('Reception','Classroom'),('Reception','Larger_Room'),('Reception','Internal_Hall'),('Internal_Hall','Commons')]:
   self.assertIn(edge,direct)
  self.assertNotIn(('Upper_Circulation','Commons'),direct)
  self.assertFalse(any('Small_Room' in edge for edge in direct))
  self.assertEqual(self.m['blueprint']['additional_room_access'],'unspecified; keep enclosed')
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

if __name__=='__main__':unittest.main()
