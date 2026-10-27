# Pursuit The Journey

A career-journey game by Lady D and Dennis. The current Godot build is a
third-person building playtest; facilitator agents and the full gameplay loop
are not connected to it yet. The standalone Python agent prototype and static
browser model reviewer are retained; the old web game and standalone Godot
blockout were removed at Dennis's request. Dennis approved the title
The Journey and the role name Check-In Console on October 26. The unchanged
prototype code and historical sources still contain The Climb and Greeter;
those are legacy names, not alternate current product decisions.

**Start with [the active project plan](Docs/Project-Plan.md)** for scope,
agreed decisions and next milestones. [Docs/README.md](Docs/README.md) lists the
working documents; [Docs/Archive](Docs/Archive/README.md) holds earlier PRDs,
decision records and reference material.

Current work is documentation cleanup and collecting the remaining building
reference photos. Final gameplay design waits for Lady D's pending gameplay
work to be pushed and reviewed. Her existing walkthrough branch adds a browser
route demo; it is not the unconfirmed pending gameplay branch. The plan records
the handoff dependency and the current, provisional first-demo baseline.

Work from `develop`. For the current playable building layout, double-click
**Play Building.cmd** on Windows or run `python tools/run_playtest.py` from the
repository root. This needs Godot 4.7+ and Python 3.10+; the Windows launcher
can reuse Blender's bundled Python. The [building guide](Docs/Building-Review.md)
covers controls, tool discovery and checks.

For the earlier static layout in a browser, use
`trials/building-review/Open Review.cmd` or run
`python trials/building-review/serve.py --open`. This starts a local review
server, not Godot. The viewer does not include the current Godot room assembly,
desk or exterior scenery, and its downloaded GLB retains that static layout.

GitHub reported this repository as **public** during the October 26 metadata
check. Earlier private-repository wording was incorrect. Historical commits
contain reference photographs and the deleted brainstorm recording; deletion
from the current tree does not remove that history. Review visibility and
publication scope before sharing further source materials. The retained
[October 21 transcript](Docs/Archive/Ideation-Transcript.txt) and archived
synthesis preserve the brainstorm's text.
