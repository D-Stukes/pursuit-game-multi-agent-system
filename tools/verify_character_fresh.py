"""Check newly authored exports in an isolated, initially empty Godot import cache."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from run_playtest import ROOT,find_godot


if __name__=='__main__':
    evidence=ROOT/'godot/.godot/playtest';evidence.mkdir(parents=True,exist_ok=True)
    fresh=Path(tempfile.mkdtemp(prefix='fresh-characters-',dir=evidence))
    files=['CharacterReview.tscn','playtest/CharacterReview.gd','playtest/tests/verify_characters.gd']
    files += [p.relative_to(ROOT/'godot').as_posix() for p in (ROOT/'godot/assets/generated/characters').glob('*.glb')]
    identities={}
    for relative in files:
        source=ROOT/'godot'/relative;target=fresh/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        identities[relative]=hashlib.sha256(target.read_bytes()).hexdigest()
    (fresh/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Fresh character import proof"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    assert not (fresh/'.godot').exists()
    binary=find_godot()
    subprocess.run([binary,'--headless','--editor','--path',str(fresh),'--import','--log-file',str(fresh/'import.log')],check=True,stdout=subprocess.DEVNULL)
    subprocess.run([binary,'--headless','--path',str(fresh),'--script','res://playtest/tests/verify_characters.gd','--log-file',str(fresh/'verification.log')],check=True)
    result={'evidence_level':'Fresh derived-cache generation using retained newly authored GLBs and existing Godot installation; not fresh tool acquisition','source_hashes':identities,'empty_cache_before_import':True,'checks_passed':True}
    (fresh/'fresh-state.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('FRESH_CHARACTER_IMPORT_PASSED',fresh)
