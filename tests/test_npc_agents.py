"""No provider traffic: exercise the installed SDK through its HTTP transport."""
import copy
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest

from backend.npc_agents import CallBudget, DialogueError, NPCDialogue, load_profiles, validate
from backend.server import create_server, settings

try:
    import anthropic
    import httpx2
except ImportError:
    anthropic = None


def payload(npc='ReceptionA', topic='directions'):
    return {'schema': 1, 'request_id': 'test-turn-1', 'npc_id': npc, 'topic': topic,
            'memory': {'turn_count': 1, 'topics': ['day'], 'lines': ['One useful step at a time.']},
            'world': {'zone': 'reception', 'entrance_unlocked': True, 'elevator_unlocked': True},
            'ambient_context': ''}


class NPCProtocolTests(unittest.TestCase):
    def test_no_key_explicitly_reports_unconfigured(self):
        with self.assertRaisesRegex(DialogueError, 'provider_unconfigured'):
            NPCDialogue().reply(payload())

    def test_request_identity_and_world_bounds(self):
        profiles = load_profiles()
        for field, value in [('npc_id', 'missing'), ('topic', 'grant_energy'), ('request_id', 'x' * 81),
                             ('memory', {'turn_count': True, 'topics': [], 'lines': []}),
                             ('world', {'zone': 'classroom', 'entrance_unlocked': True, 'elevator_unlocked': True})]:
            with self.subTest(field=field), self.assertRaises(DialogueError):
                validate({**payload(), field: value}, profiles)
        with self.assertRaises(DialogueError):
            validate({**payload(), 'grant_energy': 10}, profiles)

    def test_accepted_memory_is_copied_not_shared(self):
        original = payload()
        accepted = validate(original, load_profiles())
        accepted['memory']['lines'].append('new')
        self.assertEqual(len(original['memory']['lines']), 1)

    def test_budget_stops_at_launch_and_rate_limits(self):
        budget = CallBudget(total=2)
        budget.reserve(); budget.reserve()
        with self.assertRaisesRegex(DialogueError, 'budget_exhausted'): budget.reserve()
        budget = CallBudget(total=60, per_minute=1)
        budget.reserve()
        with self.assertRaisesRegex(DialogueError, 'budget_exhausted'): budget.reserve()

    def test_private_config_is_parsed_without_shell_execution(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'.env'
            path.write_text('ANTHROPIC_API_KEY=test-value\nANTHROPIC_MODEL=example-model\nNPC_MAX_MODEL_CALLS=4\nOTHER=$(bad)\n')
            self.assertEqual(settings(path, {}), ('test-value', 'example-model', 4))
            self.assertEqual(settings(path, {'ANTHROPIC_API_KEY': 'override'})[0], 'override')
            with self.assertRaises(ValueError): settings(path, {'NPC_MAX_MODEL_CALLS': '9999'})

    def test_loopback_health_and_unconfigured_http_contract(self):
        server = create_server(NPCDialogue(), 0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            conn = http.client.HTTPConnection(*server.server_address, timeout=3)
            conn.request('GET', '/health')
            response = conn.getresponse()
            self.assertEqual(response.status, 200)
            self.assertFalse(json.loads(response.read())['provider_ready'])
            conn.close()
            conn = http.client.HTTPConnection(*server.server_address, timeout=3)
            conn.request('POST', '/v1/npc/turn', json.dumps(payload()), {'Content-Type': 'application/json'})
            response = conn.getresponse()
            self.assertEqual(response.status, 503)
            self.assertEqual(json.loads(response.read()), {'error': 'provider_unconfigured'})
            conn.close()
        finally:
            server.shutdown(); server.server_close(); thread.join(2)

    def test_browser_origin_and_unexpected_host_are_rejected(self):
        server = create_server(NPCDialogue(), 0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            for headers in [{'Origin': 'https://example.com'}, {'Host': 'not-local.invalid'}]:
                conn = http.client.HTTPConnection(*server.server_address, timeout=3)
                conn.request('GET', '/health', headers=headers)
                response = conn.getresponse()
                self.assertEqual(response.status, 403)
                response.read(); conn.close()
        finally:
            server.shutdown(); server.server_close(); thread.join(2)


@unittest.skipIf(anthropic is None, 'Install backend/requirements.txt to exercise the official SDK')
class NPCSDKTests(unittest.TestCase):
    def service(self, handler, **options):
        client = anthropic.Anthropic(
            api_key='test-key-not-a-credential', base_url='https://mock.invalid',
            max_retries=0, open_telemetry=False,
            http_client=httpx2.Client(transport=httpx2.MockTransport(handler)),
        )
        self.addCleanup(client.close)
        return NPCDialogue(client, **options)

    def response(self, blocks, stop='end_turn'):
        return httpx2.Response(200, json={
            'id': 'msg_test', 'type': 'message', 'role': 'assistant', 'model': 'claude-haiku-5-5',
            'content': blocks, 'stop_reason': stop, 'stop_sequence': None,
            'usage': {'input_tokens': 20, 'output_tokens': 15},
        })

    def test_real_sdk_reads_facts_recalls_own_memory_then_replies(self):
        requests = []
        def handler(request):
            self.assertEqual(request.url.host, 'mock.invalid')
            body = json.loads(request.content)
            requests.append(body)
            if len(requests) == 1:
                self.assertEqual(request.headers['authorization'], 'Bearer test-key-not-a-credential')
                self.assertEqual(request.headers['anthropic-version'], '2026-10-21')
                self.assertEqual({tool['name'] for tool in body['tools']}, {'read_room_facts', 'recall_my_conversation'})
                return self.response([{'type': 'tool_use', 'id': 'tool_1', 'name': 'read_room_facts', 'input': {}}], 'tool_use')
            if len(requests) == 2:
                result = json.loads(body['messages'][-1]['content'][0]['content'])
                self.assertIn('double doors', result['facts']['classroom'])
                return self.response([{'type': 'tool_use', 'id': 'tool_2', 'name': 'recall_my_conversation', 'input': {}}], 'tool_use')
            remembered = json.loads(body['messages'][-1]['content'][0]['content'])
            self.assertEqual(remembered['topics'], ['day'])
            return self.response([{'type': 'text', 'text': 'The classroom double doors are beside the desk. Good to see you again!'}])
        result = self.service(handler).reply(payload())
        self.assertEqual(result['mode'], 'claude')
        self.assertEqual(result['request_id'], 'test-turn-1')
        self.assertEqual(result['npc_id'], 'ReceptionA')
        self.assertEqual(len(requests), 3)

    def test_tool_loop_stops_at_three_requests(self):
        requests = []
        def handler(request):
            requests.append(True)
            return self.response([{'type': 'tool_use', 'id': f'tool_{len(requests)}', 'name': 'read_room_facts', 'input': {}}], 'tool_use')
        with self.assertRaisesRegex(DialogueError, 'step_limit'):
            self.service(handler).reply(payload())
        self.assertEqual(len(requests), 3)

    def test_unknown_or_argument_bearing_tools_are_not_executed(self):
        for tool in [{'name': 'write_file', 'input': {}}, {'name': 'recall_my_conversation', 'input': {'npc_id': 'ReceptionB'}}]:
            seen = []
            def handler(request):
                body = json.loads(request.content)
                if not seen:
                    seen.append(True)
                    return self.response([{'type': 'tool_use', 'id': 'tool_1', **tool}], 'tool_use')
                self.assertTrue(body['messages'][-1]['content'][0]['is_error'])
                self.assertNotIn('ReceptionB', body['messages'][-1]['content'][0]['content'])
                return self.response([{'type': 'text', 'text': 'Let me stick to what I know.'}])
            self.service(handler).reply(payload())

    def test_timeout_and_provider_error_are_sanitized_without_retry(self):
        for status in [401, 429, 500]:
            requests = []
            def handler(_request):
                requests.append(True)
                return httpx2.Response(status, json={'error': {'type': 'api_error', 'message': 'private test detail'}})
            with self.assertRaisesRegex(DialogueError, '^provider_error$'):
                self.service(handler).reply(payload())
            self.assertEqual(len(requests), 1)
        def timeout(request):
            raise httpx2.ReadTimeout('private detail', request=request)
        with self.assertRaisesRegex(DialogueError, '^provider_timeout$'):
            self.service(timeout).reply(payload())

    def test_truncated_empty_and_oversized_output_is_rejected(self):
        for text, stop in [('', 'end_turn'), ('x' * 601, 'end_turn'), ('partial', 'max_tokens')]:
            with self.subTest(stop=stop, length=len(text)), self.assertRaises(DialogueError):
                self.service(lambda _r: self.response([{'type': 'text', 'text': text}], stop)).reply(payload())

    def test_held_out_compatible_profile_needs_no_adapter_change(self):
        profiles = copy.deepcopy(load_profiles())
        profiles['profiles']['LabVisitor'] = {**profiles['profiles']['ReceptionA'], 'label': 'Visiting Builder', 'persona': 'A concise visiting Builder.'}
        def handler(request):
            self.assertIn('Visiting Builder', json.loads(request.content)['system'])
            return self.response([{'type': 'text', 'text': 'Hello from the visiting Builder.'}])
        result = self.service(handler, profiles=profiles).reply(payload('LabVisitor', 'day'))
        self.assertEqual(result['npc_id'], 'LabVisitor')


if __name__ == '__main__':
    unittest.main()
