"""Own the optional local NPC service for exactly one Godot launch."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import queue
import subprocess
import threading


def game_environment(environment=None):
    """Provider credentials belong to the backend child, never the game child."""
    result = dict(os.environ if environment is None else environment)
    for name in ('ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'CLAUDE_CODE_OAUTH_TOKEN'):
        result.pop(name, None)
    return result


@contextmanager
def local_agent_service(root, *, environment=None):
    root = Path(root)
    python = root/'.venv'/('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    if not python.is_file():
        raise RuntimeError('Set up the project environment using Docs/NPC-Agents.md before using --agents.')
    child = subprocess.Popen(
        [str(python), '-m', 'backend.server', '--port', '0'], cwd=root,
        env=environment, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0,
    )
    lines = queue.Queue()
    reader = threading.Thread(target=lambda: lines.put(child.stdout.readline()), daemon=True)
    reader.start()
    try:
        try:
            info = json.loads(lines.get(timeout=8))
        except (queue.Empty, ValueError):
            raise RuntimeError('NPC service could not start. Check the backend setup and local configuration.') from None
        if info.get('service') != 'pursuit-npc' or type(info.get('port')) is not int or not 1024 <= info['port'] <= 65535:
            raise RuntimeError('NPC service returned an invalid startup response.')
        if not info.get('provider_ready'):
            print('NPCs use local preview; add the backend API key when it is available.')
            child.terminate(); child.wait(timeout=5)
            yield None
        else:
            yield f"http://127.0.0.1:{info['port']}"
    finally:
        if child.poll() is None:
            child.terminate()
            try: child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill(); child.wait(timeout=5)
        child.stdout.close()
        reader.join(timeout=1)
