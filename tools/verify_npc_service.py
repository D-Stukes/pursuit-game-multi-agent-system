"""Godot -> loopback HTTP -> official SDK -> in-process mock transport.

No key, provider network call or generated-content claim is involved. May run
against an isolated fresh Godot fixture with --project.
"""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

from godot_runtime import ROOT, find_godot
sys.path.insert(0, str(ROOT))

import anthropic
import httpx2
from backend.npc_agents import CallBudget, NPCDialogue
from backend.server import create_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=ROOT/'godot')
    args = parser.parse_args()
    project = args.project.resolve()
    source_paths = [
        'backend/npc_agents.py', 'backend/server.py', 'backend/requirements.txt',
        'tools/npc_runtime.py', 'tools/run_game.py', 'tools/godot_runtime.py',
        'tools/verify_npc_service.py', 'godot/assets/characters/npc-dialogue.json',
    ]
    source_hashes = {path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
                     for path in source_paths}
    evidence = project/'.godot/playtest'
    evidence.mkdir(parents=True, exist_ok=True)
    requests = []
    calls_lock = threading.Lock()

    def transport(request):
        if request.url.host != 'sdk-fixture.invalid':
            raise RuntimeError('Unexpected network destination')
        body = json.loads(request.content)
        with calls_lock:
            requests.append({'model': body['model'], 'messages': len(body['messages'])})
        if len(body['messages']) == 1 and body.get('tools'):
            content = [{'type':'tool_use','id':'fixture_tool','name':'read_room_facts','input':{}}]
            stop = 'tool_use'
        else:
            label = body['system'].split(' in the Pursuit game.', 1)[0].removeprefix('You are ')
            content = [{'type':'text','text':'SDK fixture reply for '+label+'.'}]
            stop = 'end_turn'
        return httpx2.Response(200, json={'id':'msg_fixture','type':'message','role':'assistant',
            'model':'claude-haiku-5-5','content':content,'stop_reason':stop,'stop_sequence':None,
            'usage':{'input_tokens':30,'output_tokens':20}})

    def client_factory():
        return anthropic.AsyncAnthropic(api_key='fixture-key-not-a-credential',
            base_url='https://sdk-fixture.invalid', max_retries=0, open_telemetry=False,
            http_client=httpx2.AsyncClient(transport=httpx2.MockTransport(transport)))
    dialogue = NPCDialogue(client_factory, budget=CallBudget(200,200))

    class Fixture:
        def __init__(self): self.client = client_factory
        def reply(self, payload):
            if payload.get('topic') == 'work': time.sleep(.65)
            result = dialogue.reply(payload)
            if payload.get('topic') == 'day': result['npc_id'] = 'wrong-identity'
            return result

    server = create_server(Fixture(),0)
    worker = threading.Thread(target=server.serve_forever,daemon=True)
    worker.start()
    redirect_hits = []
    class SpyHandler(BaseHTTPRequestHandler):
        def log_message(self,*_args): pass
        def do_POST(self):
            redirect_hits.append(True)
            self.send_response(200);self.send_header('Content-Length','0');self.end_headers()
        do_GET = do_POST
    spy = ThreadingHTTPServer(('127.0.0.1',0),SpyHandler)
    class RedirectHandler(BaseHTTPRequestHandler):
        def log_message(self,*_args): pass
        def do_POST(self):
            self.send_response(307)
            self.send_header('Location',f'http://127.0.0.1:{spy.server_address[1]}/unexpected')
            self.send_header('Content-Length','0');self.send_header('Connection','close');self.end_headers()
            self.close_connection=True
        do_GET = do_POST
    redirect = ThreadingHTTPServer(('127.0.0.1',0),RedirectHandler)
    other_workers=[]
    for extra in (spy,redirect):
        thread=threading.Thread(target=extra.serve_forever,daemon=True);thread.start();other_workers.append(thread)
    log = evidence/'npc-service-engine.log'
    try:
        command = [find_godot(),'--headless','--path',str(project),'--log-file',str(log),
                   '--script','res://developer/tests/verify_npc_service.gd','--',
                   '--fixture-url=http://127.0.0.1:'+str(server.server_address[1]),
                   '--redirect-url=http://127.0.0.1:'+str(redirect.server_address[1])]
        result = subprocess.run(command,check=False,timeout=60)
    finally:
        server.shutdown();server.server_close();worker.join(2)
        for extra in (spy,redirect): extra.shutdown();extra.server_close()
        for thread in other_workers: thread.join(2)
    receipt = {'real_sdk':anthropic.__version__,'engine_http':'actual loopback HTTP',
               'provider_transport':'in-process httpx2.MockTransport','provider_network_calls':0,
               'real_key_used':False,'sdk_requests':requests,'engine_returncode':result.returncode,
               'godot_project':str(project),'engine_log':str(log),'redirect_destination_requests':len(redirect_hits),
               'python_executable':sys.executable,'source_hashes':source_hashes}
    if any(hashlib.sha256((ROOT/path).read_bytes()).hexdigest() != digest
           for path, digest in source_hashes.items()):
        raise RuntimeError('Source changed during the wire verification')
    (evidence/'npc-service-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print('NPC_SERVICE_FIXTURE',json.dumps({'engine_returncode':result.returncode,'sdk_requests':len(requests),'provider_network_calls':0}))
    return result.returncode if not redirect_hits else 1


if __name__ == '__main__':
    sys.exit(main())
