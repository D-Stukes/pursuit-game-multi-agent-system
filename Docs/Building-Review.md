# Pursuit building — interactive review

The complete portable review package is in `trials/building-review/` at the repository root. Commands and asset paths below are relative to that package folder. It includes the combined
building GLB and a local Three.js viewer. No source photographs, image galleries,
Blender masters, private notes or CDN dependencies are included. The GLB contains
its generated surface materials; keep those embedded textures with the model.

## Open the review

Use Python 3.10 or newer. No Python or Node packages need installing.

1. Download/clone this branch, or copy the entire `trials/building-review` folder with its subfolders.
2. On Windows, double-click **Open Review.cmd**. Alternatively, open a terminal in
   the package folder and run `python serve.py --open` (`python3` on some systems).
3. Open <http://127.0.0.1:8767/> if your browser does not open automatically.
4. Leave the terminal running while reviewing; press Ctrl+C to stop.

If the port is occupied, use `python serve.py --port 8768 --open`.
Do not double-click `index.html`: browser file restrictions prevent model loading.
The server binds only to your own computer and serves an explicit file allowlist.
No public hosting or sharing service is configured by this package.

## What to check

- Drag to orbit, scroll/pinch to zoom, right-drag to pan; use Reset view to recover.
- Follow the route stops: entrance, right ramp, ground elevators, second-floor
  arrival, reception, separate single-door room and double-door classroom.
- Use Ground floor and Second floor for cutaways. Classroom is a camera shortcut
  into the same combined model. Toggle ceilings and route overlays as needed.
- Use Download GLB to inspect the complete asset in Blender, Godot or another
  compatible glTF application. Viewer cutaways never change the downloaded asset.

The brown-door room, larger left area and ramp-side elevator forecourt follow
Dennis's corrections. Both elevator banks align. A structural band joins the
storeys. Reception's single door leads to a separate room; its double doors lead
to the classroom, which stays inside the building and behind the street facade.

This is a static photo-reference model. Dimensions, the unseen right wing,
separate room, connector and longer hallway remain estimates. The elevator floor
change is a camera change, not a working elevator or continuous walk-through.
The Godot playtest below adds character movement and generated static collision.
Agent interactions, game navigation and performance optimization remain work.
Game Level 1 is not floor 1.

## Asset identity and checks

- Asset: `assets/pursuit-building.glb`, 12,945,724 bytes; 2,160 mesh nodes.
- SHA-256: `555faee67533b58fa02c3011be719a609c2c9c3432593dcd05062006bfa590b3`.
- Workstation source-path metadata was removed from this shared copy. All other
  scene data and the complete binary geometry/material payload are unchanged.
- Production: Blender 5.2.2 LTS, manually built from photo references and Dennis's
  layout corrections; not a photogrammetry reconstruction.
- Viewer: Three.js 0.180.0; its MIT license is retained in `vendor/LICENSE.txt`.
- Existing native/fresh-import checks covered seven sampled routes. Those checks
  do not replace game-engine collision, accessibility or measured-building checks.
- Run `python -m unittest discover -s . -p "test_*.py"` from the package folder to check
  package integrity, model/manifest coverage and the server's privacy boundary.

No new browser interaction test was performed for this handoff. HTTP responses,
asset identity, module dependencies and JavaScript syntax were checked; interactive
WebGL controls still need a partner's browser review.

## Next playable increment

Import this GLB into Godot using Blender → GLB → Godot. Author simple collision,
add a character controller, connect elevator floor transitions and implement one
reception facilitator interaction. Keep this Three.js page as the review tool.
See [Project-Plan.md](Project-Plan.md) for the active gameplay scope and next steps.

## Godot camera playtest

From the repository root, double-click **Play Building.cmd** on Windows, or run
`python tools/run_playtest.py`. The helper reuses an existing Godot installation
(PATH, `GODOT_BIN`, or this workspace's portable Tools folder), stages the canonical
GLB inside the Godot resource root, imports it and opens the building scene.
The Windows launcher can reuse Blender's bundled Python; no packages are installed.

Use WASD/arrows to walk, hold Shift to run, mouse to orbit, wheel to zoom, and
R to reset the current review location. Escape opens/closes Settings and releases
the mouse while the menu is open. Movement, look, zoom and location shortcuts
are blocked until Resume/Escape closes it. Keys 1/2/3 select entrance,
reception and classroom test spawns. Near an elevator, E transfers between its
ground and second-floor landing. This is an explicit playtest transition, not
an animated elevator. Turn right before the stair railing and use the ramp.
When a nearby wall pushes the camera very close, the avatar hides temporarily
to keep its head from blocking the view; it returns as the camera moves clear.
The initial instruction hint disappears after five seconds. The compact title,
current floor and top-right Settings button remain; all instructions are in
Settings, with a contextual elevator prompt only when nearby.

The building is loaded from an ignored, hash-checked runtime copy in
`godot/assets/generated/`; its canonical GLB remains unchanged in the review
package. Physics collision is generated from the existing geometry. The old
first-person blockout remains in `godot/Main.tscn`; the new playtest is the default.

Run `python tools/run_playtest.py --test` for actual Godot physics/camera checks.
They cover the three spawn floors, human-scale entrance/ramp/elevator/reception
movement through the classroom double-door connection, explicit lift transition,
wall blocking, camera retraction, input
release and pitch/zoom bounds. Results are written under ignored
`godot/.godot/playtest/`. Agent interactions and stars are not wired into this
scene yet.

F3 opens Developer Tools in debug builds: position/floor/FPS and location jumps.
These review controls are separate from the player instructions in Settings.
For running, the five-second hint and menu checks, run Godot with
`--headless --path godot --script res://playtest/tests/verify_controls.gd` from
the repo root. The 31 controls checks cover actual Shift/Escape/F3 input, held-input
blocking, animation changes and UI layout at 1280×720 and 800×600. They run without
opening a visible game. A stale wrapped-label height caused the previous blank
hint; it is now reset after text shaping. Fresh Forward+ frames verify visible
hint text and centered Settings/Developer Tools, including a narrower window.
`playtest/tests/live_review.gd` can keep one review window open and reload saved
scripts/scenes between batches; its fixed local commands and frames stay ignored
under `.godot/playtest/`. It uses engine APIs, not desktop automation.

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

Verification on October 24 with Godot 4.7.2: all 74 model/physics/avatar checks
pass, including skeleton pose changes while walking and the complete sampled
entrance → ramp → elevator transfer → reception → classroom route. The approved
building and native Blender hashes are unchanged. Earlier character proofs used
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
the camera. The opposite frontage is set farther back across a broad road, with a
perpendicular crossroad on the left. End-block buildings were removed so the road
continues in both directions, with light distance haze at the horizon. Decorative
building shells have matching camera collision.

The distant street is decorative, with no additional playable rooms. It is
illustrative context, not a reconstruction of real neighboring properties. The
Blender master, classroom and HTML review GLB remain unchanged; these additions
appear only in the Godot playtest.

The 74 core checks cover the prior movement/avatar route, walking/running into
the tape limits, camera clearance, distant frontage and deliberately open road
ends/crossroad. The separate 31 controls checks cover the timer, text containment,
menu/developer input and wide/narrow layout. Fresh GPU frames were inspected for
the revised UI and streetscape. Manual play feel and other-device performance
remain unverified.

UI references: the [Heliyon tutorial review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9676530/)
discusses practice, feedback and timely help; [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/indicate-allow-reminder-of-controls-during-gameplay/)
supports making control reminders available after the introduction.
