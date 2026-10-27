"""Promote a verified Blender assembly and derive viewer metadata from its GLB.

The native master stays outside Git. Both viewers consume the same export.
"""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'trials/building-review'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def multiply(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def matrix(node):
    if 'matrix' in node:
        return [[node['matrix'][c * 4 + r] for c in range(4)] for r in range(4)]
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    scale = node.get('scale', [1, 1, 1])
    rotation = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
    pos = node.get('translation', [0, 0, 0])
    return [[*(rotation[r][c] * scale[c] for c in range(3)), pos[r]] for r in range(3)] + [[0, 0, 0, 1]]


def metadata(raw, layout):
    length = struct.unpack_from('<I', raw, 12)[0]
    gltf = json.loads(raw[20:20+length])
    meshes = {}
    identity = [[int(r == c) for c in range(4)] for r in range(4)]

    def visit(index, parent, module=''):
        node = gltf['nodes'][index]
        transform = multiply(parent, matrix(node))
        module = node.get('extras', {}).get('module_id', module)
        if 'mesh' in node:
            points = []
            for primitive in gltf['meshes'][node['mesh']]['primitives']:
                acc = gltf['accessors'][primitive['attributes']['POSITION']]
                for corner in itertools.product(*zip(acc['min'], acc['max'])):
                    p = [sum(transform[r][c] * (*corner, 1)[c] for c in range(4)) for r in range(3)]
                    points.append([p[0], -p[2], p[1]])  # glTF Y-up to authoring Z-up
            low = [min(p[i] for p in points) for i in range(3)]
            high = [max(p[i] for p in points) for i in range(3)]
            name = node['name']
            layer = 'upper' if low[2] >= 4.75 else 'ground'
            if module in ('Exterior_Main', 'Exterior_Opposite', 'Streetscape'):
                layer = 'exterior'
            meshes[name] = {'layer': layer, 'room': module.lower(), 'module': module,
                            'ceiling': any(t in name.lower() for t in ('ceiling', 'roof')),
                            'min': [round(v, 4) for v in low], 'max': [round(v, 4) for v in high]}
        for child in node.get('children', []):
            visit(child, transform, module)

    for root in gltf['scenes'][gltf.get('scene', 0)]['nodes']:
        visit(root, identity)
    stops = layout['review_views']
    return {'schema_version': 2, 'model': 'assets/pursuit-building.glb',
            'model_sha256': hashlib.sha256(raw).hexdigest(),
            'assembly_sha256': digest(ROOT / 'godot/assets/building-layout.json'),
            'units': 'metres', 'dimensions_status': layout['dimensions_status'],
            'meshes': meshes, 'stops': stops,
            'routes': [{'points': points} for points in [
                [[0,-6.7,0],[0,-3.5,0],[2.35,-3.5,0],[2.35,5.2,.85],[2.35,12.1,.85],[-.95,12.1,.85]],
                [[1.05,12.1,5.05],[1.1,9.1,5.05],[-4.75,9.1,5.05],[-4.75,6.7,5.05],layout['anchors']['reception_spawn']],
                [layout['anchors']['reception_spawn'],[0,6.5,5.05],[0,3.4,5.05],[4,3.4,5.05],[4,4.2,5.05],layout['anchors']['classroom_door'],[6,4.2,5.05]],
                [[2,3.65,5.05],[2,-1.5,5.05],layout['anchors']['commons_entry'],[-6.5,3.4,5.05],[-11,3.4,5.05]]]]}


def promote(candidate):
    receipt = json.loads((candidate / 'assembly-receipt.json').read_text())
    for filename, key in [('pursuit-building.glb', 'glb_sha256'), ('Pursuit Photo Redesign.blend', 'blend_sha256')]:
        if digest(candidate / filename) != receipt[key]:
            raise ValueError(f'Candidate differs from receipt: {filename}')
    if digest(ROOT / 'godot/assets/building-layout.json') != receipt['manifest_sha256']:
        raise ValueError('Assembly manifest differs from candidate receipt')
    raw = (candidate / 'pursuit-building.glb').read_bytes()
    layout = json.loads((ROOT / 'godot/assets/building-layout.json').read_text())
    meta = metadata(raw, layout)
    if len(meta['meshes']) != receipt['meshes']:
        raise ValueError('Export mesh coverage differs from native receipt')
    shutil.copyfile(candidate / 'pursuit-building.glb', REVIEW / 'assets/pursuit-building.glb')
    (REVIEW / 'scene.json').write_text(json.dumps(meta, separators=(',', ':')), encoding='utf-8')
    print(f"Promoted {len(meta['meshes'])} meshes: {meta['model_sha256']}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    promote(parser.parse_args().candidate)
