# Mr. P and challenge robot assets

The supplied Dandy Jinn sheet and purple ghost portrait guide **Mr. P's appearance**;
the sheet title does not rename the game character. UNIT 74 guides the robot.
These are new original meshes, built from those visual references with Blender.
Reference-sheet annotations are source labels, not additional gameplay requirements.

## Source and game boundary

Editable `.blend` masters, transparent preview art, references and render evidence
remain in the existing private Creative project. On October 28 Dennis explicitly
requested the two models in the game files. The selected self-contained 3D GLBs
are therefore delivered under `godot/assets/characters/authored/`, with source
identities and rig/clip metadata in `assets.json`. A code checkout includes those
runtime assets. `python tools/prepare_characters.py --game` validates both reviewed
export receipts before replacing them; no private master is copied into Git.

The separate art viewer retains its ignored staging cache under
`godot/assets/generated/characters/`, including the optional 2D layers. Its default
preparation command is unchanged. The main game needs only the portable 3D GLBs.

## Runtime character placement

`godot/scenes/ClassroomCast.tscn` instances `RobotRepair.tscn` and its repair
bench. `PurpleRoom.tscn` now owns the reusable `MrP.tscn` instance, replacing
his temporary classroom position. Both original skeletons and skins stay intact.
Mr. P plays a subtle Idle at a uniform display scale. The robot lies face-up
on a repair bench with seven separated modules, posed through the original
17-bone rig. Each piece rests on the same surface; the rig can still move it.
No assembly-game behavior or automatic conversation is connected.

The cast is separate from the building GLB and its collision mesh. The bench
uses one simple box collider. Existing classroom furnishings and doors retain
their placement. `verify_cast.gd` checks actual skin bindings, weighted vertex
positions, seven-part separation, tabletop support and continued poseability.
The normal building suites still verify the accessible routes.

## Purple room and computers

`godot/scenes/PurpleRoom.tscn` is a native, editable Godot interior with a
six-sided shell, about eight metres across its flat sides and a 3.8 m ceiling.
The supplied room example guides its lavender walls, cream ceiling/trim, grey
carpet and six framed preview panels with yellow answer slots. Text in that
image is not a course answer key. `QuestionBoard.tscn` is shared by the six
panels; real content and question interactions remain Lady D's responsibility.
Six visual slots do not select a required question count or change the
temporary sample-content rules in the PRD.

`ComputerPortal.tscn` places the room at Godot `(32, 5.058, -48)`, separately
beside/behind the building and clear of the retained backdrop geometry. The
building export/layout is unchanged. The room uses simple static collision,
shared meshes/materials and one local light; its models, light and Mr. P's rig
are hidden or paused when unused. Its camera environment applies only inside.

`ComputerPortal.gd` registers all 17 current computer display bodies: thirteen
laptops and four desktop displays, including reception. Bases, stands, TVs and
projection screens are not separate computer interactions. Every device has an
E / Use computer label, shown on the same floor within ten metres. The nearby
reachable screen best aligned with the camera is highlighted; range is 1.8 m
and a nearer wall blocks use. Markers follow the actual imported mesh bounds,
so approved furniture placements remain the single source of their positions.

E locks movement for a short fade, transfers the player only while opaque,
then restores movement in the purple room. The return pad sends the player to
the exact originating computer position/view through another fade. R resets
the player within the room; developer location travel safely restores normal
lighting and exits the room. Repeated use and menu/travel input during the fade
are rejected. These transitions grant no puzzle, question, challenge or reward
completion. `verify_portal.gd` covers all devices and those interaction paths;
`verify_purple_room.gd` covers enclosure, floor, camera and walkable space.

## Ambient population

