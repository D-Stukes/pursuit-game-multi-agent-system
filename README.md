# Pursuit The Journey

A career-journey game by Lady D and Dennis. The current Godot build is a
third-person building playtest with a local entrance ordering/code puzzle;
facilitator agents and the full gameplay loop
are not connected to it yet. The static browser model reviewer is retained;
the disconnected Python agent prototype, old web game and standalone Godot
blockout were removed at Dennis's request. Dennis approved the title
The Journey and the role name Check-In Console on October 26. The
historical sources still contain The Climb and Greeter;
those are legacy names, not alternate current product decisions.

**Start with [the active project plan](Docs/Project-Plan.md)** for scope,
agreed decisions and next milestones. [Docs/README.md](Docs/README.md) lists the
working documents; [Docs/Archive](Docs/Archive/README.md) holds earlier PRDs,
decision records and reference material.

Lady D's PRD and charts have been reconciled into `Docs`, preserving the
approved retry and energy rules. The [source disposition](Docs/Archive/2026-10-27/README.md)
identifies the original drafts, removed duplicates and retained visual assets.
No playable challenge or agent implementation came with that documentation
delivery. The subsequent October 27 discussion replaces the checklist/three-star
structure with an entrance puzzle, elevator shooter, upstairs check-in, classroom
introduction, live Mr. P question world and one robot-assembly challenge. The
active plan records the selected route, narrative ending and unresolved content,
energy and integration details. The entrance puzzle is now implemented locally;
the rest of those features are not. The environment follows the approved blueprint
with photo-based finishes; dimensions remain estimates.

Work from `develop`. For the current playable building layout, double-click
**Play Building.cmd** on Windows or run `python tools/run_playtest.py` from the
repository root. This needs Godot 4.7+ and Python 3.10+; the Windows launcher
can reuse Blender's bundled Python. The [building guide](Docs/Building-Review.md)
covers controls, tool discovery and checks.

For free building inspection on Windows or Mac, open **Settings** (Esc) in the
game and click **Review building**. The menu closes and
the entrance opens for this debug session. **Return to play mode** in Settings
restores puzzle mode. The bypass does not complete the puzzle or award progress.
On Windows, **Review Building.cmd** also starts review directly; the optional
command is `python tools/run_playtest.py --review`. F3 still opens developer
tools and location teleports.

Use **Review Characters.cmd** for the isolated character art preview. It stages
the existing private exports from Creative. The main game includes portable
rigged Mr. P and robot assets, plus sixteen ambient NPCs. Mr. P is in the compact
hexagonal purple room: approach any
computer/laptop and press **E** to enter through a fade. Its marked return pad
sends you back to the same computer. The robot stays in the classroom, face-up
in seven separate modules. The question panels are previews. Editable masters and
preview layers remain private. [Character assets](Docs/Character-Assets.md)
documents reusable scenes, placement and animation budgets, rebuilding,
validation and the boundary with later gameplay integration.

For a static browser review of the same building export, use
`trials/building-review/Open Review.cmd` or run
`python trials/building-review/serve.py --open`. This starts a local review
server. Godot adds gameplay to that shared geometry; the browser viewer supports
inspection and downloading the canonical GLB.

GitHub reported this repository as **public** during the October 26 metadata
check. Earlier private-repository wording was incorrect. Historical commits
contain reference photographs and the deleted brainstorm recording; deletion
from the current tree does not remove that history. Review visibility and
publication scope before sharing further source materials. The retained
[October 21 transcript](Docs/Archive/Ideation-Transcript.txt) and archived
synthesis preserve the brainstorm's text.
