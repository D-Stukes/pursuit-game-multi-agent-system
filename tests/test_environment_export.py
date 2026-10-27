"""World-transform and validation regressions for assembly promotion."""
import importlib.util
import json
from pathlib import Path
import struct
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('promote',ROOT/'tools/promote_environment.py')
promote=importlib.util.module_from_spec(spec);spec.loader.exec_module(promote)


class ExportTests(unittest.TestCase):
    def test_rotated_scaled_child_world_bounds(self):
        # Independent synthetic glTF: parent translates; child rotates and scales.
        data={'nodes':[{'translation':[10,20,30],'extras':{'module_id':'Reception'},'children':[1]},
                       {'name':'probe','mesh':0,'rotation':[0,0,2**-.5,2**-.5],'scale':[2,3,1]}],
              'meshes':[{'primitives':[{'attributes':{'POSITION':0}}]}],
              'accessors':[{'min':[0,0,0],'max':[1,1,1]}], 'scenes':[{'nodes':[0]}]}
        blob=json.dumps(data).encode();raw=b'glTF'+struct.pack('<IIII',2,len(blob)+20,len(blob),0x4e4f534a)+blob
        layout=json.loads((ROOT/'godot/assets/building-layout.json').read_text())
        item=promote.metadata(raw,layout)['meshes']['probe']
        self.assertEqual(item['min'],[7,-31,20])
        self.assertEqual(item['max'],[10,-30,22])
        self.assertEqual(item['module'],'Reception')

    def test_portable_export_is_bound_to_current_assembly(self):
        meta=json.loads((ROOT/'trials/building-review/scene.json').read_text())
        self.assertEqual(meta['assembly_sha256'],promote.digest(ROOT/'godot/assets/building-layout.json'))
        raw=(ROOT/'trials/building-review/assets/pursuit-building.glb').read_bytes()
        derived=promote.metadata(raw,json.loads((ROOT/'godot/assets/building-layout.json').read_text()))
        self.assertEqual(derived,meta)


if __name__=='__main__':unittest.main()
