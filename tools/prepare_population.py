"""Package four selected Quaternius sources as portable, self-contained game GLBs.

Uses retained, creator-supplied glTF files. No network, mesh edits or new dependency.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT.parents[2]/'Creative/Blender/Pursuit - The Climb/Source/Characters/Quaternius'
DEST = ROOT/'godot/assets/characters/quaternius-population'
SOURCES = {
    'male_casual': ('1Jn7kULNmrtqP8BUUL19h8MhbdOnwPFhv', '55c654d09a2a5ff6e3bd6158d4a1b462f181cd6f1e12a0f5e9d959f9c3abc438', 'ultimatemodularcharacters'),
    'male_suit': ('1NhXHnGU0zK9hBrT5FoZp8nTz_EmvTPg5', '6c89fbb31b96c1a63ad94e3dee0942bd7b34bc789a5d39fd6a6a1738a9214fb3', 'ultimatemodularcharacters'),
    'female_casual': ('18b3WwlrwrFYWAM7BcnjWeIxKJyxAQiGh', 'b0fe6e92219cd71808844a20a1a8b960fd1cf640a6546dc6362b5add6604e87c', 'ultimatemodularwomen'),
    'female_formal': ('1iayBzVv_zLjuPtaNPouw_auwKlQLLmes', 'fdfcf454c4de037d31973eb28d8591bd7763035d49f46b380e63b1c832dc7ddf', 'ultimatemodularwomen'),
}


def encode_glb(document):
    """Rehouse the single embedded buffer; preserve accessors, skins and clips."""
    document = json.loads(json.dumps(document))
    buffers = document.get('buffers', [])
    if len(buffers) != 1 or document.get('images'):
        raise ValueError('Expected one embedded buffer and untextured materials')
    uri = buffers[0].pop('uri', '')
    if not uri.startswith('data:application/octet-stream;base64,'):
        raise ValueError('External or unexpected buffer reference')
    binary = base64.b64decode(uri.split(',', 1)[1], validate=True)
    if len(binary) != buffers[0]['byteLength']:
        raise ValueError('Embedded buffer length mismatch')
    metadata = json.dumps(document, separators=(',', ':')).encode('utf-8')
    metadata += b' ' * (-len(metadata) % 4)
    binary += b'\0' * (-len(binary) % 4)
    return (struct.pack('<4sII', b'glTF', 2, 28+len(metadata)+len(binary))
            + struct.pack('<I4s', len(metadata), b'JSON') + metadata
            + struct.pack('<I4s', len(binary), b'BIN\0') + binary)


def prepare(source=DEFAULT, destination=DEST):
    files = {}; entries = {}
    for name, (drive_id, expected, pack) in SOURCES.items():
        raw = (source/(name+'.gltf')).read_bytes()
        if hashlib.sha256(raw).hexdigest() != expected:
            raise ValueError('Source differs from selected acquisition: '+name)
        doc = json.loads(raw)
        if len(doc.get('skins', [])) != 1 or len(doc['skins'][0]['joints']) != 62:
            raise ValueError('Source rig differs from selected 62-joint character: '+name)
        packaged = encode_glb(doc)
        files[name+'.glb'] = packaged
        triangles = sum(doc['accessors'][p['indices']]['count']//3 for mesh in doc['meshes'] for p in mesh['primitives'])
        entries[name] = {
            'file': name+'.glb', 'sha256': hashlib.sha256(packaged).hexdigest(),
            'source_sha256': expected, 'source_url': f'https://drive.google.com/file/d/{drive_id}/view',
            'pack_url': f'https://quaternius.com/packs/{pack}.html',
            'license': 'CC0-1.0', 'joints': 62, 'triangles': triangles,
            'clips': [a['name'] for a in doc['animations']],
            'conversion': 'Embedded glTF buffer repackaged as GLB; geometry, skins, materials and clips unchanged',
        }
    # Validate all selected sources before replacing any runtime asset.
    destination.mkdir(parents=True, exist_ok=True)
    for name, raw in files.items():
        (destination/name).write_bytes(raw)
    (destination/'assets.json').write_text(json.dumps({'schema': 1, 'assets': entries}, indent=2)+'\n', encoding='utf-8')
    print('Population assets packaged:', ', '.join(entries))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT)
    args = parser.parse_args()
    prepare(args.source)
