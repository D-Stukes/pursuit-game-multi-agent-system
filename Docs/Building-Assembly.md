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
| Reception to additional room beside classroom | Closed glazed door (October 30 playtest request) |
| Reception to larger separate room | Closed and locked; retain glazing |
| Hallway 2 to each of its two small rooms | Closed doors (October 29 playtest request) |
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

## October 29 playtest revision

The classroom rear wall moves from X=-15.1 to X=-17.1 metres. This adds two
metres behind the robot. The adjacent L-shaped hall footprint changes with it.
The retained planter and its five foliage meshes move as one rigid assembly
to the new rear corner. Both small Hallway 2 room doors are closed.

Dennis initially confirmed IMG_4798–IMG_4803 as commons references. The
subsequent twelve-photo set replaces that first accent pass as the primary
furniture reference; see the photo reconstruction section below.
Photo IMG_4794 shows reception; its historical Classroom photo tag is not
evidence of the classroom layout. Room dimensions remain estimates.

Reference folder: https://drive.google.com/drive/folders/1eSOzOeCtZ_QwVe4NcJFAeeQdDKk-Z5Vv

### Rear-wall follow-up and live entrance doors

The robot/bench centre moves from X=-14.05 to X=-16.08. The tabletop edge
is 0.065 metres from the rear wall's inner face. The full plants move into the
rear window-side and reception-side corners. The bin and lid move together
beside the reception-side corner plant. Native preservation checks still apply.

`EntranceDoors.gd` reuses the retained door meshes in the shared export.
It rotates the two leaves around their hinges for live closed/open states and
builds their colliders from those same mesh faces. `Main.gd` excludes those
faces from the immovable building collider and still counts their triangles in
the building total. No duplicate door design or wall is generated. The raw
static review export retains its source open pose; a fresh game starts closed.

## Commons furniture from the twelve-photo set

Dennis supplied Photo 1.jpg–Photo 12.jpg on October 29. These private images
remain outside the repository. Photos 1–3 and 6 show the dining/kitchen and
central lounge; 4 and 7 show quiet rooms; 5 shows the blue wall, storage and
clothing rack; 8–12 show shared desks, window shades, the wall screen and
exposed services. Faces, personal papers and temporary boxes are not assets.

`tools/environment_commons.py` owns this furniture and ceiling pass. It replaces
the previous scattered tables, yellow cushions and circular rug with paired
white shared desks, caster chairs, charcoal/grey lounge seating, wood tables,
three wood-sided quiet booths, clothing storage and roller shades. Segmented
ducts, vent grilles, red fire pipes and suspended light bars follow the photos.
The existing kitchen frame, building shell, portals and gameplay anchors stay
fixed. Furniture scale and relative placements remain photo-based estimates.
One booth has a clear open entrance; the other two are closed dressing. The
end island stool is omitted so the player can round the island without
colliding with the booth row.

`verify_commons.gd` walks from Hallway 2 through the lounge and shared-desk
aisle, into the open booth and around the kitchen island. Native verification
checks retained meshes and declared floor/module origins. Godot captures use
the same lighting as gameplay. Visual acceptance remains Dennis's judgment.

## Approved commons layout, October 29

The approved top-down layout places the three quiet booths along the top-left
(west) side, moves shared desks east to clear them, and extends lounge, dining
and storage furnishings toward the classroom wall. Furniture uses rigid
placements from `commons_photo_revision.approved_layout`; dimensions stay fixed.
The kitchen assembly moves 0.5 m south so its lower edge starts at authoring
Y=8.8, aligned with the far edge of the western Hallway 2 room (Room 2 in the
approved image). Room shells, gameplay anchors and the robot stay fixed.

Commons and Hallway 2 use the same white upper slab material. The raised commons
floor overlay and decorative floor joint strips are removed to avoid a seam.
Classroom carpet, reception finish and quiet booth carpets remain separate.
The Blender 5.2.2 recipe applies assembly moves through `Object.matrix_world`;
the saved native file and exported model are checked before staging in Godot.

Validation of the approved export: 72 native assembly checks, 86 Python tests,
152 Godot layout checks and 16 commons movement checks passed. Export comparison
confirmed 557 moved furniture meshes and unchanged bounds for 10,758 other meshes.
The final top-down capture uses the staged canonical GLB with roofs hidden,
without furniture transforms or material overrides in the capture script.

