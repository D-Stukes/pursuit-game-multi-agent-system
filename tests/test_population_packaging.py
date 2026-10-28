"""Protect the data-preserving source-to-runtime conversion contract."""
import base64
import json
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from prepare_population import encode_glb


class PopulationPackagingTests(unittest.TestCase):
    def test_new_input_survives_repackaging_without_geometry_or_rig_edits(self):
        raw = bytes(range(251))
        source = {'asset':{'version':'2.0'},'buffers':[{'byteLength':len(raw),'uri':'data:application/octet-stream;base64,'+base64.b64encode(raw).decode()}],
                  'accessors':[{'bufferView':0,'count':3,'type':'VEC3','componentType':5126}],
                  'skins':[{'joints':[1,2],'inverseBindMatrices':0}],
                  'animations':[{'name':'Idle_Neutral','channels':[]}],
                  'nodes':[{'name':'ExampleRig'}]}
        output = encode_glb(source)
        magic,version,length = struct.unpack_from('<4sII',output)
        self.assertEqual((magic,version,length),(b'glTF',2,len(output)))
        size,kind = struct.unpack_from('<I4s',output,12)
        decoded = json.loads(output[20:20+size])
        self.assertEqual(kind,b'JSON')
        self.assertEqual(decoded['buffers'],[{'byteLength':251}])
        for key in ('accessors','skins','animations','nodes'):
            self.assertEqual(decoded[key],source[key])
        binary_size,binary_kind = struct.unpack_from('<I4s',output,20+size)
        self.assertEqual(binary_kind,b'BIN\0')
        self.assertEqual(output[28+size:28+size+len(raw)],raw)
        self.assertEqual(binary_size%4,0)
        self.assertIn('uri',source['buffers'][0])

    def test_external_buffer_cannot_become_an_incomplete_runtime_asset(self):
        with self.assertRaisesRegex(ValueError,'External'):
            encode_glb({'buffers':[{'byteLength':5,'uri':'missing.bin'}]})

    def test_truncated_buffer_is_rejected(self):
        with self.assertRaisesRegex(ValueError,'length mismatch'):
            encode_glb({'buffers':[{'byteLength':5,'uri':'data:application/octet-stream;base64,AA=='}]})


if __name__ == '__main__':unittest.main()
