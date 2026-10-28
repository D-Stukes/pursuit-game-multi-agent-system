# Pursuit building review and Godot playtest

**Current layout:** Blender, Godot and the browser viewer use one blueprint-based
building export. Godot adds the player, camera, entrance puzzle and elevator
behavior. It no longer generates a separate room plan after importing the GLB.
The October 25 blueprint, reapproved on October 28, controls the room connections.
The photographs supply visual detail. The rejected photo-inferred floor topology
is superseded; Git retains its history.

## Launch and controls

From the repository root, double-click **Play Building.cmd**, or run:

```powershell
python tools/run_playtest.py
```

Use an existing Godot 4.7+ installation and Python 3.10+. The Windows launcher
can reuse Blender's bundled Python. Set `GODOT_BIN` to an existing executable if
tool discovery cannot find Godot. No browser server is required to play.

For inspection without the entrance game on Mac or Windows, open **Settings**
(Esc) and click **Review building**. The menu closes and
movement resumes with the entrance bypassed. The **Building Review** banner
confirms it. Reopen Settings and click **Return to play mode** to restore the
entrance lock unless you actually solved it. The bypass is session-only, grants
no puzzle completion and does not disable world boundaries or locked side rooms.

The Windows **Review Building.cmd** launcher and optional
`python tools/run_playtest.py --review` command still start review directly.
F3 exposes the developer toggle and location travel; the normal Settings button
needs no terminal command or function-key shortcut. Review controls are available
when running this development project in Godot; release builds exclude them.

Orange-and-white barricades mark both street limits, just beyond the trees
flanking Pursuit. Invisible collision closes those limits across both sidewalks
and the road; it stays active during building review. Roads, side streets and
industrial building scenery continue beyond the barricades on both ends.
Those background blocks suggest the neighborhood rather than claiming surveyed
photo matches. The shared manifest records the review bounds separately from
the photographed building footprint.

- Move with WASD/arrows; hold Shift to run.
- Move the mouse to look; use the wheel to zoom.
- Press E near the street entrance to solve Sense → Decide → Act and enter the
  revealed code. The lock persists for this session; R does not relock it.
- Walk through the entrance and up the stairs or right ramp. Continue forward
  into the hallway; the elevators are on its left wall. Press E near the first
  cab. Upstairs, the exit faces a closed white door. Turn right toward reception.
- Reception has direct classroom double doors beside the desk, a locked glazed single
  door to the L-shaped larger room, an open single glazed door to the additional
  room beside the classroom, and an open connection to Hallway 2. That hallway
  passes two small rooms and joins the commons without a door or wall. Hallway 1
  separately ends at the bathrooms behind the elevator shafts.
- The yellow ground side-room door also stays locked during building review.
  The bench is against the wall opposite the lifts. The kitchen is along the
  bathroom-side wall, beside Godot position `(-7.23, 5.07, -9.49)`, and reception's
  footprint is approximately 9.4 by 5.74 m after the latest expansion. Hallway 2
  has about 3.18 m clear width; the classroom retains approximately 82.4% of its
  preceding floor area and all six table groups.
- Esc opens Settings; R resets the current review location. F3 exposes developer
  review teleports. Those are inspection tools, not gameplay progression.
- Every computer and laptop has **E / Use computer** above its display when
  nearby on the same floor. Approach and face a computer, then press E to fade
  into Mr. P's hexagonal purple room. Move around normally; use E at its marked
  return pad to return to that same computer. R resets your position inside the
  room. The wall panels are layout previews; questions and rewards are not active.

The elevator shooter, check-in UI, stand-up sequence, live Mr. P questions and
robot challenge are still separate gameplay work. The computer portal is a
spatial playtest and grants no story progress or changes to retry/energy rules.

## Approved blueprint and photo references

The authoritative drawing is `Proposed Hallway Rooms - Aligned with Hallway 1.png`
in the private Creative reference folder. Dennis approved its connections on
October 25 and reapproved them on October 28. The manifest records its SHA-256.
Its filename predates that approval. It is not to scale: room dimensions can
change to fit the references while the approved connections remain fixed.

