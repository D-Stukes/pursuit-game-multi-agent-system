"""Stage the canonical building into Godot's resource root without duplicating it in Git."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'trials/building-review'
DEST = ROOT / 'godot/assets/generated'


def prepare():
    metadata = json.loads((REVIEW / 'scene.json').read_text(encoding='utf-8'))
    source = (REVIEW / metadata['model']).resolve()
    if not source.is_relative_to(REVIEW.resolve()):
        raise ValueError('Model path escapes the review package')
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != metadata['model_sha256']:
        raise ValueError('Canonical model does not match its review manifest')
    DEST.mkdir(parents=True, exist_ok=True)
    target = DEST / 'pursuit-building.glb'
    if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
        shutil.copyfile(source, target)
    print(f'Godot building staged: {digest}')


if __name__ == '__main__':
    prepare()
