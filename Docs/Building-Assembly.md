# Building assembly and asset workflow

The blueprint restoration uses **one exported geometry layout** in Blender, Godot and
the browser review. Godot owns player input, camera, puzzle and elevator behavior;
it must not build a competing set of room walls after import.

## Files and authority

- `godot/assets/building-layout.json`: module IDs, metre/axis convention,
  elevations, reference-photo IDs, estimated bounds, doorway interfaces and
  gameplay anchors. The approved blueprint determines connections; dimensions
  are estimates, not a survey. Photos determine visible finishes and landmarks.
- `tools/build_environment.py`: reproducible Blender construction recipe. It
  retains source props and builds the blueprint shells, photo-based furnishings and
  streetscape. `tools/environment_facades.py` owns the continuous main envelope
  and neighboring scenery. `tools/environment_blueprint.py` owns room walls,
  floors, thresholds and circulation around the original lift banks. The manifest
  and these components are reviewed together.
  `tools/environment_streets.py` builds the two scenic street extensions and
  visible barricades. Godot's invisible gameplay boundaries use the same
  `street_review_limits` manifest bounds, independently of the entrance puzzle.
- `godot/developer/building-source-selection.json`: retained source-mesh
  selection used by the Blender recipe and native validator. The manifest keeps
  its original `godot/playtest/layout_source.json` provenance reference;
  `tools/environment_inputs.py` resolves that historical name to this location
  and checks the source identity. The map's contents and export metadata are
  unchanged by the directory consolidation.
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

The layout manifest uses LF line endings enforced by `.gitattributes`. Its exact
bytes are hashed into the native/export receipt, so checkout normalization must
not change that identity between computers.

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

The layout follows `Proposed Hallway Rooms - Aligned with Hallway 1.png`, approved
on October 25 and reapproved on October 28. Its SHA-256 is recorded in the
manifest. Photos supply appearance references without changing those connections.

The ground ramp continues forward into a hallway, with both elevators on the
left wall. The retained banks stay at their original coordinates and orientation.
Upstairs, turn right toward reception. Hallway 1 ends beside the bathrooms behind
the shafts. Reception connects directly to the classroom, the L-shaped separate
room and Hallway 2. Two small rooms sit along Hallway 2 and stop at Hallway 1's
end line. Hallway 2 joins the large indoor commons without a door or partition.
Dennis's later October 28 clarification confirms a direct reception door to the
additional room beside the classroom. This supersedes the drawing's access-TBD
label; retain that door on every rebuild.

The latest October 28 revision deepens reception by 1.8 m and widens it by 1 m
relative to the first walkthrough correction. Its footprint is approximately
9.4 by 5.74 m; Hallway 2 has about 3.18 m clear width between wall faces. The
classroom keeps approximately 82.4% of its preceding floor area. Reception's
single door to the separate room retains its glazing and is closed and locked,
as is the ground yellow side-room door.
Unused space between the cabs has solid infill. The bench sits against the
opposite wall. The kitchen runs along the bathroom-side wall at Dennis's marked
location, with a clear aisle to its island; the lounge moves into the former
kitchen area. Lift coordinates and scale remain unchanged.

Classroom furnishings keep their shape, scale and material parameters. Complete
table/chair/laptop assemblies, lighting rows, storage and attached wall art use
declared rigid translations to fit the shorter room; no furniture is stretched.
The manifest records exact source-prefix membership and expected mesh counts
for each assembly, plus the intact six-piece planter exception. Native verification independently
reimports the pinned source, compares every retained classroom, ground-core and
bank vertex under their declared transforms, and compares material parameters.
It also checks that every retained classroom prop fits inside its room footprint.
The complete fourteen-piece yellow leaf, inset glazing and handle use a single
declared hinge rotation to close. The native validator applies that same rigid
pose when comparing source vertices; no door part is stretched or discarded.
Kitchen and bench placements likewise use explicit assembly frames in the manifest.

### Approved door inventory

Door connections, access states and mesh prefixes live in the manifest's
`portals`; open passages are explicitly distinguished from physical doors.
The independent contract test fixes the required upper room connections.
Godot verifies that each door declared in `portals` has both jambs, a head and
a visible leaf, then checks clearances, locks and actual player movement.
The retained yellow door additionally has native source-shape and movement-lock
checks. An empty opening alone cannot pass the portal door-preservation check.

| Connection | Required state |
| --- | --- |
| Landing to reception | Open double glazed doors |
| Reception to classroom | Open double glazed doors |
| Reception to additional room beside classroom | Open single glazed door |
| Reception to larger separate room | Closed and locked; retain glazing |
| Hallway 2 to each of its two small rooms | Open single glazed doors |
| Landing to opposite room | Closed white door |
| Hallway 1 to the two bathrooms | Closed white doors; retain both in the blueprint recipe and visual review |
| Ground yellow side room | Closed and locked; retain the complete original leaf |

The reception/Hallway 2 and Hallway 2/commons connections remain open passages.
Before altering a required connection or access state, resolve it against the
user's instruction and update the manifest, recipe and tests together.

Attachment points are `ANCHOR_<id>` empties. Door interfaces record the connected
spaces, opening width, height and floor. Elevator anchors share horizontal
coordinates; their heights are taken from the same level convention. A doorway,
puzzle interaction point or lift destination is referenced by ID, not guessed
from a child mesh's bounding box.

Keep room roots at unit scale. Move a room as a root when relocating an intact
assembly. Change wall lengths and openings deliberately when reshaping it;
do not stretch furniture, stairs, doors or the player to hide a fit problem.
Room asset origins use their declared floor corners; the lift-bank origin uses
the shaft corner. These are current world positions, rather than coordinates
left over from an earlier plan. Native and Godot review cameras are
derived from the same manifest viewpoints.
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
   python tools/prepare_game.py
   ```
5. Test doorway clearances, walkable floors, elevators, camera and puzzle after
   any geometric change. Technical checks and visual reference review are separate.
   Run `python tools/verify_environment_fresh.py` to verify the selected export
   and current game sources in a separate, initially empty Godot import cache.
   This preserves existing caches and retained raw inputs; it does not reinstall
   Blender or Godot.

Current floors are street 0 m, lower elevator forecourt 0.85 m, and upstairs
5.05 m, with a 4.2 m elevator offset. These retained construction estimates are
recorded values, not measurements obtained from the new photographs. Higher
exterior storeys are scenery, not additional playable levels.

The retained lift banks have no extra rotation or relocation. Their first cab
is at Blender XY `(-0.95, 12.1)` and the second at `(-0.95, 15.1)` on both levels.
Doors face Blender +X. The forward ground hallway is beside them at X `2.35`.
The upstairs exit faces +X toward a closed white door; turning right faces -Y
toward reception. Floor cutouts and threshold infills follow the actual cab
plates and steel sills, rather than covering or leaving holes around them.

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
