"""Explicit, capped live Claude check of everyday replies and overheard scenes. Never run by default.

AI plan step H: speed, cost and the offline fallback. The real key stays in
this process. The receipt keeps provider IDs, timings, usage, check results and
the generated lines, never credentials. The offline check sends nothing: it
points the official SDK at a closed local port.
"""
import argparse
import json
from pathlib import Path
import statistics
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from godot_runtime import ROOT
from verify_builder_live import observed_factory
sys.path.insert(0, str(ROOT))
from backend import character_lines
from backend.npc_agents import CHARACTER_MAX_TOKENS, SCENE_MAX_TOKENS, CallBudget, DialogueError, NPCDialogue, make_client
from backend.server import settings

# One scene per speaker pair, then two more for timing.
SCENES = ('reception_coffee', 'street_trucks', 'lobby_schedule', 'lobby_plants', 'reception_agent_idea', 'street_welcome_day')
# USD per million input/output tokens for prompts under 100K tokens.
PRICES = {'claude-haiku-5-5': (0.10, 0.50)}
SESSION = {'scenes': 17, 'replies': 20}


def reply_turns(profiles):
    """Every topic of every live character, asked once with its first authored answer."""
    turns = []
    for npc_id, profile in profiles['profiles'].items():
        if not character_lines.speaks_live(profile):
            continue
        for topic in profile.get('topics', profiles['topics']):
            question, written = sorted(character_lines.authored_pairs(profiles, npc_id, topic))[0]
            turns.append({'schema': 3, 'request_id': f'live-{len(turns)+1}', 'npc_id': npc_id, 'topic': topic,
                          'question': question, 'written': written, 'memory': {'turn_count': 0, 'topics': []},
                          'progress': {'entrance': True, 'elevator': False, 'checked_in': False, 'classroom': False}})
    return turns


def text_kept(factory, audit):
    """Also keep each response's text on its audit entry, so rejected lines can be read."""
    def create_client():
        client = factory()
        create = client.messages.create

        async def kept(**kwargs):
            response = await create(**kwargs)
            audit[-1]['raw_text'] = next((block.text for block in response.content if block.type == 'text'), '')
            return response
        client.messages.create = kept
        return client
    return create_client


def offline_check(turn):
    """The SDK can't reach the provider: the service reports a fixed error and the game shows written lines."""
    import anthropic

    def factory():
        return anthropic.AsyncAnthropic(api_key='offline-check', base_url='http://127.0.0.1:9',
                                        max_retries=0, open_telemetry=False)
    started = time.monotonic()
    try:
        NPCDialogue(factory, budget=CallBudget(1, 1)).reply(turn)
        reason = 'unexpected_reply'
    except DialogueError as error:
        reason = str(error)
    return {'reason': reason, 'elapsed_ms': round((time.monotonic()-started)*1000),
            'passed': reason in ('provider_error', 'provider_timeout')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='Private live-test evidence directory')
    parser.add_argument('--max-model-requests', type=int, choices=range(1, 19), default=18)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    key, model, _configured_limit = settings()
    if not key.strip():
        print('LIVE_NPC_BLOCKED no_local_key')
        return 2
    audit = []
    budget = CallBudget(total=args.max_model_requests, per_minute=args.max_model_requests)
    service = NPCDialogue(text_kept(observed_factory(make_client(key), audit), audit), model=model, budget=budget)
    turns = reply_turns(service.profiles)
    turns += [{'schema': 4, 'request_id': f'live-scene-{i+1}', 'scene_id': scene_id} for i, scene_id in enumerate(SCENES)]
    results = []
    for turn in turns:
        item = {'schema': turn['schema'], 'who': turn.get('npc_id', turn.get('scene_id')), 'topic': turn.get('topic')}
        if turn['schema'] == 3:
            item['written'] = turn['written']
        started, calls = time.monotonic(), len(audit)
        try:
            result = service.reply(turn)
            item.update(accepted=True, usage=result['usage'], said=result.get('text', result.get('lines')))
        except DialogueError as error:
            item.update(accepted=False, reason=str(error), raw_text=audit[-1].get('raw_text') if len(audit) > calls else None)
        item['elapsed_ms'] = round((time.monotonic()-started)*1000)
        results.append(item)
    offline = offline_check(turns[0])
    input_price, output_price = PRICES.get(model, (None, None))

    def summary(schema, max_tokens):
        done = [r for r in results if r['schema'] == schema]
        times = [r['elapsed_ms'] for r in done]
        # Rejected lines were still paid for, so tokens and cost cover every completed call.
        paid = [a for a in audit if a['max_output_tokens'] == max_tokens and 'input_tokens' in a]
        cost = (statistics.mean(a['input_tokens']*input_price + a['output_tokens']*output_price for a in paid)/1e6
                if paid and input_price is not None else None)
        return {'calls': len(done), 'accepted': sum(r['accepted'] for r in done),
                'median_ms': round(statistics.median(times)) if times else None,
                'max_ms': max(times) if times else None, 'first_ms': times[0] if times else None,
                'mean_input_tokens': round(statistics.mean(a['input_tokens'] for a in paid)) if paid else None,
                'mean_output_tokens': round(statistics.mean(a['output_tokens'] for a in paid)) if paid else None,
                'usd_per_call': cost}
    replies, scenes = summary(3, CHARACTER_MAX_TOKENS), summary(4, SCENE_MAX_TOKENS)
    session = (SESSION['scenes']*scenes['usd_per_call'] + SESSION['replies']*replies['usd_per_call']
               if replies['usd_per_call'] is not None and scenes['usd_per_call'] is not None else None)
    receipt = {'mode': 'live', 'fixture': False, 'real_key_used': True, 'model': model,
               'max_model_requests': args.max_model_requests, 'model_requests': budget.used,
               'input_tokens': budget.input_tokens, 'output_tokens': budget.output_tokens,
               'prices_usd_per_mtok': [input_price, output_price], 'replies': replies, 'scenes': scenes,
               'session_estimate': {**SESSION, 'usd': session}, 'offline': offline,
               'results': results, 'provider_requests': audit}
    text = json.dumps(receipt, indent=2, ensure_ascii=False)
    if key in text:
        raise RuntimeError('Credential detected in live audit')
    (output/'live-npc-receipt.json').write_text(text, encoding='utf-8')
    # The line checks are meant to reject some generated lines, so PASS means every call was made and
    # answered, both kinds produced playable lines and the offline path held; all_checks_passed says
    # whether every line passed.
    receipt['all_checks_passed'] = all(r['accepted'] for r in results)
    passed = (offline['passed'] and budget.used == len(turns) and all(p.get('request_id') for p in audit)
              and replies['accepted'] and scenes['accepted'])
    print('LIVE_NPC', 'PASS' if passed else 'FAIL', json.dumps({
        'model': model, 'model_requests': budget.used, 'all_checks_passed': receipt['all_checks_passed'],
        'replies': replies, 'scenes': scenes,
        'session_usd': session, 'offline': offline}))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
