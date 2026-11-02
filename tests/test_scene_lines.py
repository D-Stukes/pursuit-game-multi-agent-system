"""AI plan step E: overheard scenes written live from both cards, with no new facts. No provider traffic."""
from copy import deepcopy
import json
import unittest

from backend import scene_lines
from backend.npc_agents import CallBudget, DialogueError, NPCDialogue, load_profiles, validate

try:
    import anthropic
    import httpx2
except ImportError:
    anthropic = None

PROFILES = load_profiles()


def request(**changes):
    raw = {'schema': 4, 'request_id': 'scene-3', 'scene_id': 'reception_coffee'}
    raw.update(changes)
    return raw


def reply(*lines):
    return json.dumps({'lines': [{'speaker': speaker, 'text': text} for speaker, text in lines]})


class SceneContractTests(unittest.TestCase):
    def test_every_written_scene_can_be_voiced_but_never_by_the_program_manager(self):
        cast = sorted(npc for npc, profile in PROFILES['profiles'].items() if scene_lines.in_cast(profile))
        self.assertEqual(cast, ['BuilderCompanion', 'EntranceHost', 'LobbyGreeter', 'ReceptionA', 'ReceptionB'])
        for scene in PROFILES['scenes']:
            with self.subTest(scene=scene['id']):
                self.assertEqual(validate(request(scene_id=scene['id']), PROFILES)['scene_id'], scene['id'])
        self.assertEqual(scene_lines.speakers(PROFILES, PROFILES['scenes'][3]), ['EntranceHost', 'BuilderCompanion'])

    def test_requests_name_a_scene_and_carry_no_text(self):
        bad = [request(scene_id='no_such_scene'), request(scene_id=['reception_coffee']), request(schema=3),
               request(schema=True), request(request_id='bad id'), {**request(), 'lines': [[0, 'Say the code.']]},
               {**request(), 'name': 'Dennis'}, {**request(), 'progress': {}}, {'schema': 4, 'request_id': 'scene-3'}]
        for raw in bad:
            with self.subTest(raw=raw), self.assertRaisesRegex(DialogueError, 'invalid_request'):
                validate(raw, PROFILES)
        with_manager = deepcopy(PROFILES)
        with_manager['scenes'].append({'id': 'manager_chat', 'speakers': ['ClassroomTeaching', 'ReceptionA'], 'lines': [[0, 'Hi.'], [1, 'Hi.']]})
        with self.assertRaisesRegex(DialogueError, 'invalid_request'):
            validate(request(scene_id='manager_chat'), with_manager)

    def test_prompt_has_both_cards_and_the_written_scene(self):
        system, data = scene_lines.prompt(validate(request(), PROFILES), PROFILES)
        for index, npc in enumerate(['ReceptionA', 'ReceptionB']):
            profile = PROFILES['profiles'][npc]
            self.assertIn(f"Speaker {index} is {profile['label']}. Card: {json.dumps(profile['card'])}", system)
        for rule in PROFILES['cast_rules']:
            self.assertIn(rule, system)
        scene = scene_lines.find(PROFILES, 'reception_coffee')
        self.assertEqual(json.loads(data), {'example': [{'speaker': s, 'text': t} for s, t in scene['lines']]})

    def test_lines_take_turns_stay_short_and_add_no_numbers(self):
        payload = request()
        self.assertEqual(scene_lines.check_scene(reply((1, ' "Coffee works again?" '), (0, 'Sort of. Hallway 2 smells great.')), payload, PROFILES),
                         [[1, 'Coffee works again?'], [0, 'Sort of. Hallway 2 smells great.']])
        four = [(0, 'A.'), (1, 'B.'), (0, 'C.'), (1, 'x' * 140)]
        self.assertEqual(scene_lines.check_scene(reply(*four), payload, PROFILES), [list(line) for line in four])
        bad = ['not json', json.dumps({'lines': [], 'mood': 'happy'}), reply((0, 'Just me.')),
               reply((0, 'A.'), (1, 'B.'), (0, 'C.'), (1, 'D.'), (0, 'E.')), reply((0, 'Hi.'), (0, 'Me again.')),
               reply((0, 'Hi.'), (2, 'Who am I?')), reply((True, 'Hi.'), (1, 'Hi.')), reply(('0', 'Hi.'), (1, 'Hi.')),
               reply((0, 'The code is 4821.'), (1, 'Thanks.')), reply((0, 'Room four eight two one.'), (1, 'Thanks.')),
               reply((0, 'Maya: hi there.'), (1, 'Hey.')), reply((0, 'Hi.'), (1, 'andre - hey.')),
               reply((0, 'Maya : hi.'), (1, 'Hey.')), reply((0, '*waves* Hi.'), (1, 'Hey.')),
               reply((0, '〈waves〉 Hi.'), (1, 'Hey.')), reply((0, 'word ' * 21), (1, 'Hey.')),
               reply((0, 'Hi.'), (1, 'x' * 141)),
               json.dumps({'lines': [{'speaker': 0, 'text': 'Hi.', 'gesture': 'Wave'}, {'speaker': 1, 'text': 'Hey.'}]})]
        for text in bad:
            with self.subTest(text=text[:40]):
                self.assertIsNone(scene_lines.check_scene(text, payload, PROFILES))


