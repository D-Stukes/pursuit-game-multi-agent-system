# Pursuit building review and Godot playtest

**Current layout:** Godot assembles the approved connected rooms at runtime.
The HTML reviewer and downloadable GLB retain the preceding static layout.
Use the Godot playtest below to review the current room arrangement. The
browser server is optional and is not required to launch Godot.

The complete portable review package is in `trials/building-review/` at the
repository root. In the browser-review sections below, commands and asset paths
are relative to that package folder unless stated otherwise. Godot commands
are run from the repository root. The portable package includes the combined
building GLB and a local Three.js viewer. No source photographs, image galleries,
Blender masters, private notes or CDN dependencies are included. The GLB contains
its generated surface materials; keep those embedded textures with the model.

## Open the static browser review

Use Python 3.10 or newer. No Python or Node packages need installing.

1. Use `develop`, or copy the entire `trials/building-review` folder with its subfolders.
2. On Windows, double-click **Open Review.cmd**. Alternatively, open a terminal in
   the package folder and run `python serve.py --open` (`python3` on some systems).
3. Open <http://127.0.0.1:8767/> if your browser does not open automatically.
4. Leave the terminal running while reviewing; press Ctrl+C to stop.

If the port is occupied, use `python serve.py --port 8768 --open`.
Do not double-click `index.html`: browser file restrictions prevent model loading.
The server binds only to your own computer and serves an explicit file allowlist.
No public hosting or sharing service is configured by this package.

## What to check in the static browser review

- Drag to orbit, scroll/pinch to zoom, right-drag to pan; use Reset view to recover.
- Follow the route stops: entrance, right ramp, ground elevators, second-floor
  arrival, player-right turn to reception, separate single-door room and direct
  double-door classroom entry.
- Use Ground floor and Second floor for cutaways. Classroom is a camera shortcut
  into the same combined model. Toggle ceilings and route overlays as needed.
- Use Download GLB to inspect the complete asset in Blender, Godot or another
  compatible glTF application. Viewer cutaways never change the downloaded asset.

The brown-door room, larger left area and ramp-side elevator forecourt follow
Dennis's corrections. Both elevator banks align. A structural band joins the
storeys. Reception's single door leads to a separate room; its double doors lead
to the classroom, which stays inside the building and behind the street facade.

This is a static photo-reference model. Dimensions, the unseen right wing,
separate room, enlarged footprint and longer hallway remain estimates. The elevator floor
change is a camera change, not a working elevator or continuous walk-through.
The Godot playtest below adds character movement and generated static collision.
Agent interactions, gameplay objectives and navigation beyond the tested
playable route remain unfinished. Physical movement and elevator transfer
already work in Godot.
Game Level 1 is not floor 1.

## Asset identity and checks

- Asset: `assets/pursuit-building.glb`, 13,197,484 bytes; 2,288 mesh nodes.
- SHA-256: `7493b9daf9b9705e5b23b5a9010f338523a495d4929dff34e0794f30d07af9d0`.
- Workstation source-path metadata was removed from this shared copy. The current
  export includes hallway/room extensions and ground-floor furnishings; the
  classroom is retained.
- Production: Blender 5.2.2 LTS, manually built from photo references and Dennis's
  layout corrections; not a photogrammetry reconstruction.
- Viewer: Three.js 0.180.0; its MIT license is retained in `vendor/LICENSE.txt`.
- Existing native/fresh-import checks covered seven sampled routes. Those checks
  do not replace game-engine collision, accessibility or measured-building checks.
- Run `python -m unittest discover -s . -p "test_*.py"` from the package folder to check
  package integrity, model/manifest coverage and the server's privacy boundary.

For the original portable-package handoff, HTTP responses, asset identity,
module dependencies and JavaScript syntax were checked. That handoff did not
include a new browser interaction test. On October 26 the page/model returned
HTTP 200 and all four package tests passed; those checks do not prove the
interactive WebGL controls, which still need browser review.

## Next playable increment

