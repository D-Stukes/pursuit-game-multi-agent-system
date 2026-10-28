"""Integrity and privacy regressions for the portable review package."""
import hashlib
import http.client
import json
from pathlib import Path
import re
import struct
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.parse import quote

import serve

EXPECTED = json.loads((serve.ROOT / 'scene.json').read_text())['model_sha256']


class PackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), serve.Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self, path, method='GET'):
        conn = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        conn.request(method, path)
        response = conn.getresponse()
        result = response.status, dict(response.getheaders()), response.read()
        conn.close()
        return result

    def test_allowed_assets_and_no_store(self):
        for path, mime in serve.FILES.items():
            with self.subTest(path=path):
                status, headers, body = self.request('/' + quote(path))
                self.assertEqual(status, 200)
                self.assertEqual(headers['Content-Type'], mime)
                self.assertEqual(body, (serve.ROOT / path).read_bytes())
                self.assertEqual(headers['Cache-Control'], 'no-store')
                self.assertIn("frame-ancestors 'none'", headers['Content-Security-Policy'])
        status, headers, body = self.request('/assets/pursuit-building.glb?v=test', 'HEAD')
        self.assertEqual(status, 200)
        self.assertEqual(int(headers['Content-Length']), (serve.ROOT / 'assets/pursuit-building.glb').stat().st_size)
        self.assertEqual(body, b'')

    def test_private_files_and_traversal_are_not_served(self):
        for path in ['/serve.py', '/README.md', '/scene.json.bak', '/vendor/',
                     '/.git/config', '/../README.md', '/%2e%2e/README.md',
                     '/%2e%2e%5cREADME.md', '/%00', '/Images/pursuit_L2_students1.jpg',
                     '/assets/Pursuit%20Corrected%20Building.blend']:
            with self.subTest(path=path):
                self.assertEqual(self.request(path)[0], 404)

    def test_glb_identity_embedded_resources_and_manifest_coverage(self):
        raw = (serve.ROOT / 'assets/pursuit-building.glb').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), EXPECTED)
        magic, version, size, length, kind = struct.unpack_from('<4sIIII', raw)
        self.assertEqual((magic, version, size, kind), (b'glTF', 2, len(raw), 0x4E4F534A))
        gltf = json.loads(raw[20:20 + length])
        self.assertNotIn('source_assets', gltf['scenes'][0].get('extras', {}))
        self.assertNotIn('Home Codex', raw[20:20 + length].decode())
        binary_length, binary_type = struct.unpack_from('<II', raw, 20 + length)
        self.assertEqual(binary_type, 0x004E4942)
        binary = raw[28 + length:28 + length + binary_length]
        self.assertGreater(len(binary), 100000)
        meta = json.loads((serve.ROOT / 'scene.json').read_text())
        self.assertEqual(meta['model'], 'assets/pursuit-building.glb')
        self.assertEqual(meta['model_sha256'], EXPECTED)
        nodes = [node for node in gltf['nodes'] if 'mesh' in node]
        self.assertGreater(len(nodes), 4000)
        self.assertEqual({n['name'] for n in nodes}, set(meta['meshes']))
        self.assertFalse(any(n['name'].startswith('Double-door connector |') for n in nodes))
        self.assertFalse(any(n['name'].startswith('Classroom | Breakout door') for n in nodes))
        self.assertTrue({'reception', 'classroom', 'commons-kitchen', 'rooftop-pavilion'} <= {s['id'] for s in meta['stops']})
        self.assertGreaterEqual(len(meta['routes']), 4)
        self.assertEqual({v['module'] for v in meta['meshes'].values()}, {'Ground_Core','Lift_Banks','Upper_Circulation','Reception','Classroom','Small_Room','Larger_Room','Internal_Hall','Commons','Side_Workspace','Exterior_Main','Exterior_Opposite','Streetscape','Hall_Room_1','Hall_Room_2','Bathrooms','Other_Room'})
        for resource in gltf.get('images', []) + gltf.get('buffers', []):
            self.assertNotIn('uri', resource)
        self.assertNotIn('classroom', meta)  # no separate model dependency

    def test_page_has_no_photo_gallery_and_local_module_dependencies_resolve(self):
        html = (serve.ROOT / 'index.html').read_text(encoding='utf-8')
        self.assertNotRegex(html, r'<img\b|data:image|photos-panel|renders-panel')
        self.assertIn('assets/pursuit-building.glb', html)
        for file in serve.ROOT.rglob('*.js'):
            code = re.sub(r'/\*.*?\*/', '', file.read_text(encoding='utf-8'), flags=re.S)
            for specifier in re.findall(r'^\s*import\s+[^;]+?\bfrom\s*[\'\"]([^\'\"]+)', code, re.M):
                if specifier == 'three':
                    target = serve.ROOT / 'vendor/three.module.js'
                elif specifier.startswith('three/addons/'):
                    target = serve.ROOT / 'vendor' / specifier.removeprefix('three/addons/')
                else:
                    self.assertTrue(specifier.startswith('.'), specifier)
                    target = (file.parent / specifier).resolve()
                self.assertTrue(target.is_file(), target)
                self.assertIn(target.relative_to(serve.ROOT).as_posix(), serve.FILES)
        for file in serve.ROOT.rglob('*'):
            if file.is_file():
                self.assertNotIn(file.suffix.lower(), {'.jpg', '.jpeg', '.png', '.blend', '.blend1'})


if __name__ == '__main__':
    unittest.main()
