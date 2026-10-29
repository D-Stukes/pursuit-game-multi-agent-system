"""Launch the game, or select an explicit local developer tool."""
import argparse
from contextlib import nullcontext
import json
from pathlib import Path
import subprocess
import sys

# Support both direct CLI execution and importing this launcher in tests.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from godot_runtime import ROOT, find_godot, import_project
from prepare_game import prepare
from prepare_characters import prepare as prepare_characters
from npc_runtime import game_environment, local_agent_service
from godot_review import directory as review_directory, review_session, send_request


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--agents', action='store_true', help='Enable the local Claude NPC service; missing key uses local preview')
    developer = parser.add_argument_group('Developer tools (optional)')
    modes = developer.add_mutually_exclusive_group()
    modes.add_argument('--dev', action='store_true', help='Play with the entrance and elevator gates bypassed; earns no progress')
    modes.add_argument('--characters', action='store_true', help='Open the isolated character art review using retained private exports')
    modes.add_argument('--browser-review', action='store_true', help='Open the local browser model reviewer')
    modes.add_argument('--test', action='store_true', help='Run the headless building/physics regression')
    modes.add_argument('--live-review', action='store_true', help='Keep one developer review game open for repeated local commands')
    modes.add_argument('--review-status', action='store_true', help='Check the existing review process without starting Godot')
    modes.add_argument('--review-command', type=Path, help='Send a JSON request file to the existing review process; starts no engine')
    developer.add_argument('--port', type=int, default=8767, help='Loopback browser-review port (default: 8767)')
    developer.add_argument('--review-timeout', type=float, default=30, help='Seconds to wait for a live review reply (default: 30; max: 120)')
    args = parser.parse_args(argv)
    if args.agents and (args.test or args.characters or args.browser_review or args.live_review or args.review_status or args.review_command):
        parser.error('--agents applies only to the game or --dev')
    if not 1024 <= args.port <= 65535:
        parser.error('--port must be between 1024 and 65535')
    try:
        if args.review_status or args.review_command:
            request = {'action': 'status'} if args.review_status else json.loads(args.review_command.read_text(encoding='utf-8-sig'))
            print(json.dumps(send_request(ROOT, request, args.review_timeout), indent=2))
            return 0
        environment = game_environment()
        if args.browser_review:
            return subprocess.run([sys.executable, str(ROOT/'trials/building-review/serve.py'),
                                   '--open', '--port', str(args.port)], cwd=ROOT,
                                  env=environment, check=False).returncode
        with review_session(ROOT) if args.live_review else nullcontext():
            if args.characters:
                prepare_characters()
            else:
                prepare()
            binary = find_godot()
            import_project(binary, ROOT/'godot', environment=environment)
            command = [binary, '--path', str(ROOT/'godot')]
            if args.characters:
                command.append('res://developer/CharacterReview.tscn')
            elif args.test:
                command += ['--headless', '--script', 'res://developer/tests/verify_playtest.gd']
            elif args.live_review:
                command += ['--script', 'res://developer/tests/live_review.gd',
                            '--log-file', str(review_directory(ROOT)/'review-engine.log')]
                print('Live review stays open. Use --review-status or --review-command in another terminal.', flush=True)
            # Normal play uses project.godot's sole main scene.
            with local_agent_service(ROOT) if args.agents else nullcontext(None) as agent_url:
                user_args = []
                if args.dev: user_args.append('--developer-review')
                if agent_url: user_args += ['--npc-provider=claude', '--npc-agent-url='+agent_url]
                if user_args: command += ['--', *user_args]
                return subprocess.run(command, cwd=ROOT, env=environment, check=False).returncode
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Could not start the game or developer tool: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
