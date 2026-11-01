"""The cast's personality cards: every everyday character has one, and they follow the shared rules."""
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
DIALOGUE = json.loads((ROOT / 'godot/assets/characters/npc-dialogue.json').read_text(encoding='utf-8'))
LIFE = json.loads((ROOT / 'godot/assets/characters/npc-life.json').read_text(encoding='utf-8'))
CARD_FIELDS = ('name', 'job', 'personality', 'voice', 'interests', 'knows')
# Everyday gestures only; the models' combat clips are off limits.
GESTURES = {'Idle', 'Idle_Neutral', 'Interact', 'Wave'}


def profile_for(actor):
    for npc_id, profile in DIALOGUE['profiles'].items():
        if profile.get('actor', npc_id) == actor:
            return npc_id, profile
    return None, None


class CastCards(unittest.TestCase):
    def test_every_everyday_character_has_a_complete_card(self):
        for actor in LIFE['actors']:
            npc_id, profile = profile_for(actor)
            self.assertIsNotNone(profile, actor)
            card = profile.get('card', {})
            for field in CARD_FIELDS:
                self.assertTrue(card.get(field), f'{npc_id} card is missing {field}')
            for field in ('interests', 'knows'):
                self.assertIsInstance(card[field], list, f'{npc_id} {field}')

    def test_names_are_unique_and_shown(self):
        cards = {npc_id: p['card'] for npc_id, p in DIALOGUE['profiles'].items() if 'card' in p}
        names = [card['name'] for card in cards.values()]
        self.assertEqual(len(names), len(set(names)))
        for npc_id, card in cards.items():
            self.assertEqual(DIALOGUE['profiles'][npc_id]['label'], card['name'], npc_id)

    def test_only_everyday_characters_have_cards(self):
        # Mr. P and the Program Manager are Lady D's; they get no card and no AI voice.
        for npc_id, profile in DIALOGUE['profiles'].items():
            if profile.get('actor', npc_id) not in LIFE['actors']:
                self.assertNotIn('card', profile, npc_id)

    def test_data_keeps_the_rules(self):
        for scene in DIALOGUE['scenes']:
            self.assertLessEqual(len(scene['lines']), 4, scene['id'])
        for name, action in LIFE['actions'].items():
            self.assertLessEqual({action['clip'], action['rest']}, GESTURES, name)

    def test_scenes_are_short_and_can_happen(self):
        milestones = {'entrance', 'elevator', 'checked_in', 'classroom'}
        ids = [scene['id'] for scene in DIALOGUE['scenes']]
        self.assertEqual(len(ids), len(set(ids)))
        pair = float(DIALOGUE['scene_settings']['pair_distance'])
        for scene in DIALOGUE['scenes']:
            a, b = (LIFE['actors'][actor] for actor in scene['speakers'])
            shared = set(a['areas']) & set(b['areas'])
            # Somewhere they both visit, two spots are close enough for them to talk.
            spots = [place for place in LIFE['places'] if place['area'] in shared]
            self.assertTrue(any(math.dist(p['position'], q['position']) <= pair and abs(p['position'][1] - q['position'][1]) <= .5
                                for p in spots for q in spots if p is not q), f"{scene['id']}: the two never stand close")
            for key in ('after', 'before'):
                if key in scene:
                    self.assertIn(scene[key], milestones, scene['id'])
            # Upstairs milestones are only heard by people who live upstairs.
            if scene.get('after') in ('elevator', 'checked_in', 'classroom'):
                self.assertIn('upper', shared, f"{scene['id']}: the player is upstairs by then")
            self.assertEqual({speaker for speaker, _ in scene['lines']}, {0, 1}, scene['id'])
            for _, text in scene['lines']:
                self.assertLessEqual(len(text.split()), 20, f"{scene['id']}: {text}")
        # The street suite expects the door scene to play before the newer street scenes.
        self.assertLess(ids.index('street_door'), ids.index('street_hints'))

    def test_shared_rules_cover_the_agreed_limits(self):
        rules = ' '.join(DIALOGUE['cast_rules'])
        for phrase in ('School-appropriate', 'Never claim or change game progress', 'four lines at most',
                       'Interact, Wave and Idle'):
            self.assertIn(phrase, rules)

    def test_first_meeting_introduces_the_character_by_name(self):
        for npc_id, profile in DIALOGUE['profiles'].items():
            if 'card' not in profile or npc_id == 'BuilderCompanion':
                continue
            greeting = profile['greetings'][0].replace('\u2019', "'")
            self.assertIn(f"I'm {profile['card']['name']}", greeting, npc_id)


if __name__ == '__main__':
    unittest.main()
