"""Resolve retained building inputs without rewriting saved export provenance."""
import json
from pathlib import Path


def load_source_selection(root, layout):
    root = Path(root).resolve()
    reference = layout['source']['selection']
    # Saved Blender masters/manifests retain this original acquisition path.
    # The exact same selection bytes now live with developer-only resources.
    if reference == 'godot/playtest/layout_source.json':
        reference = 'godot/developer/building-source-selection.json'
    path = (root/reference).resolve()
    if not path.is_relative_to(root):
        raise ValueError('Building source selection escapes the repository')
    data = json.loads(path.read_text(encoding='utf-8'))
    if data.get('source_sha256') != layout['source']['sha256'] or not isinstance(data.get('meshes'), list):
        raise ValueError('Building source selection does not match export provenance')
    return data['meshes']
