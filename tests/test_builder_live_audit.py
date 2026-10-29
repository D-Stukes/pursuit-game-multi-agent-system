"""Exercise the live-test audit with the real SDK and an offline transport."""
import asyncio
import json
import unittest
import anthropic
import httpx2
from tools.verify_builder_live import observed_factory


class LiveAuditTests(unittest.TestCase):
    def factory(self, transport):
        return lambda: anthropic.AsyncAnthropic(api_key='fixture-secret-not-real',
            base_url='https://audit-fixture.invalid', max_retries=0, open_telemetry=False,
            http_client=httpx2.AsyncClient(transport=httpx2.MockTransport(transport)))

    def execute(self, factory):
        async def run():
            async with factory() as client:
                return await client.messages.create(model='claude-haiku-5-5',max_tokens=180,
                    messages=[{'role':'user','content':'Give a game hint.'}])
        return asyncio.run(run())

    def test_audit_records_provider_identity_and_usage_without_key(self):
        def transport(request):
            self.assertEqual(request.url.host,'audit-fixture.invalid')
            return httpx2.Response(200,headers={'request-id':'req_live_audit_fixture'},json={
                'id':'msg_audit','type':'message','role':'assistant','model':'claude-haiku-5-5',
                'content':[{'type':'tool_use','id':'read_1','name':'read_current_objective','input':{}}],
                'stop_reason':'tool_use','stop_sequence':None,'usage':{'input_tokens':24,'output_tokens':18}})
        audit=[]
        result=self.execute(observed_factory(self.factory(transport),audit))
        self.assertEqual(result.stop_reason,'tool_use')
        self.assertEqual(audit[0]['request_id'],'req_live_audit_fixture')
        self.assertEqual(audit[0]['input_tokens'],24)
        self.assertEqual(audit[0]['tool_calls'],['read_current_objective'])
        self.assertNotIn('fixture-secret',json.dumps(audit))
        self.assertNotIn('authorization',json.dumps(audit))

    def test_provider_error_logs_only_type_and_status(self):
        def transport(_request):
            return httpx2.Response(401,json={'error':{'type':'authentication_error',
                'message':'private detail fixture-secret-not-real'}})
        audit=[]
        with self.assertRaises(anthropic.AuthenticationError):
            self.execute(observed_factory(self.factory(transport),audit))
        self.assertEqual(audit[0]['status_code'],401)
        self.assertEqual(audit[0]['error_type'],'AuthenticationError')
        self.assertNotIn('private detail',json.dumps(audit))
        self.assertNotIn('fixture-secret',json.dumps(audit))


if __name__=='__main__':unittest.main()
