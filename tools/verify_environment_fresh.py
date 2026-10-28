"""Verify the current staged building in a separate, initially empty Godot cache.

Run after promoting the new export and running tools/prepare_playtest.py.
Existing project caches and raw art inputs are retained, never cleared.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from godot_runtime import ROOT, find_godot, import_project

TESTS = {
    'verify_layout': 'LAYOUT_RESULT',
    'verify_playtest': 'PLAYTEST_RESULT',
    'verify_controls': 'CONTROLS_RESULT',
    'verify_entrance': 'ENTRANCE_RESULT',
    'verify_review': 'REVIEW_RESULT',
}
SCRIPTS = (
    'BuildingPlaytest', 'BuildingPlayer', 'PlaytestHUD', 'ApprovedLayout',
    'EntrancePuzzle', 'EntrancePuzzleState', 'EnvironmentLighting',
)
EVIDENCE_LEVEL = (
    'Fresh derived-cache generation using the current retained building export, '
    'retained avatar and existing Godot installation; not fresh raw acquisition '
    'or fresh tool installation.'
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(timeout=300):
    project = ROOT/'godot'
    staged_building = project/'assets/generated/pursuit-building.glb'
    metadata = json.loads((ROOT/'trials/building-review/scene.json').read_text())
    if digest(staged_building) != metadata['model_sha256']:
        raise ValueError('Staged building differs from the selected export; prepare the playtest first')
    if digest(project/'assets/building-layout.json') != metadata['assembly_sha256']:
        raise ValueError('Building export and assembly manifest differ; rebuild and promote first')

    evidence = project/'.godot/playtest'
    evidence.mkdir(parents=True, exist_ok=True)
    fresh = Path(tempfile.mkdtemp(prefix='fresh-environment-', dir=evidence))
    files = [
        'project.godot', 'icon.svg', 'BuildingPlaytest.tscn',
        'assets/building-layout.json', 'assets/generated/pursuit-building.glb',
        'assets/characters/quaternius-casual/Casual_Hoodie.glb',
        'assets/characters/quaternius-casual/LICENSE.txt',
    ]
    files += [f'playtest/{name}.gd' for name in SCRIPTS]
    files += [f'playtest/tests/{name}.gd' for name in TESTS]
    files += [name+'.uid' for name in list(files)
              if name.endswith('.gd') and (project/(name+'.uid')).is_file()]
    identities = {}
    for relative in files:
        original = project/relative
        target = fresh/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)
        identities[relative] = digest(target)
        if identities[relative] != digest(original):
            raise ValueError('Input changed during fixture preparation: '+relative)
    if (fresh/'.godot').exists():
        raise RuntimeError('Fresh fixture unexpectedly contains an import cache')

    receipt = {
        'evidence_level': EVIDENCE_LEVEL,
        'source_hashes': identities,
        'empty_cache_before_import': True,
        'import_completed': False,
        'checks_passed': False,
        'tests': {},
    }
    receipt_path = fresh/'fresh-state.json'

    def save_receipt():
        receipt_path.write_text(json.dumps(receipt, indent=2), encoding='utf-8')

    save_receipt()
    print('FRESH_ENVIRONMENT_PROJECT', fresh, flush=True)
    try:
        binary = find_godot()
        receipt['godot_binary'] = binary
        import_project(binary, fresh)
        receipt['import_completed'] = True
        save_receipt()
        # The actual test scripts retain JSON/proofs here after import. This
        # directory is intentionally absent when empty-cache status is checked.
        (fresh/'.godot/playtest').mkdir(parents=True, exist_ok=True)
        for name, marker in TESTS.items():
            log = fresh/(name+'.log')
            with log.open('w', encoding='utf-8') as output:
                command = [binary, '--headless', '--path', str(fresh), '--script',
                           f'res://playtest/tests/{name}.gd']
                if name == 'verify_review':
                    command += ['--', '--building-review']
                result = subprocess.run(
                    command,
                    stdout=output, stderr=subprocess.STDOUT, timeout=timeout,
                    check=False,
                )
            text = log.read_text(encoding='utf-8', errors='replace')
            match = re.search(re.escape(marker)+r' checks=(\d+) failures=(\d+)', text)
            passed = result.returncode == 0 and match is not None and int(match[2]) == 0
            receipt['tests'][name] = {
                'returncode': result.returncode,
                'checks': int(match[1]) if match else None,
                'failures': int(match[2]) if match else None,
                'passed': passed,
                'log': log.name,
            }
            save_receipt()
            print(name, 'PASS' if passed else 'FAIL', flush=True)
            if not passed:
                raise RuntimeError(f'{name} failed; inspect {log}')
        receipt['checks_passed'] = True
        save_receipt()
    except Exception as error:
        receipt['error'] = str(error)
        save_receipt()
        raise
    print('FRESH_ENVIRONMENT_IMPORT_PASSED', fresh, flush=True)
    return fresh


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout', type=float, default=300,
                        help='Maximum seconds per engine verification script (default: 300)')
    verify(parser.parse_args().timeout)
