"""Strict, read-only observations for the player-requested Builder help loop."""
from copy import deepcopy

STAGES = ('entrance', 'elevator', 'check_in_pending', 'classroom_pending', 'mr_p_pending', 'course_active', 'ending_pending')
TOPICS = ('next', 'hint', 'steps')
TOOLS = [
    {'name': name, 'description': description,
     'input_schema': {'type': 'object', 'properties': {}, 'additionalProperties': False}}
    for name, description in (
        ('read_current_objective', 'Read the verified current objective. Required before responding.'),
        ('inspect_current_challenge', 'Read the current pipe board or shooter progress; no solutions or door code.'),
        ('get_approved_hint', 'Read a game-authored hint for the current challenge. Required for hint or steps help.'),
        ('recall_my_conversation', 'Read only this Builder conversation: two recent exchanges and chosen explanation style.'),
    )
]


def integer(value, minimum, maximum):
    return type(value) is int and minimum <= value <= maximum


def validate_builder(raw, profiles):
    """Reject unknown fields and invalid observations, including bool-as-int."""
    def require(condition):
        if not condition:
            raise ValueError('invalid_request')

    require(set(raw) == {'schema', 'request_id', 'npc_id', 'topic', 'memory', 'world', 'ambient_context'})
    require(type(raw['schema']) is int and raw['schema'] == 2 and raw['ambient_context'] == '')
    profile = profiles['profiles'].get(raw['npc_id'], {})
    require(profile.get('mode') == 'builder' and raw['topic'] in TOPICS)
    require(isinstance(raw['request_id'], str) and 0 < len(raw['request_id']) <= 80
            and raw['request_id'].isascii() and all(c.isalnum() or c in '_.:-' for c in raw['request_id']))
    memory = raw['memory']
    require(isinstance(memory, dict) and set(memory) == {'turn_count', 'topics', 'lines', 'facts'})
    require(integer(memory['turn_count'], 0, 1000000))
    require(isinstance(memory['topics'], list) and len(memory['topics']) <= 2
            and all(t in TOPICS for t in memory['topics']))
    require(isinstance(memory['lines'], list) and len(memory['lines']) == len(memory['topics']))
    require(all(isinstance(t, str) and 0 < len(t) <= 600
                and all(ord(c) >= 32 or c == '\n' for c in t) for t in memory['lines']))
    facts = memory['facts']
    require(isinstance(facts, dict) and set(facts) == {'style', 'hints_given'})
    require(facts['style'] in ('brief', 'steps') and integer(facts['hints_given'], 0, memory['turn_count']))
    world = raw['world']
    require(isinstance(world, dict) and set(world) == {'zone', 'stage', 'entrance_unlocked', 'elevator_unlocked', 'challenge'})
    require(world['zone'] in ('street', 'ground', 'upstairs', 'purple_room') and world['stage'] in STAGES)
    require(type(world['entrance_unlocked']) is bool and type(world['elevator_unlocked']) is bool)
    require((world['entrance_unlocked'], world['elevator_unlocked']) ==
            ((False, False) if world['stage'] == 'entrance' else
             (True, False) if world['stage'] == 'elevator' else (True, True)))
    challenge = world['challenge']
    require(isinstance(challenge, dict))
    if world['stage'] == 'entrance':
        require(set(challenge) == {'kind', 'phase', 'level', 'size', 'circuits', 'row', 'column', 'ports'})
        require(challenge['kind'] == 'pipe' and challenge['phase'] in ('rotate', 'test', 'next', 'code'))
        require(integer(challenge['level'], 1, 4) and integer(challenge['size'], 3, 5))
        require(integer(challenge['circuits'], 0, 4) and isinstance(challenge['ports'], list))
        if challenge['phase'] == 'rotate':
            require(integer(challenge['row'], 1, challenge['size']) and integer(challenge['column'], 1, challenge['size']))
            require(len(challenge['ports']) == 2 and len(set(challenge['ports'])) == 2
                    and all(p in ('north', 'east', 'south', 'west') for p in challenge['ports']))
        else:
            require(type(challenge['row']) is int and challenge['row'] == 0
                    and type(challenge['column']) is int and challenge['column'] == 0 and challenge['ports'] == [])
        require(challenge['circuits'] == challenge['level'] - (challenge['phase'] in ('rotate', 'test')))
        require(challenge['phase'] != 'code' or challenge['level'] == 4)
        require(challenge['phase'] != 'next' or challenge['level'] < 4)
    elif world['stage'] == 'elevator':
        require(set(challenge) == {'kind', 'phase', 'wave', 'cleared', 'shields'})
        require(challenge['kind'] == 'shooter' and challenge['phase'] in ('ready', 'playing', 'between', 'lost', 'won'))
        require(integer(challenge['wave'], 0, 3) and integer(challenge['cleared'], 0, 18)
                and integer(challenge['shields'], 0, 3))
    else:
        require(challenge == {'kind': 'travel' if world['zone'] in ('street', 'ground') else 'none'})
    return deepcopy(raw)


def help_text(payload, profiles):
    """The same authored catalogue supplies local preview and provider tools."""
    world = payload['world']
    catalogue = profiles['builder_help']
    objective = catalogue['objectives'][world['stage']]
    arrival_hint = catalogue.get('arrival_hints', {}).get(world['stage'], catalogue['pending'])
    if world['stage'] not in ('entrance', 'elevator'):
        next_action = catalogue['travel'][world['zone']] if world['challenge']['kind'] == 'travel' else arrival_hint
        if payload['topic'] == 'next':
            return objective+' '+next_action
    if payload['topic'] == 'next':
        return objective
    challenge = world['challenge']
    if challenge['kind'] == 'pipe':
        fields = {**challenge, 'ports': ' and '.join(challenge['ports'])}
        hint = catalogue['pipe'][challenge['phase']].format(**fields)
    elif challenge['kind'] == 'shooter':
        hint = catalogue['shooter'].get(challenge['phase'], catalogue['shooter']['playing']).format(**challenge)
    elif challenge['kind'] == 'travel':
        hint = catalogue['travel'][world['zone']]
    else:
        hint = arrival_hint
    if payload['topic'] == 'steps' or payload['memory']['facts']['style'] == 'steps':
        return f'1. {objective}\n2. {hint}\n3. Try it, then ask again if you need another hint.'
    return hint


def observation(name, payload, profiles):
    if name == 'read_current_objective':
        objective_payload = {**payload, 'topic': 'next'}
        return {'stage': payload['world']['stage'], 'objective': help_text(objective_payload, profiles)}
    if name == 'inspect_current_challenge':
        return deepcopy(payload['world']['challenge'])
    if name == 'get_approved_hint':
        return {'hint': help_text(payload, profiles), 'progress_awarded': False}
    if name == 'recall_my_conversation':
        return deepcopy(payload['memory'])
    return {'error': 'unknown_tool'}