The Godot playtest below already imports this GLB, generates collision and adds
character movement and elevator floor transitions. The October 27 design now
places check-in upstairs, after an entrance puzzle and an elevator shooter gate.
The entrance puzzle is implemented locally; the shooter and check-in are not.
The former ground-floor
check-in plan is superseded; its existing desk remains scenery. Keep the
Three.js page as the static-source review tool and use Godot for the current
playable arrangement.
See [Project-Plan.md](Project-Plan.md) for the active gameplay scope and next steps.

### Try the entrance puzzle

1. Launch **Play Building.cmd** and approach the street entrance. Press **E**.
2. Select **Sense**, **Decide**, **Act**, then **Check order**. Use **Show hint**
   or **Reset order** if needed. Wrong answers do not cost energy in this increment.
3. Type the displayed three-digit code and select **Unlock entrance** (or Enter).
4. Select **Back to building** and walk through the doorway.

Escape closes the panel without unlocking. Closing/reopening and resetting
location preserve progress in the current process; restarting the game relocks
the gate and chooses new code digits. No real Pursuit access code is used.
Normal 1/2/3 location shortcuts cannot skip the locked entrance. F3 developer
travel remains a deliberate review bypass, not completion evidence.

Focused verification: run Godot with `--headless --path godot --script
res://playtest/tests/verify_entrance.gd` from the repository root. The check
covers wrong/partial order, guessed/wrong code, real E/Enter/Escape/Tab input,
modal movement lock, session retention and physical locked/unlocked traversal.
Rendered captures under ignored `.godot/playtest/` are review evidence, not
assets required to play. Existing route/layout tests solve entry before testing
interior circulation.

## Godot camera playtest

