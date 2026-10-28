"""Fresh-state integrity checks for private art exports and ignored engine copies."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('prepare_characters',ROOT/'tools/prepare_characters.py')
staging=importlib.util.module_from_spec(spec);spec.loader.exec_module(staging)


class CharacterStagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(dir=ROOT/'godot/.godot/playtest')
        self.root=Path(self.temporary.name);self.original=staging.DEST
        staging.DEST=self.root/'cache'

    def tearDown(self):
        staging.DEST=self.original;self.temporary.cleanup()

    def export(self):
        folder=self.root/'exports/Mr P';folder.mkdir(parents=True)
        raw=b'newly produced art export'
        (folder/'mr-p.glb').write_bytes(raw)
        (folder/'receipt.json').write_text(json.dumps({'glb_sha256':hashlib.sha256(raw).hexdigest()}))
        return folder,raw

    def test_fresh_export_produces_fresh_resource_copy(self):
        folder,raw=self.export()
        self.assertFalse(staging.DEST.exists())
        with contextlib.redirect_stdout(io.StringIO()):staging.prepare(folder.parent)
        self.assertEqual((staging.DEST/'mr-p.glb').read_bytes(),raw)

    def test_bad_source_does_not_replace_previous_resource(self):
        folder,_=self.export();(folder/'mr-p.glb').write_bytes(b'corrupted')
        staging.DEST.mkdir();target=staging.DEST/'mr-p.glb';target.write_bytes(b'previous')
        with self.assertRaisesRegex(ValueError,'does not match'):staging.prepare(folder.parent)
        self.assertEqual(target.read_bytes(),b'previous')

    def test_old_cache_cannot_substitute_for_missing_producer_export(self):
        staging.DEST.mkdir();(staging.DEST/'mr-p.glb').write_bytes(b'cached')
        with self.assertRaisesRegex(ValueError,'No selected'):staging.prepare(self.root/'absent')

    def test_bad_robot_layer_preserves_all_previous_resources(self):
        folder,raw=self.export();robot=folder.parent/'Robot';(robot/'parts').mkdir(parents=True)
        (robot/'robot.glb').write_bytes(raw)
        (robot/'receipt.json').write_text(json.dumps({'glb_sha256':hashlib.sha256(raw).hexdigest()}))
        parts=['torso','head','power_core','left_arm','right_arm','left_leg','right_leg']
        images={part:{'file':part+'.png','sha256':hashlib.sha256(b'valid layer').hexdigest()} for part in [*parts,'complete']}
        (robot/'parts/parts.json').write_text(json.dumps({'parts':parts,'overlay_order':parts,'canvas':[768,1024],'images':images}))
        for part in [*parts,'complete']:(robot/'parts'/(part+'.png')).write_bytes(b'bad layer')
        staging.DEST.mkdir();target=staging.DEST/'mr-p.glb';target.write_bytes(b'previous')
        with self.assertRaisesRegex(ValueError,'part image does not match'):staging.prepare(folder.parent)
        self.assertEqual(target.read_bytes(),b'previous')


if __name__=='__main__':unittest.main()
