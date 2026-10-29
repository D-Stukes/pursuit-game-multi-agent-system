"""The relocated native source map must work without its historical directory."""
import json
from pathlib import Path
import tempfile
import unittest

from tools.environment_inputs import load_source_selection

ROOT=Path(__file__).resolve().parents[1]


class EnvironmentInputTests(unittest.TestCase):
    def setUp(self):
        self.scratch=ROOT/'godot/.godot/playtest'
        self.scratch.mkdir(parents=True,exist_ok=True)

    def test_live_selection_matches_saved_export_provenance(self):
        layout=json.loads((ROOT/'godot/assets/building-layout.json').read_text())
        selection=load_source_selection(ROOT,layout)
        self.assertEqual(sum(row['kind']=='classroom' for row in selection),646)
        self.assertTrue(all({'name','kind','delta'}<=row.keys() for row in selection))

    def test_fresh_relocated_selection_needs_no_old_cache_or_path(self):
        with tempfile.TemporaryDirectory(dir=self.scratch) as folder:
            root=Path(folder); path=root/'godot/developer/building-source-selection.json'
            path.parent.mkdir(parents=True)
            meshes=[{'name':'new-compatible-prop','kind':'classroom','delta':[1,2,3]}]
            path.write_text(json.dumps({'source_sha256':'new-source','meshes':meshes}))
            layout={'source':{'selection':'godot/playtest/layout_source.json','sha256':'new-source'}}
            self.assertFalse((root/'godot/playtest').exists())
            self.assertEqual(load_source_selection(root,layout),meshes)
            layout['source']['sha256']='different-source'
            with self.assertRaisesRegex(ValueError,'provenance'):load_source_selection(root,layout)

    def test_declared_selection_cannot_escape_root(self):
        with tempfile.TemporaryDirectory(dir=self.scratch) as folder:
            with self.assertRaisesRegex(ValueError,'escapes'):
                load_source_selection(Path(folder),{'source':{'selection':'../outside.json','sha256':'unused'}})


if __name__=='__main__':unittest.main()
