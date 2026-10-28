"""Keep generated junctions free of raised/coplanar road crossings."""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('streets',ROOT/'tools/environment_streets.py')
streets=importlib.util.module_from_spec(spec)
spec.loader.exec_module(streets)


class StreetFloorTests(unittest.TestCase):
    def test_junction_floors_abut_without_overlapping(self):
        floors=[]
        def floor(name,x0,y0,x1,y1,z,color):
            floors.append((name,x0,y0,x1,y1,z))
        noop=lambda *args,**kwargs: None
        layout=json.loads((ROOT/'godot/assets/building-layout.json').read_text())
        streets.build_street_extensions(layout,noop,floor,noop,noop)
        floors += [('existing asphalt',-65,-22,65,-8.3,-.20),
                   ('existing near sidewalk',-55,-8.3,55,-4.75,0),
                   ('existing far sidewalk',-55,-24,55,-22,0)]
        for i,a in enumerate(floors):
            for b in floors[i+1:]:
                overlap=min(a[3],b[3])-max(a[1],b[1])>1e-6 and min(a[4],b[4])-max(a[2],b[2])>1e-6
                self.assertFalse(overlap,(a,b))


if __name__=='__main__': unittest.main()