The main building also instances `godot/scenes/BuildingPopulation.tscn`: sixteen
background people across the street, ground floor, reception, classroom, commons
and a small room. Two existing reception actors now have social conversation
controllers; the other fourteen remain visual NPCs. The shared models/rigs are
unchanged. [NPC conversations](NPC-Agents.md) documents scripted greetings,
keyless local preview, optional Claude replies and bounded ambient exchange.
Four selected variants come from Quaternius's
[Ultimate Modular Men](https://quaternius.com/packs/ultimatemodularcharacters.html)
and [Ultimate Modular Women](https://quaternius.com/packs/ultimatemodularwomen.html),
the same creator and modular collection as the current player. Creator-supplied
CC0 terms accompany the runtime assets in `quaternius-population/LICENSE.txt`.
Each model retains its 62-joint skin and original animation clips. The suit's
optional pistol mesh is hidden on ambient instances; the source rig is retained.

`godot/assets/characters/population.json` is the placement authority, in Godot
XYZ metres: each entry has an ID, model, area, feet position, yaw and height.
Actors instance one reusable `AmbientNPC.tscn`; the four imported scenes share
mesh/material resources while skeleton poses remain independent. Uniform fitting
preserves proportions. Feet snap only within the expected floor band, and one
static capsule per person prevents walking through them. The camera ignores
those capsules. The building export and approved floor/door layout are unchanged.

One timer checks the population five times per second. At most eight nearby
actors in the camera's field of view on the player's floor run idle updates;
other models retain a still pose with processing disabled. Meshes stop rendering
at 32 metres, and ambient people do not cast extra shadows. There is no per-NPC
navigation, physics tick or continuous decision loop. A separate event coordinator
owns the two reception conversations; animation culling does not own AI state.
Cast actors remain separate
from this background population so future gameplay can own them explicitly.

Portable GLBs and provenance are under `godot/assets/characters/quaternius-population/`.
`python tools/prepare_population.py --source <retained-source-folder>` validates
the selected raw glTF hashes and repackages their embedded buffer as GLB without
editing geometry, weights, materials or clips. A regular checkout uses the
included GLBs and needs no private source folder or network download.
`verify_population.gd` checks floor contact, body clearance, skins, shared mesh
resources, unarmed suit instances and real animation advance/pause behavior.
`benchmark_population.gd` compares rendered frame times with and without the
population; its result is local hardware evidence, not a universal FPS guarantee.

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
The grin is an authored static expression; only the eyelids have facial morphs.
Speech visemes and live AI-driven expression control are separate integration work.

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

## Challenge robot

The UNIT 74 interpretation has gray/slate armor, a green striped visor, separate
mechanical panels, joint bearings and flexible colored wiring. A 17-bone rig
drives Idle, PowerOn and Assemble. Hard panels have rigid weights; only wiring
blends between adjacent bones. PowerOn keeps both feet planted. Assemble is a
one-shot transition from separated modules into their bind-pose positions.

```powershell
blender --background --python-exit-code 1 --python tools/build_characters.py -- --asset robot --output-dir "<Robot source folder>" --render
blender --background "<Robot source folder>/Robot.blend" --python-exit-code 1 --python tools/verify_native_characters.py
```

The output contains `Robot.blend`, `robot.glb`, its identity receipt and `parts/`.
The seven module IDs are `torso`, `head`, `power_core`, `left_arm`, `right_arm`,
`left_leg` and `right_leg`. Each is one independently visible skinned mesh.
Named `SOCKET_<part_id>` empties declare **bind-pose** target positions in metres
and the corresponding bone name. They do not follow live animation themselves;
use the declared bone for a moving attachment. They are not another coordinate
system or a license to change part scale.

Every PNG layer uses the same 768×1024 transparent canvas, orthographic camera
and bind pose. `parts/parts.json` records hashes, projection and draw order.
Do not crop individual layers, scale them separately or draw in arbitrary order.
Draw legs and arms first, then torso, head and power core. The complete and
individual silhouettes are compared by native verification; the Godot review
exercises the actual layered consumer.

After review, retain the selected robot GLB, `receipt.json` and complete `parts/`
bundle in `Creative/Blender/Pursuit - The Climb/Exports/Characters/Robot/`.
The staging tool validates every GLB and layer hash before replacing any cached
resource. A damaged layer cannot silently replace a previously working bundle.
Question-to-part mapping, scoring and challenge completion remain Lady D's
content and the later gameplay integration; those are not inferred from anatomy.

## Review in Godot

```powershell
python tools/run_character_review.py
```

This stages existing exports, imports them and opens `CharacterReview.tscn`.
The launcher reuses the same Godot discovery as the building launcher.
Choose Mr. P or Robot. Drag to orbit, use the wheel to zoom, F/P/B for fixed views
and T for turntable. Clip buttons refit the camera and play the named animations.
Idle loops; other clips play once and return to Idle. Esc closes the review.

Robot part buttons toggle the same named module in 3D and 2D. Choose **2D assembly
layers** to inspect the registered flat art; animation controls are disabled in
that static view. The review is an art inspection tool, not the playable challenge.

The import checks in `godot/playtest/tests/verify_characters.gd` exercise the
actual skeleton, skins, clips and eyelid morphs in Godot. Native verification
checks dependency containment, normalized skin weights, connected body topology
and numeric motion at every frame. Images from `capture_characters.gd` provide
fixed-view and representative-pose evidence. Sampled images are not proof of
every possible pose or continuous playback.

`python tools/verify_character_fresh.py` creates a separate initially empty
Godot project/cache using the current retained GLBs and part layers. It checks
fresh derived-cache generation with existing tools; it does not claim a fresh
Blender/Godot installation or fresh acquisition of the original reference images.

Measured source/export geometry is approximately 66k triangles for Mr. P and
36.5k for the robot. These are measured asset counts, not a target-hardware
performance certification. Scene-specific lighting, shadow setup and gameplay
budgets must be checked when the characters are integrated.

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
