"""Shared Godot discovery and import setup for local review tools."""
import os
from pathlib import Path
import re
import shutil
import subprocess

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
    portable = ROOT.parents[2] / 'Tools/Godot'
    candidates = list(portable.glob('**/*_console.exe'))
    if candidates:
        def version(path):
            match = re.search(r'v(\d+)\.(\d+)\.(\d+)', path.name)
            return tuple(map(int, match.groups())) if match else (0, 0, 0)
        return str(max(candidates, key=version))
    raise RuntimeError('Godot was not found. Install/use Godot 4.7+ and set GODOT_BIN to its executable.')


def import_project(binary, project, *, environment=None):
    subprocess.run([binary, '--headless', '--editor', '--path', str(project), '--import'], check=True, env=environment)
