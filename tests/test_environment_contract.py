"""Tests for the portable module/portal contract; no Blender or provider required."""
import json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class AssemblyContractTests(unittest.TestCase):
 def setUp(self):
  self.m=json.loads((ROOT/'godot/assets/building-layout.json').read_text(encoding='utf-8-sig'))
  self.rooms={x['id']:x for x in self.m['modules']}
 def test_references_and_module_identity(self):
  self.assertEqual(len(self.rooms),len(self.m['modules']))
  self.assertEqual({n for x in self.rooms.values() for n in x['photos']},set(range(4770,4804)))
  self.assertEqual(self.m['units'],'metres')
  for x in self.rooms.values():self.assertEqual(len(x['origin']),3)
 def test_portals_fit_both_connected_spaces(self):
  for p in self.m['portals']:
   a=self.m['anchors'][p['anchor']]
   self.assertGreaterEqual(p['width'],1)
   self.assertLessEqual(p['height'],self.m['levels']['upper_ceiling']-self.m['levels']['upper'])
   for room_id in [p['from'],p['to']]:
    if 'bounds' not in self.rooms[room_id]:continue
    x0,y0,x1,y1=self.rooms[room_id]['bounds']
    self.assertTrue(x0-.001<=a[0]<=x1+.001 and y0-.001<=a[1]<=y1+.001,(p['id'],room_id,a))
    self.assertTrue(min(abs(a[0]-x0),abs(a[0]-x1),abs(a[1]-y0),abs(a[1]-y1))<.001,(p['id'],room_id))
 def test_room_assets_attach_at_their_declared_floor_corner(self):
  for room in self.rooms.values():
   if room.get('bounds'):
    self.assertEqual(room['origin'][:2],room['bounds'][:2],room['id'])
    self.assertEqual(room['origin'][2],self.m['levels']['upper'],room['id'])
 def test_confirmed_rooms_and_separate_corridors(self):
  c,s,l=[self.rooms[k]['bounds'] for k in ['Classroom','Small_Room','Larger_Room']]
  self.assertEqual(c[3],s[1]);self.assertEqual(s[3],l[1])
  direct={(p['from'],p['to']) for p in self.m['portals']}
  self.assertNotIn(('Upper_Circulation','Commons'),direct)
  for r in ['Classroom','Small_Room','Larger_Room']:
   self.assertIn(('Reception',r),direct)
 def test_vertical_core_and_reference_uncertainty(self):
  a=self.m['anchors'];g,u=a['lift_ground'],a['lift_upper']
  self.assertEqual(g[:2],u[:2]);self.assertAlmostEqual(u[2]-g[2],4.2)
  self.assertEqual(self.m['levels']['street'],0)
  self.assertIn('Estimated',self.m['dimensions_status'])
  self.assertFalse(next(p for p in self.m['portals'] if p['id']=='commons')['confirmed'])

if __name__=='__main__':unittest.main()