The [reference folder](https://drive.google.com/drive/folders/1eSOzOeCtZ_QwVe4NcJFAeeQdDKk-Z5Vv)
contains 34 still photographs and 33 MOV companions. All 34 stills were visually
reviewed; the MOV companions were inventoried, not reviewed. These photographs
guide materials, glazing, furnishings, services and exterior appearance. They
do not override the approved blueprint's ramp hallway or upstairs room plan.

There are **two playable floors**: ground/first floor at street level and the
lower elevator forecourt, and second floor for Pursuit's reception, classroom
and commons. Higher exterior storeys and neighboring buildings are scenery.
Dimensions, unobserved room interiors and exact hallway lengths are estimates,
not surveyed measurements. The drawing left the additional front room's access
unspecified. Dennis's later October 28 clarification confirms its direct door
from reception; that connection is now part of the required door inventory.

### Reception photo landmarks

In [IMG_4794](https://drive.google.com/file/d/1sgrYFhgjDaR9eUA3SsFhp2H56h2UKWDd/view),
read the visible doors from left to right:

| Photo landmark | Confirmed destination |
| --- | --- |
| Glass entrance doors on the left | Reception entrance seen after turning right on leaving the upstairs elevator. |
| Door at the far end | Larger separate room. |
| Middle room door | Additional room beside the classroom; direct reception access confirmed by Dennis on October 28. |
| Rightmost room door | Existing classroom. |
| Opening beside the chair and classroom doorway | Internal hallway access. |

The following schematic records the approved playable connections. It is not a
measured plan; node position does not establish compass orientation or dimensions.

```mermaid
flowchart TD
    Ramp[Ground ramp] --> Forward[Continue forward into hallway]
    Forward -->|Elevators on left wall| Lift[Upstairs elevator arrival]
    Lift --> Landing[Building corridor]
    Landing -->|Turn right; reception entrance| Reception[Reception and lounge]
    Landing -->|Hallway 1 ends behind shafts| Restrooms[Bathroom doors]
    Reception -.->|Locked side door| Large[Larger separate room]
    Reception -->|Rightmost door| Class[Classroom]
    Reception -->|Restored single door| Additional[Additional room beside classroom]
    Reception -->|Open mouth beside classroom| Hall[Hallway 2]
    Hall --> Small1[Small room 1]
    Hall --> Small2[Small room 2]
    Hall -->|No wall or door| Commons[Open commons and kitchen]
```

Hallway 2 runs beside the classroom into the large open indoor area. Its two
small rooms stop at Hallway 1's end line, as drawn. Keep Hallway 1 and Hallway 2
distinct, and do not add a shortcut through the bathrooms or an unseen room.

### Photo coverage

| Photos | Placement | Implemented treatment |
| --- | --- | --- |
| 4770-4774 | Opposite-side streetscape | Matching industrial masses, window rhythms and roof pavilion. |
| 4775-4781 | Pursuit-side frontage and adjacent buildings | Reworked façade divisions, height and rooflines; higher storeys are scenery. |
| 4782 | Main street entrance | Narrower glazed framing with the entrance puzzle attached to its threshold. |
| 4783-4787 | Ground entrance, stairs, yellow partition, ramp and bakery window | Retained original core and fixed bank coordinates, forward hallway, bakery glazing, services and supports. |
| 4788-4789 | Upstairs elevator landing and corridor | Narrower landing with end-window and blue-glazing landmarks. |
| 4790-4793 | Outside reception and restroom circulation | Reworked reception threshold, separate outer corridor and columns. |
| 4794-4797 | Reception/lounge and internal passage | Photo finishes and lounge landmarks fitted to the approved direct classroom and Hallway 2 connections. |
| 4798-4801 and 4803 | Open commons | Kitchen finishes and island relocated to the bathroom-side wall confirmed in the walkthrough; lounge seating occupies the former kitchen side. |
| 4802 | Side workspace and telephone closet beside the commons | Side workstation dressing has estimated placement. The telephone closet's interior and separate access are not modeled. |


## Shared assets and maintenance

The canonical portable GLB is `trials/building-review/assets/pursuit-building.glb`.
Its identity, per-mesh cutaway metadata and review cameras are in `scene.json`.
`tools/prepare_playtest.py` checks that hash and stages the same geometry into
Godot's ignored generated-assets folder. Do not edit the staged copy directly.

[Building-Assembly.md](Building-Assembly.md) explains native Blender masters,
metre units, floor/module origins, collection assets, shared mesh data, doorway
interfaces and named gameplay anchors. The original Blender master is retained;
the redesign has its own native master. Native masters and new reference photos
are outside the public repository.

All 646 retained classroom props preserve their shape and material parameters.
Declared rigid assembly translations fit the tables, chairs, lighting and storage
to the shorter classroom; the complete planter remains inside the room.
The native validator independently reimports the pinned source and compares every vertex
under these declared transforms, as well as checking room bounds. It also
compares all retained ground-core and lift-bank shapes and materials against
the original source, including the declared rigid closed pose for the yellow leaf.

## Verification

After rebuilding/promoting the export, import the Godot project, then run:

```powershell
python -m unittest discover -s tests
python tools/run_playtest.py --test
```

Additional Godot scripts under `godot/playtest/tests/` verify layout/doorway
clearances (`verify_layout.gd`), controls (`verify_controls.gd`) and the entrance
puzzle (`verify_entrance.gd`). Run with `godot --headless --path godot --script
res://playtest/tests/<script>.gd`. Use `capture_environment.gd` to render the
export's reference viewpoints and `capture_playtest.gd` for actual game views.
Native Blender validation is separate from the runtime checks.

Technical checks establish geometry interfaces, source preservation and tested
routes. They do not establish measured accuracy, user approval, or that every
unseen detail matches the building. Furniture and façade details are stylized.

## Envelope and review consistency

The main facade encloses the entire occupied floor footprint. Adjacent scenery
begins outside that footprint; it does not supply transparent exterior walls for
the classroom or commons. Solid piers, spandrels and window heads close the
facade bays. `verify_layout.gd` checks doorway clearances, the closed opposite
door, the forward ramp hallway, bank-end floor support, the right-turn reception
sightline and the open Hallway 2/commons join against the imported geometry.
It also samples the main facade's joints and formerly open bands.
The approved door inventory in [Building-Assembly.md](Building-Assembly.md#approved-door-inventory)
is checked for physical frames and leaves as well as openings. The additional
room doorway, expanded reception and added hallway width have actual walking
checks; a manifest-only connection cannot establish a playable route.
`tools/verify_environment_fresh.py` runs the engine suites in an
isolated, initially empty import cache with retained current inputs.

Game and review renders share `playtest/EnvironmentLighting.gd`, including
ambient/contact shading. The character review retains its separate studio.

## Optional browser review

Use `trials/building-review/Open Review.cmd` or run:

```powershell
python trials/building-review/serve.py --open
```

Open the local address shown by the server. Orbit, zoom, choose a floor or photo
view, and download the same GLB used by Godot. This is a static model review;
it does not simulate elevator travel, the avatar or game interactions.
The server's allowlist excludes private source files and reference photographs.
