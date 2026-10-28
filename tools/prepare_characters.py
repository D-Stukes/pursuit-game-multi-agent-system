"""Stage selected private character exports into ignored Godot resources."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[1]
DEFAULT=ROOT.parents[2]/'Creative/Blender/Pursuit - The Climb/Exports/Characters'
DEST=ROOT/'godot/assets/generated/characters'
GAME_DEST=ROOT/'godot/assets/characters/authored'


def prepare_game(source=DEFAULT):
    """Promote only the two verified 3D assets requested for the playable scene."""
    assets={};copies=[]
    for directory,filename,expected_bones in [('Mr P','mr-p.glb',13),('Robot','robot.glb',17)]:
        folder=source/directory
        receipt=json.loads((folder/'receipt.json').read_text())
        original=folder/filename;raw=original.read_bytes()
        digest=hashlib.sha256(raw).hexdigest()
        if digest!=receipt['glb_sha256'] or receipt.get('bones')!=expected_bones:
            raise ValueError('Game character differs from its reviewed rig receipt: '+directory)
        copies.append((original,GAME_DEST/filename))
        assets[receipt['asset']]={'file':filename,'sha256':digest,'bones':expected_bones,
            'clips':list(receipt['clips']),'units':'metres','source':'Original authored geometry; tools/build_characters.py'}
    GAME_DEST.mkdir(parents=True,exist_ok=True)
    for original,target in copies:shutil.copyfile(original,target)
    (GAME_DEST/'assets.json').write_text(json.dumps({'schema':1,'assets':assets},indent=2)+'\n',encoding='utf-8')
    print('Reviewed game characters staged: '+', '.join(assets))


def prepare(source=DEFAULT):
    prepared=[];copies=[]
    for directory,filename in [('Mr P','mr-p.glb'),('Robot','robot.glb')]:
        folder=source/directory
        if not (folder/'receipt.json').is_file():continue
        receipt=json.loads((folder/'receipt.json').read_text())
        raw=(folder/filename).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=receipt['glb_sha256']:
            raise ValueError(f'{directory} export does not match its review receipt')
        copies.append((folder/filename,DEST/filename))
        if directory=='Robot':
            part_dir=folder/'parts';manifest=json.loads((part_dir/'parts.json').read_text())
            expected={'torso','head','power_core','left_arm','right_arm','left_leg','right_leg'}
            if set(manifest['parts'])!=expected or manifest['canvas']!=[768,1024]:raise ValueError('Robot layer registration does not match the seven-part contract')
            if len(manifest['overlay_order'])!=7 or set(manifest['overlay_order'])!=expected:raise ValueError('Robot layer order does not match its part IDs')
            for part in [*manifest['parts'],'complete']:
                entry=manifest['images'][part];name=entry['file']
                if Path(name).name!=name or Path(name).suffix.lower()!='.png':raise ValueError('Robot image path escapes its part folder')
                image=part_dir/name
                if hashlib.sha256(image.read_bytes()).hexdigest()!=entry['sha256']:raise ValueError('Robot part image does not match its receipt: '+part)
                copies.append((image,DEST/'robot-parts'/name))
            copies.append((part_dir/'parts.json',DEST/'robot-parts/parts.json'))
        prepared.append(filename)
    if not prepared:raise ValueError('No selected character exports found; build and review the characters first')
    # Validate the complete producer bundle before replacing any cached resource.
    for original,target in copies:
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,target)
    print('Character exports staged: '+', '.join(prepared))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--assets-dir',type=Path,default=DEFAULT)
    parser.add_argument('--game',action='store_true',help='Stage the reviewed 3D GLBs as portable game assets; keep private masters and 2D preview layers outside Git')
    args=parser.parse_args()
    (prepare_game if args.game else prepare)(args.assets_dir)