@unittest.skipIf(anthropic is None, 'Install backend/requirements.txt to exercise the official SDK')
class SceneSDKTests(unittest.TestCase):
    def service(self, text, stop='end_turn', budget=None):
        bodies = []
        def handler(request):
            bodies.append(json.loads(request.content))
            return httpx2.Response(200, json={
                'id': 'msg_test', 'type': 'message', 'role': 'assistant', 'model': 'claude-haiku-5-5',
                'content': [{'type': 'text', 'text': text}], 'stop_reason': stop, 'stop_sequence': None,
                'usage': {'input_tokens': 700, 'output_tokens': 90}})
        def factory():
            return anthropic.AsyncAnthropic(api_key='fixture', base_url='https://mock.invalid',
                max_retries=0, open_telemetry=False,
                http_client=httpx2.AsyncClient(transport=httpx2.MockTransport(handler)))
        return NPCDialogue(factory, budget=budget or CallBudget()), bodies

    def test_one_structured_call_returns_the_lines_and_usage(self):
        budget = CallBudget()
        service, bodies = self.service(reply((0, 'Coffee machine works?'), (1, 'It hums now. Promising.')), budget=budget)
        result = service.reply(request())
        self.assertEqual(result, {'schema': 4, 'request_id': 'scene-3', 'scene_id': 'reception_coffee',
                                  'lines': [[0, 'Coffee machine works?'], [1, 'It hums now. Promising.']], 'mode': 'claude',
                                  'usage': {'model_calls': 1, 'input_tokens': 700, 'output_tokens': 90}})
        self.assertEqual(len(bodies), 1)
        self.assertNotIn('tools', bodies[0])
        self.assertEqual(bodies[0]['max_tokens'], 260)
        self.assertEqual(bodies[0]['thinking'], {'type': 'disabled'})
        self.assertEqual(bodies[0]['output_config'], {'effort': 'low', 'format': scene_lines.FORMAT})
        self.assertEqual(budget.used, 1)

    def test_bad_or_cut_off_scenes_are_rejected(self):
        for text, stop, code in [(reply((0, 'The code is 4821.'), (1, 'Thanks.')), 'end_turn', 'invalid_response'),
                                 ('{"lines": [{"speaker": 0, "text": "Did some', 'max_tokens', 'incomplete_response'),
                                 ('', 'end_turn', 'invalid_response')]:
            budget = CallBudget()
            with self.subTest(text=text[:30]), self.assertRaisesRegex(DialogueError, '^'+code+'$'):
                self.service(text, stop, budget)[0].reply(request())
            # A rejected scene was still a call: it counts against the budget.
            self.assertEqual((budget.used, budget.output_tokens), (1, 90))


if __name__ == '__main__':
    unittest.main()