From the repository root, double-click **Play Building.cmd** on Windows, or run
`python tools/run_playtest.py`. The helper reuses an existing Godot installation
(PATH, `GODOT_BIN`, or this workspace's portable Tools folder), stages the canonical
GLB inside the Godot resource root, imports it and opens the building scene.
The Windows launcher can reuse Blender's bundled Python; no packages are installed.

For the current partner review, check out `develop`, update it from origin,
and run **Play Building.cmd** from that checkout. Godot 4.7+ and Python 3.10+
are required; if Godot is not on PATH, set `GODOT_BIN` to its executable.
The player/camera feature was merged and pushed to `develop` in `305b179` on
October 26, 2026. Its temporary feature and synchronization branches were deleted.
`develop` includes the current runtime room arrangement, character, camera,
street scenery and a small ground-floor check-in desk centered at
`(0.62, 0.02, 0.40)` (the feet marker; its base rests on the tile).
The desk is scenery from the previous check-in plan; the selected Check-In Console
interaction is now upstairs and is not connected yet. Upstairs reception remains
in place. Use the Godot playtest to review these changes: the HTML viewer/downloadable GLB predates the runtime
room assembly and this desk.

Use WASD/arrows to walk, hold Shift to run, mouse to orbit, wheel to zoom, and
R to reset the current review location. Escape opens/closes Settings and releases
the mouse while the menu is open. Movement, look, zoom and location shortcuts
are blocked until Resume/Escape closes it. Keys 1/2/3 select entrance,
reception and classroom test spawns. Near an elevator, E transfers between its
ground and second-floor landing with a short walk into the cab, a destination
fade, and a walk out. Controls stay locked during travel. The cab itself does
not physically move. The upper exit stops just beyond the jamb at approximately
`(0.91, 5.06, -12.21)`; onward movement belongs to the player. The entrance stairs
and the ramp are both traversable.
When a nearby wall pushes the camera very close, the avatar hides temporarily
to keep its head from blocking the view; it returns as the camera moves clear.
The initial instruction hint disappears after five seconds. The compact title,
current floor and top-right Settings button remain; all instructions are in
Settings, with a contextual elevator prompt only when nearby.

The interactive playtest renders at up to 60 FPS while focused and 15 FPS when
unfocused, reducing background GPU demand. Physics keeps its existing tick rate.
Headless checks lift the render cap so verification does not wait on it.

The building is loaded from an ignored, hash-checked runtime copy in
`godot/assets/generated/`; its canonical GLB remains unchanged in the review
package. `ApprovedLayout.gd` reuses selected source assemblies and generates the
approved room shells before building collision. Its `layout_source.json` records
the reused source mesh names and placement offsets. `BuildingPlaytest.tscn`
is the retained default scene. The unused first-person blockout was removed
at Dennis's request; it is not required to launch or test this playtest.

Run `python tools/run_playtest.py --test` for actual Godot physics/camera checks.
They cover three spawn locations across two physical floors, human-scale entrance/ramp/elevator/reception
movement through the classroom double-door connection, explicit lift transition,
wall blocking, camera retraction, input
release and pitch/zoom bounds. Results are written under ignored
`godot/.godot/playtest/`. Agent interactions and stars are not wired into this
scene yet.

The October 26 pre-merge check run passed 120 core playtest checks, 36 controls
checks and 141 layout checks (297 total), plus two standalone Python Greeter
tests and four browser-package tests. This verifies the tested environment and
prototype behavior, not the planned agent integration or a completed Level 1.
Later paragraphs describe earlier visual proofs and their limits; they are
not claims that new frames were captured during this documentation review.

F3 opens Developer Tools in debug builds: position/floor/FPS and location jumps.
These review controls are separate from the player instructions in Settings.
For running, the five-second hint and menu checks, run Godot with
`--headless --path godot --script res://playtest/tests/verify_controls.gd` from
the repo root. The 36 controls checks cover foreground/background frame budgets,
actual Shift/Escape/F3 input, held-input
blocking, animation changes and UI layout at 1280×720 and 800×600. They run without
opening a visible game. A stale wrapped-label height caused the previous blank
hint; it is now reset after text shaping. Fresh Forward+ frames verify visible
hint text and centered Settings/Developer Tools, including a narrower window.
`playtest/tests/live_review.gd` can keep one review window open and reload saved
scripts/scenes between batches; its fixed local commands and frames stay ignored
under `.godot/playtest/`. It uses engine APIs, not desktop automation.
Walking checks include floor height and stop the batch at a failed waypoint.
Creating `.godot/playtest/review-cancel` cancels a running review batch.

### Test character and license

The player uses **Casual Hoodie** (purple hoodie, shorts and sneakers) from
[Quaternius Ultimate Modular Men](https://quaternius.com/packs/ultimatemodularcharacters.html),
with the pack's included [CC0 license](../godot/assets/characters/quaternius-casual/LICENSE.txt).
Personal and commercial use are allowed; attribution is optional. This replaces
the previous Kenney Mini avatar, whose appearance was rejected during review.

The original `Casual_Hoodie.gltf` comes from the creator-linked Drive folder's
Individual Characters → glTF directory:
[source file](https://drive.google.com/file/d/1em1So1xwwQNfHJYMvzKcXkZllvtxpKP5/view).
Source SHA-256:
`dd74886c26998a0fa888b4ce557a0932d7d97b0265dd4c763154d081b7a6cb98`.
The runtime `Casual_Hoodie.glb` SHA-256 is
`d647ee4ca1c66008bca70aafcc0315b62c8ac0a6bc0f611e369569b43d0b214b`.
It repacks the source's embedded base64 buffer into a GLB binary chunk; all other
scene data and decoded buffer bytes are unchanged. No texture files are needed.
The license text is retained with normalized UTF-8 line endings.

The original four body meshes, 62-joint rig, materials and 24 animations are
retained. The playtest fits the visual to a 1.72 m height, uses the unchanged
0.24 m-radius capsule, and maps `Idle_Neutral`/`Walk`/`Run` to the controller's
idle/walk/run states according to actual movement. The source faces +Z and the visual is
rotated to match the controller's -Z forward direction. Other included clips
are unused; no new gameplay actions are enabled.

Verification on October 25 with Godot 4.7.2: all 120 model/physics/avatar/scenery checks
pass, including skeleton pose changes while walking and the complete sampled
entrance → ramp → elevator transfer → reception → classroom route. The current
source export is identified above and remains unchanged. The current runtime
layout retains all 646 classroom furnishing/teaching/service mesh parts, placing
the assemblies inside the new room shell without scaling their geometry.
Earlier character proofs used
actual Forward+ frames for front/back appearance, walking, ramp, reception,
classroom and a narrow viewport. The current controls/exterior revision also has
fresh rendered UI/crossroads proof. Manual camera-feel,
animation-stride and performance acceptance remain user review; this is a
movement/asset proof rather than completed gameplay.

### Exterior backdrop

The Godot playtest adds a lightweight, decorative streetscape separate from the
canonical building GLB: low-detail neighboring facades, storefronts, trees,
street lamps, a gradient sky, small sun and simple clouds. Windows use instanced
meshes. These are original procedural shapes; no downloaded scenery is required.
The visible sky sun is separate from the existing interior illumination.

Low yellow-and-black construction tape on posts retains four sidewalk bounds,
including its left rear corner. Collision blocks walking/running without snagging
the camera. The approved street plan forms an H: Front Road connects two side
roads at T junctions, without horizontal extensions beyond them. Immediate
neighbors stay joined to Pursuit. Continuous outer building rows mask the left
and right views beyond the side roads. The earlier opposite storefront forms
sit closer across Front Road. Decorative shells have matching camera collision.

Nine planter trees provide a modest city planting rhythm: three along each
outer row and three across the street. Two small raised beds, two benches and
four bollard markers detail the opposite sidewalk. These are decorative props,
with no quest markers, additional interiors or new gameplay interactions.

The distant street is decorative, with no additional playable rooms. It is
illustrative context, not a reconstruction of real neighboring properties. These
street additions and the current room arrangement appear only in Godot. The
shared GLB is the retained source library and earlier static-review snapshot.

The 120 core checks cover the actual right turn, upper landing/cross-hall placement, aligned lift floors,
the closed opaque door opposite the cab, resource reuse, and walking/running on the stair treads,
elevator travel in both directions and input locking, the prior avatar route, and walking/running into
the tape limits, camera clearance, the H's clear side roads, joined neighbors,
continuous outer building screens and planting clearance. The separate 36
controls checks cover frame budgets, the timer, text containment,
menu/developer input and wide/narrow layout. Fresh GPU frames were inspected for
the revised UI and streetscape, including the H layout from overhead, both road
ends, the opposite planting and the player's front/left/right views. Manual play feel and other-device performance
remain unverified.

The earlier scenery cleanup retained 478 mesh nodes while sharing immutable
resources: 448 distinct box meshes became 69, 30 sphere meshes became three, and
four tape shaders became one. The added courtyard facade reuses this cache;
current checks find 75 box resources, three spheres and one tape shader. Flat
ground, roads and markings receive shadows but no longer cast them; building,
tree and furniture shadows remain. Normal launches reuse the imported model;
the review harness alone requests a deep refresh after reimport. Collision
construction reads each object's transform once, retaining identical triangles.
During the resource-sharing cleanup, before/after headless receipts matched the
collision and scenery-layout hashes. The current room assembly changes building
geometry. The street returns to the original entrance line, with neighbors
meeting the wider side wings; the H arrangement and planting remain.
These are measured resource reductions, not a system-wide FPS improvement claim.

UI references: the [Heliyon tutorial review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9676530/)
discusses practice, feedback and timely help; [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/indicate-allow-reminder-of-controls-during-gameplay/)
supports making control reminders available after the introduction.

### Approved connected-room layout

Leave the upper elevator facing the closed opaque white door to another room,
then turn the **player's right** toward reception. The retained white cylinder
sits left of the straight approach. Short Hallway 1 ends at the two bathroom
doors behind the shaft backs.

Reception's double doors beside the desk open directly into the classroom,
without a vestibule. Its single door on the entering player's left is now closed
and locked. The separate room and additional room remain modeled behind it,
extending to the front boundary, and are outside the accessible playtest route.

The open reception passage on the player's right leads into Hallway 2. Two
small rooms sit near reception, entirely on the reception side of Hallway 1's
end. The corridor continues into a large indoor open area behind the bathroom,
with no separating wall or doors, and along the classroom to the front boundary.
Original reception seating and art are reused in this open area.

The ground floor has one original street entrance, the retained stairs/right
ramp and elevator route, the L-shaped brown-door room behind the shafts, and
larger left/right neighboring spaces. Both have locked glazed street doors at
approximately `x = ±9.39`. The left space also has a locked interior glazed door;
the bakery is visible from the lift approach through a fixed window, with no
internal entrance. Its stocked display case, oven, bread racks, wall shelves and
coffee equipment are illustrative dressing. The street entry has fixed
sidelights, a transom, corner returns and a matching floor finish. There is no
duplicated entrance or long front approach.
The nearer opening in the brown-door room also has a locked glazed door; the
existing farther glazed door remains visible behind it.
The classroom and larger ground-floor left room each have about 192.4 m² of
modeled floor area. These dimensions and unseen spaces are authored estimates,
not surveyed architecture or certified emergency-egress plans.

Run `godot --headless --fixed-fps 60 --path godot --script res://playtest/tests/verify_layout.gd`
for the continuous character route. Its 141 checks cover the desk's position, collision and
ramp bypass, source resolution, preserved core
and untrimmed bank transforms, room areas/limits, entrance closure, brown-room circulation,
the actual lift/right turn, classroom, locked separate-room entry, open area,
front boundary and return lift. Actual character attempts verify that both
street doors, nearer brown-room door, bakery window, reception side door, opposite lift
door, two hall rooms and bathrooms block
entry. The last lift's side pocket is sealed; the landing has a left exterior
window looking toward a nearby decorative courtyard building. Generic ROOM
labels are removed. Bathroom doors have signs and remain
closed; no bathroom interiors are required for this playtest.
The upper cab's exposed steel side is enclosed by an opaque shaft return. Three
retained upper trim boxes are shortened to that return, clearing the former
projection from the hall; the cab and elevator-door positions stay fixed.

The cab/lobby floors are cut around each retained metal sill; four cab plates
are rebuilt to remove coplanar faces. Checks inspect actual sill bounds, the
bathroom/shaft join, entrance door rails, corner/threshold closure, nonoverlapping
door/window trim, and reception furniture/wall clearance.
The classroom monitor cabinet is reused against the projection wall, leaving
the shared entry clear. Its bin and lid stay inside the classroom, clear of the
locked reception side door. Other classroom furniture geometry remains retained.
The character uses normal movement/collision, with no room-to-room teleportation.
The visible review harness additionally walks 78 accessible-route segments;
locked-room tests stay in the physics suite. Continuous human camera/play feel
and architecture beyond the supplied photos remain user review.

The runtime assembly contains 2,096 meshes and 133,840 collision triangles.
The source GLB and native master are retained unchanged; these Godot layout
changes have not been baked back into the downloadable GLB. No source photos,
native Blender files, review frames or machine-specific paths are published.

### Visual defect checks

Use a short loop: identify the exact player location in F3, compare with the
photo reference, inspect a matched normal view plus an oblique/detail view,
repair the owning geometry, then repeat the real character route and collision
checks. Keep one review window open and reload it between batches. Save an
approved visual baseline before using pixel differences to flag future changes;
a screenshot comparison does not replace checking access and floor continuity.

Godot supports [runtime collision visualization and scene inspection](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html).
Its [3D rendering guidance](https://docs.godotengine.org/en/latest/tutorials/3d/3d_rendering_limitations.html)
explains why nearly coplanar surfaces flicker; eliminate the overlap before
adjusting camera clipping planes. The practitioner guide
[6 steps to a successful playtesting process](https://www.gamedeveloper.com/programming/6-steps-to-a-successful-playtesting-process-for-an-indie-developer)
supports focused checks with explicit success criteria and recorded feedback.
