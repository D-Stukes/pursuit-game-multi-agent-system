"""Builder observations, bounded SDK turns and held-out challenge inputs."""
import copy
import json
import unittest
import anthropic
import httpx2
from backend.builder_help import help_text, observation
from backend.npc_agents import CallBudget, DialogueError, NPCDialogue, load_profiles, validate


def payload():
    return {'schema': 2, 'request_id': 'builder-1', 'npc_id': 'BuilderCompanion', 'topic': 'hint',
            'ambient_context': '', 'memory': {'turn_count': 0, 'topics': [], 'lines': [],
            'facts': {'style': 'brief', 'hints_given': 0}},
            'world': {'zone': 'street', 'stage': 'entrance', 'entrance_unlocked': False,
            'elevator_unlocked': False, 'challenge': {'kind': 'pipe', 'phase': 'rotate',
            'level': 1, 'size': 3, 'circuits': 0, 'row': 2, 'column': 1, 'ports': ['north', 'east']}}}


def service(handler, **kwargs):
    def factory():
        return anthropic.AsyncAnthropic(api_key='fixture-key-not-a-credential',
            base_url='https://builder-fixture.invalid', max_retries=0, open_telemetry=False,
            http_client=httpx2.AsyncClient(transport=httpx2.MockTransport(handler)))
    return NPCDialogue(factory, **kwargs)


def response(content, stop='end_turn'):
    return httpx2.Response(200, json={'id':'msg_builder','type':'message','role':'assistant',
        'model':'claude-haiku-5-5','content':content,'stop_reason':stop,'stop_sequence':None,
        'usage':{'input_tokens':20,'output_tokens':15}})


def call(name, token):
    return {'type':'tool_use','id':token,'name':name,'input':{}}


