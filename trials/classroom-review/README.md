# Classroom asset review

An isolated Godot project for inspecting the Blender classroom trial. It does
not change the game's existing main scene or progression. Dimensions are
estimated from reference photos; this is a modeled room, not a measured scan.

Copy the trial's generated `Pursuit Classroom.glb` into `assets/classroom.glb`.
Generated models, extracted textures, import caches, and review evidence are ignored by Git. Keep
the editable Blender master and selected previews in the creative project.

With Godot 4.7.2 available as `godot`:

```powershell
godot --headless --editor --path . --import
godot --headless --path . --fixed-fps 60 -- --verify
godot --path .
```

Run from this folder. The verification command checks imported geometry,
approximate expected room bounds, a capsule settling onto the floor, a six-meter
walk down the central aisle, and a ray hitting the side wall. It writes an
ignored `evidence/verification.json` receipt and returns a nonzero exit code on
failure. A missing asset is an error, not a passing placeholder.

For an actual rendered engine preview:

```powershell
godot --path . -- --snapshot
```

This writes `evidence/Godot Classroom.png`. Rendering requires a working graphics
driver; the headless geometry/physics check does not prove rendered appearance.

Controls: WASD to walk, mouse to look, Escape to release/recapture the cursor,
and R to reset. The fixture adds temporary per-mesh collision shapes, lighting,
and a first-person walker. Authored simplified collision, a complete circulation
audit, moving doors, gameplay integration, and target-device performance remain
separate production work.
