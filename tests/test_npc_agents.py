"""No provider traffic: exercise the installed SDK through its HTTP transport."""
import copy
import asyncio
import http.client
import json
import os
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from backend.npc_agents import CallBudget, DialogueError, NPCDialogue, load_profiles, validate
from backend.server import create_server, settings
from tools.npc_runtime import game_environment, local_agent_service

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
        with self.assertRaises(DialogueError):
            validate(payload(topic='ambient'), profiles)

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

    def test_optional_launcher_starts_and_stops_without_key(self):
        root = Path(__file__).resolve().parents[1]
        if not (root/'.venv').is_dir(): self.skipTest('Project environment not installed')
        with local_agent_service(root, environment={**os.environ,'ANTHROPIC_API_KEY':''}) as url:
            self.assertIsNone(url)

    def test_backend_keeps_key_but_game_environment_removes_it(self):
        root = Path(__file__).resolve().parents[1]
        if not (root/'.venv').is_dir(): self.skipTest('Project environment not installed')
        backend_env = {**os.environ,'ANTHROPIC_API_KEY':'fixture-key-not-a-credential',
                       'ANTHROPIC_AUTH_TOKEN':'','CLAUDE_CODE_OAUTH_TOKEN':'fixture-token','PRESERVED_SETTING':'yes'}
        with local_agent_service(root, environment=backend_env) as url:
            self.assertTrue(url.startswith('http://127.0.0.1:'))
            host, port = url.removeprefix('http://').split(':')
            conn = http.client.HTTPConnection(host,int(port),timeout=3)
            conn.request('GET','/health');response=conn.getresponse()
            self.assertTrue(json.loads(response.read())['provider_ready']);conn.close()
            game_env = game_environment(backend_env)
            self.assertNotIn('ANTHROPIC_API_KEY',game_env)
            self.assertNotIn('ANTHROPIC_AUTH_TOKEN',game_env)
            self.assertNotIn('CLAUDE_CODE_OAUTH_TOKEN',game_env)
            self.assertEqual(game_env['PRESERVED_SETTING'],'yes')


@unittest.skipIf(anthropic is None, 'Install backend/requirements.txt to exercise the official SDK')
class NPCSDKTests(unittest.TestCase):
    def service(self, handler, **options):
        def factory():
            return anthropic.AsyncAnthropic(
                api_key='test-key-not-a-credential', base_url='https://mock.invalid',
                max_retries=0, open_telemetry=False,
                http_client=httpx2.AsyncClient(transport=httpx2.MockTransport(handler)),
            )
        return NPCDialogue(factory, **options)

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

    def test_ambient_uses_one_request_with_public_memory_only(self):
        calls = []
        def handler(request):
            body = json.loads(request.content)
            calls.append(body)
            self.assertEqual(body['tools'], [])
            prompt = json.loads(body['messages'][0]['content'])
            self.assertEqual(prompt['public_memory']['topics'], ['ambient'])
            self.assertIn('facts', prompt)
            return self.response([{'type':'text','text':'See you in class!'}])
        raw = payload(topic='ambient')
        raw['memory'] = {'turn_count':1,'topics':['ambient'],'lines':['Public room conversation.']}
        self.service(handler).reply(raw)
        self.assertEqual(len(calls), 1)

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

    def test_elapsed_deadline_cancels_slow_provider_and_closes_client(self):
        cancelled = []
        clients = []
        async def dribbling(_request):
            try:
                # The HTTP inactivity timeout would not interrupt this transport.
                # Only the outer elapsed deadline cancels the active operation.
                while True: await asyncio.sleep(.01)
            finally:
                cancelled.append(True)
        def factory():
            client=anthropic.AsyncAnthropic(api_key='fixture',base_url='https://mock.invalid',
                max_retries=0,open_telemetry=False,
                http_client=httpx2.AsyncClient(transport=httpx2.MockTransport(dribbling)))
            clients.append(client)
            return client
        start=time.monotonic()
        with patch('backend.npc_agents.DEADLINE_SECONDS',.08):
            with self.assertRaisesRegex(DialogueError,'^provider_timeout$'):
                NPCDialogue(factory).reply(payload())
        self.assertLess(time.monotonic()-start,.5)
        self.assertEqual(cancelled,[True])
        self.assertTrue(clients[0].is_closed())

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
