"""Explicit, capped live Claude test through rendered Godot. Never run by default.

The real key stays in this local backend process. The audit retains only game
observations, provider IDs/usage and generated game dialogue, never credentials.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from godot_runtime import ROOT, find_godot
from npc_runtime import game_environment
sys.path.insert(0, str(ROOT))
from backend.npc_agents import CallBudget, DialogueError, NPCDialogue, make_client
from backend.server import create_server, settings


def observed_factory(factory, audit):
    def create_client():
        client = factory()
        create = client.messages.create

        async def observed_create(**kwargs):
            item = {'model': kwargs['model'], 'messages': len(kwargs['messages']),
                    'max_output_tokens': kwargs['max_tokens'],
                    'thinking': kwargs.get('thinking',{}).get('type','default'),
                    'effort': kwargs.get('output_config',{}).get('effort','default')}
            audit.append(item)
            started = time.monotonic()
            try:
                response = await create(**kwargs)
                item.update(request_id=getattr(response, '_request_id', None),
                            model_returned=response.model, stop_reason=response.stop_reason,
                            input_tokens=response.usage.input_tokens, output_tokens=response.usage.output_tokens,
                            content_types=[b.type for b in response.content],
                            tool_calls=[b.name for b in response.content if b.type == 'tool_use'])
                return response
            except BaseException as error:
                item.update(error_type=type(error).__name__, status_code=getattr(error, 'status_code', None))
                raise
            finally:
                item['elapsed_ms'] = round((time.monotonic()-started)*1000)

        client.messages.create = observed_create
        return client
    return create_client


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='Private live-test evidence directory')
    parser.add_argument('--topics', nargs='+', choices=('hint','steps','next'), default=['hint','steps','next'])
    parser.add_argument('--max-model-requests', type=int, choices=range(1,10), default=9)
    args = parser.parse_args()
    if len(args.topics)>3 or len(set(args.topics))!=len(args.topics):
        parser.error('Choose one to three distinct help topics')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # User invokes this script explicitly; the game/default launcher never does.
    key, model, _configured_limit = settings()
    if not key.strip():
        print('LIVE_BUILDER_BLOCKED no_local_key')
        return 2
    audit = []
    budget = CallBudget(total=args.max_model_requests, per_minute=9)
    factory = observed_factory(make_client(key), audit)

    class AuditedDialogue(NPCDialogue):
        def __init__(self):
            super().__init__(factory, model=model, budget=budget)
            self.turns = []

        def reply(self, payload):
            if (not isinstance(payload, dict) or payload.get('schema') != 2
                    or payload.get('npc_id') != 'BuilderCompanion' or len(self.turns) >= len(args.topics)):
                raise DialogueError('invalid_request')
            turn = {'topic': payload.get('topic'), 'schema': payload.get('schema')}
            self.turns.append(turn)
            started = time.monotonic()
            try:
                result = super().reply(payload)
                turn.update(accepted=True, tools_used=result.get('tools_used', []), usage=result.get('usage', {}))
                return result
            except DialogueError as error:
                turn.update(accepted=False, reason=str(error))
                raise
            finally:
                turn['elapsed_ms'] = round((time.monotonic()-started)*1000)

    service = AuditedDialogue()
    server = create_server(service, 0)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    paths = ['backend/npc_agents.py', 'backend/builder_help.py', 'backend/server.py',
             'backend/requirements.txt', 'tools/verify_builder_live.py', 'tools/npc_runtime.py',
             'godot/game/NPCConversations.gd', 'godot/game/NPCConversationState.gd',
             'godot/game/NPCServiceClient.gd', 'godot/developer/tests/play_builder.gd',
             'godot/assets/characters/npc-dialogue.json']
    pins = {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in paths}
    receipt = {'mode': 'live', 'fixture': False, 'real_key_used': True, 'model': model,
               'max_model_requests': args.max_model_requests, 'max_player_help_turns': len(args.topics),
               'topics':args.topics,'source_hashes': pins}
    command = [find_godot(), '--path', str(ROOT/'godot'), '--log-file', str(output/'engine.log'),
               '--script', 'res://developer/tests/play_builder.gd', '--', '--live-api',
               '--live-topics='+','.join(args.topics),
               '--npc-provider=claude', '--npc-agent-url=http://127.0.0.1:'+str(server.server_address[1]),
               '--output='+str(output)]
    try:
        with (output/'game-console.log').open('w', encoding='utf-8') as console:
            result = subprocess.run(command, env=game_environment(), stdout=console,
                                    stderr=subprocess.STDOUT, check=False, timeout=100)
        receipt['engine_returncode'] = result.returncode
    except subprocess.TimeoutExpired:
        receipt.update(engine_returncode=None, error='game_timeout')
    finally:
        server.shutdown();server.server_close();worker.join(2)
        receipt.update(provider_requests=audit, turns=service.turns, model_requests=budget.used,
                       input_tokens=budget.input_tokens, output_tokens=budget.output_tokens)
        receipt['source_unchanged'] = all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in pins.items())
        text = json.dumps(receipt, indent=2)
        if key in text:
            raise RuntimeError('Credential detected in live audit')
        (output/'live-receipt.json').write_text(text, encoding='utf-8')
    passed = (receipt.get('engine_returncode') == 0 and receipt['source_unchanged']
              and len(service.turns) == len(args.topics) and all(t.get('accepted') for t in service.turns)
              and 1 <= budget.used <= args.max_model_requests and all(p.get('request_id') for p in audit))
    print('LIVE_BUILDER', 'PASS' if passed else 'FAIL', json.dumps({
        'model': model, 'player_turns': len(service.turns), 'model_requests': budget.used,
        'input_tokens': budget.input_tokens, 'output_tokens': budget.output_tokens,
        'engine_returncode': receipt.get('engine_returncode')}))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
