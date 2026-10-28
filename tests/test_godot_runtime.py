"""Discovery contract shared by building and character launchers."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('godot_runtime', ROOT/'tools/godot_runtime.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class GodotDiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.scratch = ROOT/'godot/.godot/playtest'
        self.scratch.mkdir(parents=True, exist_ok=True)

    def test_explicit_missing_binary_does_not_silently_fall_back(self):
        with patch.dict(runtime.os.environ, {'GODOT_BIN': '/missing/godot.exe'}):
            with self.assertRaisesRegex(RuntimeError, 'GODOT_BIN'):
                runtime.find_godot()

    def test_explicit_existing_binary_takes_priority(self):
        with tempfile.TemporaryDirectory(dir=self.scratch) as directory:
            binary = Path(directory)/'configured.exe'
            binary.touch()
            with patch.dict(runtime.os.environ, {'GODOT_BIN': str(binary)}):
                with patch.object(runtime.shutil, 'which', return_value='other-godot'):
                    self.assertEqual(runtime.find_godot(), str(binary))

    def test_portable_fallback_uses_numeric_version_order(self):
        with tempfile.TemporaryDirectory(dir=self.scratch) as directory:
            root = Path(directory)/'Coding/Projects/game'
            portable = Path(directory)/'Tools/Godot'
            portable.mkdir(parents=True)
            for version in ['4.9.0', '4.10.0']:
                (portable/f'Godot_v{version}-stable_win64_console.exe').touch()
            with patch.dict(runtime.os.environ, {'GODOT_BIN': ''}):
                with patch.object(runtime.shutil, 'which', return_value=None):
                    with patch.object(runtime, 'ROOT', root):
                        self.assertIn('v4.10.0', runtime.find_godot())


if __name__ == '__main__':
    unittest.main()
