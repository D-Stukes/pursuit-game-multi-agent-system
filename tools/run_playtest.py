"""Prepare and run the building playtest with an existing Godot installation."""
import argparse
from contextlib import nullcontext
import subprocess
import sys

from godot_runtime import ROOT, find_godot, import_project
from prepare_playtest import prepare
from npc_runtime import game_environment, local_agent_service


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', action='store_true', help='Run the actual model/physics checks headlessly')
    parser.add_argument('--review', action='store_true', help='Start debug building review with the entrance puzzle bypassed')
    parser.add_argument('--agents', action='store_true', help='Start the optional local Claude NPC service; no key uses local preview')
    args = parser.parse_args()
    if args.test and args.agents:
        parser.error('--agents is for interactive play, not the geometry test runner')
    try:
        prepare()
        binary = find_godot()
        import_project(binary, ROOT / 'godot', environment=game_environment())
        command = [binary, '--path', str(ROOT / 'godot')]
        if args.test:
            command += ['--headless', '--script', 'res://playtest/tests/verify_playtest.gd']
        else:
            command += ['res://BuildingPlaytest.tscn']
        with local_agent_service(ROOT) if args.agents else nullcontext(None) as agent_url:
            user_args = []
            if args.review: user_args.append('--building-review')
            if agent_url: user_args += ['--npc-provider=claude', '--npc-agent-url='+agent_url]
            if user_args: command += ['--', *user_args]
            return subprocess.run(command, check=False, env=game_environment()).returncode
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Playtest could not start: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
