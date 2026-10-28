"""Prepare and run the building playtest with an existing Godot installation."""
import argparse
import subprocess
import sys

from godot_runtime import ROOT, find_godot, import_project
from prepare_playtest import prepare


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', action='store_true', help='Run the actual model/physics checks headlessly')
    args = parser.parse_args()
    try:
        prepare()
        binary = find_godot()
        import_project(binary, ROOT / 'godot')
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
