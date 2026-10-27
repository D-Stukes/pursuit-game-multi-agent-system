# Mr. P and challenge robot assets

The supplied Dandy Jinn sheet and purple ghost portrait guide **Mr. P's appearance**;
the sheet title does not rename the game character. UNIT 74 guides the robot.
These are new original meshes, built from those visual references with Blender.
Reference-sheet annotations are source labels, not additional gameplay requirements.

## Source and game boundary

Editable `.blend` masters, generated GLBs, transparent art and render evidence live
in the existing Creative project, outside Git. The repository holds reproducible
authoring code, verification and an isolated Godot review scene. Runtime copies
are staged under ignored `godot/assets/generated/characters/`.

This follows the workspace rule against committing generated assets. A code
checkout alone does not include these private exports. Use the existing local
exports or rebuild with Blender; no new package installation or paid service is
required. The existing building and player are separate from this art review.

The character art does not implement Mr. P's AI, questions, answer rules or
challenge completion. Lady D retains that content responsibility. Robot part
images will support the selected 2D assembly activity without requiring the
player's 3D model to be broken apart.

## Mr. P

The native source has a continuous deforming torso/arms/tail surface, a supported
facial sculpt, independently editable hat pieces, a 13-bone skeleton and paired
eyelid morphs. Materials use ordinary Principled/PBR colors. Idle, Welcome and
Guide are named clips; they carry art motion rather than tutorial content.

Authoring uses metres, Blender Z up and forward toward -Y. glTF/Godot use Y up
and the character faces +Z. Keep the rig root at unit scale. Export only the asset
collection; studio cameras and lights stay in the native master.

Build a separate master/output folder outside the repository:

```powershell
blender --background --python-exit-code 1 --python tools/build_characters.py -- --asset mr-p --output-dir "<Mr P source folder>" --render
```

`<Mr P source folder>` is an absolute working folder. The selected native filename
is `Mr P.blend`; its runtime export is `mr-p.glb`. The recipe uses the installed
Blender API; tested APIs are recorded with each receipt, rather than assumed
compatible with every Blender version.

Reopen the exact saved master and verify it:

```powershell
blender --background "<Mr P source folder>/Mr P.blend" --python-exit-code 1 --python tools/verify_native_characters.py
```

After review, place the selected GLB and its `receipt.json` together under
`Creative/Blender/Pursuit - The Climb/Exports/Characters/Mr P/` in the Home Codex
workspace. The staging tool checks the export hash before replacing an engine
resource. The native master stays in Source.

## Review in Godot

```powershell
python tools/run_character_review.py
```

This stages existing exports, imports them and opens `CharacterReview.tscn`.
The launcher reuses the same Godot discovery as the building launcher.
Drag to orbit, use the wheel to zoom, F/P/B for fixed views and T for turntable.
Clip buttons play the named animations. Esc closes the review.

The import checks in `godot/playtest/tests/verify_characters.gd` exercise the
actual skeleton, skins, clips and eyelid morphs in Godot. Native verification
checks dependency containment, normalized skin weights, connected body topology
and numeric motion at every frame. Images from `capture_characters.gd` provide
fixed-view and representative-pose evidence. Sampled images are not proof of
every possible pose or continuous playback.

Appearance review and construction/deformation review are separate. A successful
export, triangle count or normalized weights cannot establish likeness. These
assets need Dennis and Lady D's visual acceptance before being treated as final
character designs.

## Workflow references

Godot's [import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)
recommends correcting source data where practical rather than maintaining a
different imported scene. The [glTF 2.0 specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
defines portable node, skin and morph animation. Exported controls are checked
in the destination engine; Blender-only controls are not assumed to survive.
