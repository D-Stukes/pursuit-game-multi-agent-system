# Building assembly and asset workflow

The photo redesign uses **one exported geometry layout** in Blender, Godot and
the browser review. Godot owns player input, camera, puzzle and elevator behavior;
it must not build a competing set of room walls after import.

## Files and authority

- `godot/assets/building-layout.json`: module IDs, metre/axis convention,
  elevations, reference-photo IDs, estimated bounds, doorway interfaces and
  gameplay anchors. Dimensions are photo estimates, not a survey.
- `tools/build_environment.py`: reproducible Blender construction recipe. It
  retains source props and builds the photo-based shells, furnishings and
  streetscape. The manifest and recipe are reviewed together.
- `tools/verify_native_environment.py`: reopen the saved native candidate in
  Blender and verify module origins, anchors, classroom preservation, dependency
  containment and asset re-instancing.
- `tools/promote_environment.py`: verify the native/export/manifest receipt,
  then derive browser bounds and cutaway metadata from the exported hierarchy.
  Both viewers use the resulting canonical GLB.
- `tests/test_environment_contract.py`: portable checks for portal/room fit,
  floor alignment, reference coverage and distinct circulation routes.
- Native `.blend` masters and photographic references remain in the private
  Creative project. They are not embedded into or served by the public package.
- The final shared GLB and its hash/mesh metadata belong to the existing portable
  review package. Godot stages an ignored copy of that exact export.

## How parts fit together

Use Blender metres, Z up. Convert once on export/import to Godot
`(Blender X, Blender Z, -Blender Y)`. Do not rotate an imported floor again to
compensate for a second conversion.

`Pursuit_Assembly` is the world root. `Floor_Street` and `Floor_Upper` are named
stacking roots; the vertical elevator core is a separate module. Each room is a
named collection with a root Empty and an explicit origin. Room collections are
marked as Blender assets. Their collection instance offsets use those origins,
so dragging or linking a room does not introduce an unexplained world offset.
Repeated geometry uses shared mesh data rather than hand-maintained copies.

The upstairs plan follows IMG_4794's handedness: glazed entry on the left,
white far wall with the larger-room door, and blue room wall on the right.
The recipe's declared plan transform places those modules consistently. Actual
classroom furnishings use a proper rigid rotation, never negative scale. The
notice board and its three attached notices have a documented rigid placement
exception in the manifest so they mount to the solid rear wall, rather than
covering exterior glazing. A six-piece planter is also moved intact from outside
the façade onto the classroom floor. Native verification compares every source vertex
after these declared moves and compares the retained material parameters.
It also checks that every retained classroom prop fits inside the room footprint.
The short approach and turn into the blue/black internal passage remain inferred
from overlapping photos; the confirmed room-door destinations are separate facts.

Attachment points are `ANCHOR_<id>` empties. Door interfaces record the connected
spaces, opening width, height and floor. Elevator anchors share horizontal
coordinates; their heights are taken from the same level convention. A doorway,
puzzle interaction point or lift destination is referenced by ID, not guessed
from a child mesh's bounding box.

Keep room roots at unit scale. Move a room as a root when relocating an intact
assembly. Change wall lengths and openings deliberately when reshaping it;
do not stretch furniture, stairs, doors or the player to hide a fit problem.
Parent objects while preserving world transforms. Check both the native scene
and a fresh export after changing parentage or origins.

For assembly, objects **do not need to be welded into one mesh**. Keep floors,
rooms, doors, furnishings and shared services separable. Join only geometry that
really needs common topology; a joined mesh is not a substitute for an asset
hierarchy. Preserve independent parts needed for collision, interaction or reuse.

## Change and verification procedure

1. Edit the manifest and Blender recipe together for a layout change; preserve
   confirmed room connections and identify estimates.
2. Rebuild a separate candidate with an existing Blender installation:

   ```powershell
   blender --background --python-exit-code 1 --python tools/build_environment.py -- --output-dir "<candidate folder>"
   ```

   `<candidate folder>` is an absolute working folder outside the public repository.
   No new dependencies or provider calls are needed. The original retained mesh
   source is pinned to a Git revision and SHA-256; it is never modified in place.
3. Reopen the saved `.blend` and run native verification. Inspect the exported
   GLB at the photo viewpoints, including interior circulation and both street
   frontages. A successful export alone does not prove a usable environment.
4. Promote the reviewed GLB and matching metadata together. Stage that same
   geometry in Godot; do not retain hidden procedural substitutes for its walls.

   ```powershell
   python tools/promote_environment.py "<candidate folder>"
   python tools/prepare_playtest.py
   ```
5. Test doorway clearances, walkable floors, elevators, camera and puzzle after
   any geometric change. Technical checks and visual reference review are separate.

Current floors are street 0 m, lower elevator forecourt 0.85 m, and upstairs
5.05 m, with a 4.2 m elevator offset. These retained construction estimates are
recorded values, not measurements obtained from the new photographs. Higher
exterior storeys are scenery, not additional playable levels.

## Technical references

Blender's [collection assets](https://docs.blender.org/manual/en/5.0/editors/asset_browser.html)
and [parenting behavior](https://docs.blender.org/manual/en/5.0/scene_layout/object/editing/parent.html)
support reusable assemblies with deliberate transforms. The implementation is
verified against installed Blender 5.2.2; indexed 5.0 manual extracts provide
workflow context, not a claim of identical APIs. Godot's
[import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)
recommends changing source data where practical to minimize differences between
the modeling application and imported scene. The assembly and re-instancing
checks test our actual use of those principles.
