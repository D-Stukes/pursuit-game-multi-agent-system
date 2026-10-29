"""Persistent review ownership, response freshness and command failure boundaries."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import godot_review as review

ROOT = Path(__file__).resolve().parents[1]


class GodotReviewTests(unittest.TestCase):
    def setUp(self):
        scratch = ROOT/'godot/.godot/playtest'
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        review.directory(self.root).mkdir(parents=True)
        self.session = {'ready':True,'session_id':'session-a','engine_pid':os.getpid()}

    def test_process_probe_is_read_only_and_recognizes_current_process(self):
        self.assertTrue(review.process_alive(os.getpid()))
        self.assertFalse(review.process_alive(-1))
        self.assertFalse(review.process_alive(2147483647))

    def test_os_lock_rejects_second_owner_and_releases_after_exit(self):
        path = review.directory(self.root)/'review-session.lock'
        with review.file_lock(path):
            with self.assertRaisesRegex(RuntimeError, 'already owns'):
                with review.file_lock(path): self.fail('second owner acquired lock')
        with review.file_lock(path): pass

    def test_live_orphan_process_blocks_a_new_launch(self):
        with patch.object(review, 'read_report', return_value=self.session):
            with self.assertRaisesRegex(RuntimeError, 'still running'):
                with review.review_session(self.root): self.fail('duplicate launch allowed')

    def test_stale_report_from_exited_process_does_not_block_launch(self):
        with patch.object(review, 'read_report', return_value=self.session), patch.object(review, 'process_alive', return_value=False):
            with review.review_session(self.root): pass

    def test_reply_must_match_current_session_and_request(self):
        reply = dict(self.session, request_id='request-a', busy=False, results=[{'frame':42}])
        with patch.object(review, 'read_report', side_effect=[self.session, reply]), patch.object(review.uuid, 'uuid4') as uuid:
            uuid.return_value.hex = 'request-a'
            self.assertEqual(review.send_request(self.root, {'action':'status'}), reply)
        payload = json.loads((review.directory(self.root)/'review-command.json').read_text())
        self.assertEqual(payload, {'action':'status','session_id':'session-a','request_id':'request-a'})

    def test_new_session_cannot_be_mistaken_for_the_requested_session(self):
        with patch.object(review, 'read_report', side_effect=[self.session, dict(self.session, session_id='session-b')]):
            with self.assertRaisesRegex(RuntimeError, 'session changed'):
                review.send_request(self.root, {'action':'status'})

    def test_busy_session_and_pending_command_are_not_overwritten(self):
        with patch.object(review, 'read_report', return_value=dict(self.session, busy=True)):
            with self.assertRaisesRegex(RuntimeError, 'starting or busy'):
                review.send_request(self.root, {'action':'status'})
        command = review.directory(self.root)/'review-command.json'
        command.write_text('pending')
        with patch.object(review, 'read_report', return_value=self.session):
            with self.assertRaisesRegex(RuntimeError, 'pending'):
                review.send_request(self.root, {'action':'status'})
        self.assertEqual(command.read_text(), 'pending')

    def test_timeout_leaves_the_session_and_pending_request_intact(self):
        with patch.object(review, 'read_report', return_value=self.session), patch.object(review.time, 'monotonic', side_effect=[0,2]):
            with self.assertRaisesRegex(RuntimeError, 'left running'):
                review.send_request(self.root, {'action':'status'}, timeout=1)
        self.assertTrue((review.directory(self.root)/'review-command.json').exists())
        self.assertTrue(review.process_alive(self.session['engine_pid']))

    def test_stale_code_error_is_propagated(self):
        reply = dict(self.session, request_id='request-a', error='Loaded source changed; keep the editor open.')
        with patch.object(review, 'read_report', side_effect=[self.session,reply]), patch.object(review.uuid, 'uuid4') as uuid:
            uuid.return_value.hex = 'request-a'
            with self.assertRaisesRegex(RuntimeError, 'Loaded source changed'):
                review.send_request(self.root, {'action':'reset'})

    def test_invalid_commands_are_rejected_before_channel_writes(self):
        bad = [None, {'steps':[]}, {'steps':[None]}, {'action':'run_code'}, {'action':[]}, {'action':{}}, {'feet':[1,2]}, {'feet':[0,float('nan'),1]}, {'wait':999}, {'capture':'../outside.png'}, {'size':[99999,99999]}, {'resume':'yes'}, {'steps':[{}],'action':'reset'}]
        for request in bad:
            with self.subTest(request=request), self.assertRaises(ValueError):
                review.send_request(self.root, request)
        self.assertFalse((review.directory(self.root)/'review-command.json').exists())

    def test_course_fixture_is_an_explicit_standalone_request(self):
        review.validate_request({'action':'course_playthrough'})
        for request in [{'action':'course_playthrough','resume':True},{'steps':[{'action':'status'},{'action':'course_playthrough'}]}]:
            with self.subTest(request=request), self.assertRaises(ValueError):
                review.validate_request(request)

    def test_npc_fixture_is_an_explicit_standalone_request(self):
        review.validate_request({'action':'npc_routines'})
        for request in [{'action':'npc_routines','resume':True},{'steps':[{'action':'npc_routines'},{'action':'status'}]}]:
            with self.subTest(request=request), self.assertRaises(ValueError):
                review.validate_request(request)


if __name__ == '__main__':
    unittest.main()
