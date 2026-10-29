# Pursuit The Journey

A career-journey game by Lady D and Dennis. The current Godot build is a
third-person building playtest with a four-level entrance pipe/code puzzle and
an elevator spaceship shooter;
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
energy and integration details. The entrance puzzle, elevator shooter and
computer portal to the purple room and upstairs check-in are implemented locally;
the Program Manager classroom sequence is connected too. Mr. P’s course gameplay remains separate. The environment follows
the approved blueprint
with photo-based finishes; dimensions remain estimates.

Work from `develop`. For the current playable building layout, double-click
**Play Game.cmd** on Windows or run `python tools/run_game.py` from the
repository root. This needs Godot 4.7+ and Python 3.10+; the Windows launcher
can reuse Blender's bundled Python. The [building guide](Docs/Building-Review.md)
covers controls, tool discovery and checks.

There is one Windows launcher. Normal launch plays the game. Developer options
use the same launcher or Python entry point:

| Purpose | Command from the repository root |
| --- | --- |
| Normal game | `python tools/run_game.py` |
| Bypass the puzzle gates for inspection | `python tools/run_game.py --dev` |
| Isolated character art review | `python tools/run_game.py --characters` |
| Local browser model reviewer | `python tools/run_game.py --browser-review` |
| Headless building/physics check | `python tools/run_game.py --test` |
| Keep one developer review game open | `python tools/run_game.py --live-review` |
| Check that same running review game | `python tools/run_game.py --review-status` |

During development, keep the Godot editor open. The [persistent testing
workflow](Docs/Building-Review.md#keep-godot-open-during-development) explains
live editing and repeated screenshot/movement checks in one review process.
Review commands start no additional engine or import. Source changes that cannot
be applied safely require restarting play, rather than closing the editor.

Use the keypad on the left of the street entrance: press E, solve the four
pipe boards and enter the revealed code to unlock the door.

The same options work with `Play Game.cmd`. In a development game on Windows
or Mac, **Settings -> Developer Tools** or **F3** opens the bypass toggle and
location controls. Turn the bypass off to restore undefeated gates. Developer
inspection does not complete either game or award progress.

Godot has one game entry point, `godot/Main.tscn`. Runtime scripts live in
`godot/game/`, reusable scenes in `godot/scenes/`, and models and data in
`godot/assets/`. `godot/developer/` contains the developer menu and isolated
character reviewer; its `tests/` folder contains verification and capture
scripts. `tools/` holds the Python launch, asset-preparation and verification
utilities. Generated imports and check output stay in the ignored `.godot/`
cache. Normal play does not start the agent service or prepare private art.

Use the **--characters** developer option for the isolated character art preview. It stages
the existing private exports from Creative. The main game includes portable
rigged Mr. P and robot assets, plus five humanoid role actors. Mr. P is in the compact
hexagonal purple room: approach any
computer/laptop and press **E** to enter through a fade. Its marked return pad
sends you back to the same computer. The robot stays in the classroom, face-up
in seven separate modules. The question panels are previews. Editable masters and
preview layers remain private. [Character assets](Docs/Character-Assets.md)
documents reusable scenes, placement and animation budgets, rebuilding,
validation and the boundary with later gameplay integration.

The shared session now tracks verified entrance and elevator wins and displays
the next objective. Upstairs reception offers name entry, an in-game avatar
photo and explicit check-in confirmation; the next boundary is the classroom
introduction, followed by the objective to use a classroom computer. The Program Manager uses scripted captions/gestures and a synthetic crowd murmur. Later course work remains separate. Developer review permits
inspection without awarding progress.

The normal HUD also shows shared energy/maximum, score and course activity
progress. It works without Developer Tools. Activities remain not started until
a course supplies its required set; temporary work is labelled **Sample
activities**. The display reads verified results and never awards progress.

For temporary course-rule testing, complete check-in and the classroom
introduction, enter the purple world through a computer, then use **F3 -> Sample
course (temporary)**. Its labelled fixtures exercise retries, energy, score,
recovery and completion through the shared Orchestrator. The sample checkpoint
is not the robot game. After verified sample completion, close the panel for
the classroom results, brief assessment and L3 story ending. Developer Tools
also offers **Preview Ending**, which restores your position/view and progress.
**Play Again** starts a fresh session; **Settings → Restart Run** asks for
confirmation. Godot stays open. Progress is session-only. Lady D's real Mr. P,
robot and Dial-a-Friend remain separate.

The **Builder companion** near the entrance has **E / Ask Builder**: a scripted
greeting, then next-step, hint or step-by-step help grounded in the current
pipe/shooter state. Local help works without a key. `--agents` enables optional
Claude wording only after a help choice. Memory holds two recent exchanges;
the companion cannot award progress. Reception conversations and contact-gated
background chatter are scripted. The entrance host and Program Manager also
have authored conversations. Each closed conversation resumes that character's
short walking/activity routine; Settings and other interactions pause it.
Obstacles make the character wait, and movement never invokes Claude.
See [NPC setup](Docs/NPC-Agents.md) for limits and
mock verification and the October 28 Windows/Godot live Haiku 5.5 check. Broader
reply quality, other machines/models and Mr. P integration remain unverified.

The **--browser-review** developer option shows the same building export in a
browser. This starts a local review
server. Godot adds gameplay to that shared geometry; the browser viewer supports
inspection and downloading the canonical GLB.

GitHub reported this repository as **public** during the October 26 metadata
check. Earlier private-repository wording was incorrect. Historical commits
contain reference photographs and the deleted brainstorm recording; deletion
from the current tree does not remove that history. Review visibility and
publication scope before sharing further source materials. The retained
[October 21 transcript](Docs/Archive/Ideation-Transcript.txt) and archived
synthesis preserve the brainstorm's text.
