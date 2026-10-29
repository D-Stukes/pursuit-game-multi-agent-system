"""Mode selection must not start the wrong tool, provider or private producer."""
from contextlib import contextmanager, ExitStack, redirect_stderr
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('run_game', ROOT/'tools/run_game.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class GameLauncherTests(unittest.TestCase):
    def setUp(self):
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.prepare = self.stack.enter_context(patch.object(launcher, 'prepare'))
        self.art = self.stack.enter_context(patch.object(launcher, 'prepare_characters'))
        self.find = self.stack.enter_context(patch.object(launcher, 'find_godot', return_value='godot'))
        self.import_project = self.stack.enter_context(patch.object(launcher, 'import_project'))
        self.run = self.stack.enter_context(patch.object(launcher.subprocess, 'run', return_value=Mock(returncode=0)))
        self.environment = {'KEEP':'yes'}
        self.stack.enter_context(patch.object(launcher, 'game_environment', return_value=self.environment))
        self.provider = self.stack.enter_context(patch.object(launcher, 'local_agent_service'))

    def test_normal_play_uses_project_main_and_no_backend_or_art_producer(self):
        self.assertEqual(launcher.main([]), 0)
        self.prepare.assert_called_once_with()
        self.art.assert_not_called(); self.provider.assert_not_called()
        self.assertEqual(self.run.call_args.args[0], ['godot','--path',str(ROOT/'godot')])
        self.assertEqual(self.run.call_args.kwargs['env'], self.environment)
        self.assertEqual(self.import_project.call_args.kwargs['environment'], self.environment)

    def test_developer_review_is_explicit_and_starts_no_provider(self):
        launcher.main(['--dev'])
        self.assertIn('--building-review', self.run.call_args.args[0])
        self.provider.assert_not_called()

    def test_character_review_calls_only_its_own_producer(self):
        launcher.main(['--characters'])
        self.art.assert_called_once_with(); self.prepare.assert_not_called()
        self.assertIn('res://CharacterReview.tscn', self.run.call_args.args[0])
        self.provider.assert_not_called()

    def test_browser_tool_needs_neither_godot_nor_private_art(self):
        launcher.main(['--browser-review','--port','8768'])
        self.find.assert_not_called(); self.prepare.assert_not_called(); self.art.assert_not_called()
        self.provider.assert_not_called(); self.import_project.assert_not_called()
        self.assertEqual(self.run.call_args.args[0], [launcher.sys.executable,str(ROOT/'trials/building-review/serve.py'),'--open','--port','8768'])
        self.assertEqual(self.run.call_args.kwargs['env'], self.environment)

    def test_geometry_checks_are_headless_and_do_not_start_provider(self):
        launcher.main(['--test'])
        self.assertIn('--headless', self.run.call_args.args[0])
        self.assertIn('res://playtest/tests/verify_playtest.gd', self.run.call_args.args[0])
        self.provider.assert_not_called()

    def test_explicit_provider_is_owned_until_game_exits(self):
        lifecycle = []
        @contextmanager
        def service(_root):
            lifecycle.append('started')
            try: yield 'http://127.0.0.1:12345'
            finally: lifecycle.append('stopped')
        self.provider.side_effect = service
        def run(*_args, **_kwargs):
            self.assertEqual(lifecycle, ['started'])
            return Mock(returncode=7)
        self.run.side_effect = run
        self.assertEqual(launcher.main(['--agents']), 7)
        self.assertIn('--npc-agent-url=http://127.0.0.1:12345', self.run.call_args.args[0])
        self.assertEqual(lifecycle, ['started','stopped'])

    def test_invalid_modes_fail_before_any_producer_or_provider(self):
        for args in [['--dev','--characters'],['--agents','--test'],['--agents','--characters'],['--agents','--browser-review'],['--browser-review','--port','22']]:
            with self.subTest(args=args), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                launcher.main(args)
        self.prepare.assert_not_called(); self.art.assert_not_called(); self.provider.assert_not_called()


if __name__ == '__main__':
    unittest.main()