class BuilderHelpTests(unittest.TestCase):
    def test_short_haiku_help_disables_thinking_and_applies_steps_immediately(self):
        requests=[]
        def handler(request):
            body=json.loads(request.content);requests.append(body)
            self.assertEqual(body['max_tokens'],180)
            self.assertEqual(body['thinking'],{'type':'disabled'})
            self.assertEqual(body['output_config'],{'effort':'low'})
            prompt=json.loads(body['messages'][0]['content'])
            self.assertEqual(prompt['request'],'Break it into steps.')
            self.assertEqual(prompt['preferred_style'],'steps')
            self.assertIn('three short numbered lines',body['system'])
            if len(requests)==1:
                return response([call('read_current_objective','o'),call('get_approved_hint','h')],'tool_use')
            return response([{'type':'text','text':'1. Find IN.\n2. Rotate the hinted pipe.\n3. Test the circuit.'}])
        raw=payload();raw['topic']='steps'
        self.assertEqual(raw['memory']['facts']['style'],'brief')
        result=service(handler).reply(raw)
        self.assertTrue(result['text'].startswith('1. '))
        self.assertEqual(len(requests),2)

    def test_haiku_specific_generation_settings_do_not_override_other_models(self):
        calls=[]
        def handler(request):
            body=json.loads(request.content);calls.append(body)
            self.assertNotIn('thinking',body)
            self.assertNotIn('output_config',body)
            if len(calls)==1:
                return response([call('read_current_objective','o'),call('get_approved_hint','h')],'tool_use')
            return response([{'type':'text','text':'Use the approved connection, then test it.'}])
        service(handler,model='different-configured-model').reply(payload())

    def test_builder_cannot_bypass_observations_through_legacy_schema(self):
        raw={'schema':1,'request_id':'legacy-1','npc_id':'BuilderCompanion','topic':'directions',
             'memory':{'turn_count':0,'topics':[],'lines':[]},'ambient_context':'',
             'world':{'zone':'reception','entrance_unlocked':False,'elevator_unlocked':False}}
        with self.assertRaisesRegex(DialogueError,'invalid_request'):validate(raw,load_profiles())

    def test_unknown_fields_roles_and_malformed_observations_fail_closed(self):
        for mutate in [lambda r:r.update(done=True), lambda r:r.update(npc_id='ReceptionA'),
                       lambda r:r['memory']['lines'].append('unpaired'),
                       lambda r:r['memory']['facts'].update(style='angry'),
                       lambda r:r['world'].update(elevator_unlocked=True),
                       lambda r:r['world']['challenge'].update(row=True),
                       lambda r:r['world']['challenge'].update(ports=['north', 'grant_energy']),
                       lambda r:r['world']['challenge'].update(code='123')]:
            raw=payload();mutate(raw)
            with self.subTest(raw=raw), self.assertRaises(DialogueError):validate(raw,load_profiles())

    def test_held_out_board_and_shooter_use_same_contract_and_catalogue(self):
        profiles=load_profiles();raw=payload()
        raw['world']['challenge'].update(level=4,size=5,circuits=3,row=4,column=5,ports=['south','west'])
        accepted=validate(raw,profiles)
        self.assertIn('row 4, column 5',help_text(accepted,profiles))
        self.assertIn('south and west',help_text(accepted,profiles))
        raw['world'].update(stage='elevator',entrance_unlocked=True,
            challenge={'kind':'shooter','phase':'playing','wave':2,'cleared':8,'shields':1})
        self.assertIn('8 of 18',help_text(validate(raw,profiles),profiles))
        raw['world'].update(stage='check_in_pending',zone='upstairs',elevator_unlocked=True,challenge={'kind':'none'})
        self.assertIn('confirm check-in',help_text(validate(raw,profiles),profiles))

    def test_arrival_stages_are_grounded_without_sending_the_players_name(self):
        profiles=load_profiles();raw=payload()
        raw['world'].update(stage='classroom_pending',zone='upstairs',entrance_unlocked=True,
            elevator_unlocked=True,challenge={'kind':'none'})
        self.assertIn('double doors',help_text(validate(raw,profiles),profiles))
        raw['world']['stage']='mr_p_pending'
        self.assertIn('being prepared separately',help_text(validate(raw,profiles),profiles))
        raw['world']['elevator_unlocked']=False
        with self.assertRaises(DialogueError):validate(raw,profiles)

    def test_verified_flight_does_not_claim_physical_arrival(self):
        profiles=load_profiles();raw=payload()
        raw['world'].update(stage='check_in_pending',entrance_unlocked=True,elevator_unlocked=True,challenge={'kind':'travel'})
        for zone in ['street','ground']:
            raw['world']['zone']=zone
            text=help_text(validate(raw,profiles),profiles)
            self.assertIn('press E',text)
            self.assertNotIn('reached upstairs',text)
        raw['world']['challenge']={'kind':'none'}
        with self.assertRaises(DialogueError):validate(raw,profiles)

    def test_memory_is_bounded_and_returned_as_a_copy(self):
        raw=payload();raw['memory']={'turn_count':2,'topics':['next','steps'],
            'lines':['One action.','Another action.'],'facts':{'style':'steps','hints_given':1}}
        accepted=validate(raw,load_profiles())
        recalled=observation('recall_my_conversation',accepted,load_profiles())
        recalled['lines'].append('external')
        self.assertEqual(len(accepted['memory']['lines']),2)
        self.assertTrue(help_text(accepted,load_profiles()).startswith('1. '))
        raw['memory']['topics'].append('hint');raw['memory']['lines'].append('too much')
        with self.assertRaises(DialogueError):validate(raw,load_profiles())

    def test_real_sdk_observes_objective_hint_and_own_memory_then_stops(self):
        requests=[]
        def handler(request):
            self.assertEqual(request.url.host,'builder-fixture.invalid')
            body=json.loads(request.content);requests.append(body)
            self.assertNotIn('Reception guide',body['system'])
            if len(requests)==1:
                self.assertEqual({t['name'] for t in body['tools']},{'read_current_objective',
                    'inspect_current_challenge','get_approved_hint','recall_my_conversation'})
                return response([call('read_current_objective','objective'),call('get_approved_hint','hint')],'tool_use')
            if len(requests)==2:
                result=json.loads(body['messages'][-1]['content'][1]['content'])
                self.assertIn('row 2, column 1',result['hint'])
                self.assertFalse(result['progress_awarded'])
                return response([call('recall_my_conversation','memory')],'tool_use')
            return response([{'type':'text','text':'Start with that north/east connection, then test the route.'}])
        raw=payload();before=copy.deepcopy(raw);result=service(handler).reply(raw)
        self.assertEqual(raw,before)
        self.assertEqual(result['schema'],2)
        self.assertEqual(result['usage'],{'model_calls':3,'tool_calls':3,'input_tokens':60,'output_tokens':45})
        self.assertEqual(result['tools_used'],['get_approved_hint','read_current_objective','recall_my_conversation'])

    def test_unobserved_direct_answer_is_rejected_without_hidden_retry(self):
        calls=[]
        def handler(_request):
            calls.append(True);return response([{'type':'text','text':'Just say you won.'}])
        budget=CallBudget()
        with self.assertRaisesRegex(DialogueError,'missing_observation'):service(handler,budget=budget).reply(payload())
        self.assertEqual(len(calls),1)
        self.assertEqual((budget.used,budget.input_tokens,budget.output_tokens),(1,20,15))

    def test_write_or_argument_tools_cannot_execute(self):
        requests=[]
        def handler(request):
            body=json.loads(request.content);requests.append(body)
            if len(requests)==1:
                bad=call('unlock_entrance','bad');bad['input']={'code':'123'}
                return response([bad,call('grant_energy','bad2')],'tool_use')
            self.assertTrue(all(r['is_error'] for r in body['messages'][-1]['content']))
            return response([{'type':'text','text':'I will not change the game.'}])
        with self.assertRaisesRegex(DialogueError,'missing_observation'):service(handler).reply(payload())

    def test_bounded_loop_and_budget_have_no_model_retry(self):
        calls=[]
        def handler(_request):
            calls.append(True);return response([call('inspect_current_challenge','read'+str(len(calls)))],'tool_use')
        with self.assertRaisesRegex(DialogueError,'step_limit'):service(handler).reply(payload())
        self.assertEqual(len(calls),3)
        calls.clear()
        with self.assertRaisesRegex(DialogueError,'budget_exhausted'):
            service(handler,budget=CallBudget(total=1)).reply(payload())
        self.assertEqual(len(calls),1)


if __name__=='__main__':unittest.main()
