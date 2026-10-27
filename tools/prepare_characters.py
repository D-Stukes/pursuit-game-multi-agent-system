"""Stage reviewed private character exports into ignored Godot resources."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[1]
DEFAULT=ROOT.parents[2]/'Creative/Blender/Pursuit - The Climb/Exports/Characters'
DEST=ROOT/'godot/assets/generated/characters'


def prepare(source=DEFAULT):
    prepared=[]
    for directory,filename in [('Mr P','mr-p.glb')]:
        folder=source/directory
        if not (folder/'receipt.json').is_file():continue
        receipt=json.loads((folder/'receipt.json').read_text())
        raw=(folder/filename).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=receipt['glb_sha256']:
            raise ValueError(f'{directory} export does not match its review receipt')
        DEST.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(folder/filename,DEST/filename)
        prepared.append(filename)
    if not prepared:raise ValueError('No reviewed character exports found; build and review the characters first')
    print('Character exports staged: '+', '.join(prepared))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--assets-dir',type=Path,default=DEFAULT)
    prepare(parser.parse_args().assets_dir)