The Hallway 2 blue-wall lettering now spans the solid wall above a centered
3.4 m charcoal couch. The couch faces the hallway, with its back near the wall.
The main route at authoring Y=6.2 and the aisle at Y=5.1 stay clear.

Physical CLASSROOM and COMMONS entrance signs and the RECEPTION label are part
of the same exported building. The Commons sign hangs above the open approach;
it introduces no doorway or wall. Classroom plants retain their corner poses.

The neon ornament above the classroom doorway is raised by 0.3 m to leave a
clear gap above the new CLASSROOM lettering. Both stay below the ceiling.


### Golden sky presentation

`godot/assets/sky/austell-golden-sky.png` is a generated cloud panorama derived
from the supplied Austell Street sky references. `austell-sky.gdshader` maps it
with a horizon scale of 1.32. `EnvironmentLighting.gd` uses a warm low sun while
preserving the indoor ambient light. No building geometry changed in this round.
The submitted generation prompt and reference roles are in
`godot/assets/sky/provenance.json`; private source photos are not bundled.


### Entrance sidelights and navigation maps, October 29

The closed leaf pivots are at X ±1.26 m and Godot Z 4.85 m. The original
sidelight jambs stopped at X ±1.52 m, leaving approximately 0.19 m between
frame edges. `environment_facades.py` now extends each sidelight to ±1.26 m
and shifts its plane 0.10 m to meet the closed leaves. Door geometry, pivots,
wall positions and doorway width are unchanged. Only 22 sidelight meshes
changed; all other exported mesh bounds remain identical.

The separate Blender 5.2.2 candidate passed 79 native assembly checks after
reopening, including retained source vertices, materials and rigid assemblies.
The export uses the existing glTF recipe. Reference: [Blender 5.2 object
transforms](https://docs.blender.org/manual/en/latest/scene_layout/object/editing/transform/introduction.html).
Native closed/front and top-down views and collision rays confirm both former
slits are filled and the opened central doorway remains clear.

`render_navigation_maps.gd` renders both floors from the staged canonical GLB.
`BuildingMap.gd` uses the exact same orthographic world bounds for its live
player arrow and objective ring. `godot/assets/maps/provenance.json` records
the model identity and projection. Re-render maps whenever the model changes.
The map is an orientation aid, not an automatic route planner.


### Full street map and chair interaction

The ground map now covers 52×45 m centred at authoring [1, -2.5], including the
full walkable street bounds. The upstairs projection remains 52×31.2 m centred
at [1, 6.325]. Off-screen SubViewport rendering produces 1300×1125 and 1300×780
textures. Map provenance records each projection and image hash; no geometry
was changed for this follow-up. Runtime zoom/pan uses the same projection.

ChairSeats discovers the exported chair seat surfaces and matching backs. It
rejects other floors, occupied seats and seats behind walls. Explicit C input
anchors the student at the seat while the animation plays, then returns them
to a collision-free floor position for standing. Sitting never changes progress.

### October 30 entrance rails, closed door and laptops

Dennis reported that the entrance doors looked cut off at the bottom, that the
reception door to the additional room beside the classroom stood open, and that
some classroom laptops faced away from their chairs.

- The retained source models each entrance leaf's bottom rail
  (`Exterior open door rail` and `rail.002`) 12 m in front of its leaf. The
  selection carried the 12 m correction, but tagged them `door_trim`, a kind the
  recipe never imports, so the leaves had no bottom rail. They are now retained
  `ground` meshes with the same 12 m delta, which lands them under each leaf's
  glass; `EntranceDoors.gd` poses them with their leaves and native verification
  checks them against the source like the top rails.
- The `additional_room` portal is closed and glazed in the manifest; the recipe
  passes the portal's state to its door builder.
- Each classroom table holds two laptops. The `-0.65` laptop on all six tables
  faced the same way as its neighbour, away from its own chair. Six manifest
  `placement_exceptions` turn each laptop's base, screen and separate cyan display
  face 180 degrees about the base centre. `verify_layout.gd` now checks every student laptop against its
  nearest chair and both entrance leaves for top and bottom rails.

Built with Blender 5.2.3 (Homebrew) on macOS; native verification passed 79
checks. Map textures were re-rendered from the promoted model and their hashes
recorded in `godot/assets/maps/provenance.json`.

