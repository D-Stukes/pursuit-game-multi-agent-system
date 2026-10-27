# Project documentation

Start with the active plan. These are the working documents:

**Current phase:** clean up documentation and gather building references.
Resume final gameplay design after Lady D's pending gameplay work is pushed
and reviewed. The exact incoming branch is not yet confirmed; the existing
walkthrough branch is not evidence that the pending games have been published.

| Document | Use |
| --- | --- |
| [Project plan](Project-Plan.md) | Current scope, agreed decisions, agent roles, gameplay rules and next milestones. |
| [Agent flow and completion](Agent-Flow.md) | Outer and inner loops, verified check-in, Mr. P retries, Helper return and current implementation gaps. |
| [Agent flow presentation](agent-flow.html) | Lady D's original animated overview, moved here unchanged. Use the active plan and Agent-Flow.md for current rules; the presentation is not an executable game. |
| [Building review guide](Building-Review.md) | Open the interactive model and check its asset identity and known limits. |

`Project-Plan.md` is the single active PRD: its approved-decision section owns
current scope and names; its future-design section lists details still to design.
`Agent-Flow.md`
records selected interaction behavior and recommended integration design
within that scope. `Building-Review.md`
owns environment launch and inspection instructions. Read implementation status
separately from intended behavior: the default Godot scene is a movement/camera
playtest, not the integrated agent game. Historical sources cannot override
these working documents. Record an agreed scope change in the plan before
updating its dependent flow or presentation.

For the current baseline, use The Journey and Check-In Console, the checklist
as the first demo activity, immediate advancement for a correct answer,
restatement after the first incorrect submission, a stronger-help offer after
the second, and starting energy 10 with cost 1 per incorrect submission. The
plan records Dennis's approvals; unchanged source attachments are history.

The [archive](Archive/README.md) contains earlier PRDs, the decision review,
brainstorm, pitch, architecture diagram and supplied reference guides. Those
files preserve context; their historical claims do not override the active plan.
The [October 26 source notes](Archive/2026-10-26/Source-Notes.md) distinguish
the supplied Claude artifacts, Lady D's proposals and the presentation feedback.

Maintain `Project-Plan.md` as decisions change. Keep source history in `Archive/`
instead of creating another parallel numbered PRD.

## Repository layout during the partner handoff

- `Docs/` holds the working documents and animated agent-flow presentation;
  `Docs/Archive/` holds source history and the other supplied attachments.
  No other PRD is active. Its README is a navigation index, not another plan.
- `godot/` holds the current building playtest. The unused standalone blockout
  (`Main.tscn`, `Main.gd`, `Player.gd` and their script UID sidecars) was removed.
- `agents/`, `demo/` and `tests/` hold the Python prototype, its runnable example
  and its tests. `tools/` holds the model-staging and Godot launch helpers.
- `trials/building-review/` holds the canonical GLB, browser viewer and vendored
  dependencies used by the Godot launcher. It is not a disposable old trial.

At Dennis's request, the obsolete `prototype/`, ignored `trials/classroom-review/`
and local `Images/` folders were removed, along with the brainstorm MP3 and
empty `Media/` folder. The transcript remains archived. Removed tracked
experiments remain accessible through Git history; ignored local experiment
files are deleted from disk. Generated Godot caches and runtime model copies
remain ignored. The current model, avatar, gameplay scripts, agent prototype,
launch helpers and verification checks are retained.
