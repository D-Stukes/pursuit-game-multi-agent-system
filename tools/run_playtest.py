"""Prepare and run the building playtest with an existing Godot installation."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare_playtest import prepare

ROOT = Path(__file__).resolve().parents[1]


def find_godot():
    configured = os.environ.get('GODOT_BIN')
    if configured:
        path = Path(configured)
        if not path.is_file():
            raise RuntimeError('GODOT_BIN does not name an existing executable')
        return str(path)
    for command in ['godot', 'godot4', 'godot.exe']:
        found = shutil.which(command)
        if found:
            return found
    # Reuse the Home Codex portable-tool location when running in that workspace.
    portable = ROOT.parents[2] / 'Tools/Godot'
    candidates = list(portable.glob('**/*_console.exe'))
    if candidates:
        def version(path):
            match = re.search(r'v(\d+)\.(\d+)\.(\d+)', path.name)
            return tuple(map(int, match.groups())) if match else (0, 0, 0)
        return str(max(candidates, key=version))
    raise RuntimeError('Godot was not found. Install/use Godot 4.7+ and set GODOT_BIN to its executable.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', action='store_true', help='Run the actual model/physics checks headlessly')
    args = parser.parse_args()
    try:
        prepare()
        binary = find_godot()
        subprocess.run([binary, '--headless', '--editor', '--path', str(ROOT / 'godot'), '--import'], check=True)
        command = [binary, '--path', str(ROOT / 'godot')]
        if args.test:
            command += ['--headless', '--script', 'res://playtest/tests/verify_playtest.gd']
        else:
            command += ['res://BuildingPlaytest.tscn']
        return subprocess.run(command, check=False).returncode
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Playtest could not start: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
