"""Catch floor maps left stale after a canonical building export changes."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NavigationAssetTests(unittest.TestCase):
    def test_floor_map_source_matches_the_current_building(self):
        record = json.loads((ROOT / 'godot/assets/maps/provenance.json').read_text())
        model = ROOT / record['source']
        self.assertEqual(record['source_sha256'], hashlib.sha256(model.read_bytes()).hexdigest())

    def test_both_floor_images_match_the_render_receipt(self):
        folder = ROOT / 'godot/assets/maps'
        record = json.loads((folder / 'provenance.json').read_text())
        self.assertEqual(set(record['texture_sha256']), {'ground.png', 'upper.png'})
        for name, checksum in record['texture_sha256'].items():
            with self.subTest(floor=name):
                self.assertEqual(checksum, hashlib.sha256((folder / name).read_bytes()).hexdigest())

    def test_ground_projection_covers_the_walkable_street(self):
        record = json.loads((ROOT / 'godot/assets/maps/provenance.json').read_text())
        layout = json.loads((ROOT / 'godot/assets/building-layout.json').read_text())
        ground = record['floors']['ground']
        street = layout['street_review_limits']
        x, depth = ground['center']
        self.assertLessEqual(x - ground['width'] / 2, street['min_x'])
        self.assertGreaterEqual(x + ground['width'] / 2, street['max_x'])
        self.assertLessEqual(depth - ground['depth'] / 2, street['min_depth'])
        self.assertGreaterEqual(depth + ground['depth'] / 2, street['max_depth'])
