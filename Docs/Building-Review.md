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
Character movement, authored collision, navigation, interactions and performance
optimization remain Godot implementation work. Game Level 1 is not floor 1.

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
See the current Markdown PRD for gameplay scope and outstanding team decisions.
