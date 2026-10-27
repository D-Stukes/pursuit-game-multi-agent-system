# Project documentation

**Current phase:** the October 27 gameplay discussion selects a new route and
robot-building challenge. The earlier checklist, three-star objective system,
stoplight and ground-floor check-in are superseded. Gameplay implementation
and exact activity content remain outstanding.

| Document | Use |
| --- | --- |
| [Project plan](Project-Plan.md) | Single active PRD: selected route, decisions, ownership, current implementation and remaining questions. |
| [Agent flow and completion](Agent-Flow.md) | Coordination, stage verification, retries, live Mr. P/Helper, recovery and implementation gaps. |
| [Agent flow presentation](agent-flow.html) | Original animated source overview. Historical labels/reward rules are superseded by the active PRD; it is not an executable game. |
| [Mr. P character study](platform-character.html) | Supplied SVG/CSS visual concept, not an integrated Godot character. |
| [Building review guide](Building-Review.md) | Launch the existing environment and inspect asset identity and limits. |

The selected route is entrance puzzle → elevator shooter → upstairs check-in
→ classroom stand-up → laptop/portal to Mr. P’s purple world → questions and
one robot-assembly challenge → remaining questions → classroom/L3 story ending.
Use the plan’s [approved decisions](Project-Plan.md#approved-first-demo-decisions)
and [unresolved checklist](Project-Plan.md#unresolved-integration-and-player-state-questions)
for exact scope. Start at 10 energy; incorrect submissions cost 1; first error
rephrases, second offers stronger help. Use the approved
[temporary settings and sample Mr. P interface](Project-Plan.md#temporary-development-placeholders)
to start development: maximum 10, +1 correct-answer energy, +3 robot-completion
energy, recovery to 10, per-question attempt reset and 10/30 completion score.
Energy gains cap at 10; recovery retains attempts; declining recovery at zero
pauses submissions. These are replaceable playtest defaults. Lady D owns the
real questions, their order and completion rules; sample content is not final.
Mr. P and Helper are intended to use live Claude; no working connection is
claimed. This is a single-player game, with no real-human calling service.

Read intended gameplay separately from implementation status. Default Godot
is a movement/camera/elevator playtest, not the integrated game. No new game
features were delivered by the documentation reconciliation. Work from
`develop`; the merged documentation and old walkthrough branches are retired.

The [archive](Archive/README.md) preserves original PRDs and presentation sources.
[October 26 source notes](Archive/2026-10-26/Source-Notes.md) and
[October 27 source disposition](Archive/2026-10-27/README.md) describe earlier
reconciliation decisions as of their reviews. The later gameplay discussion
in the active plan supersedes those earlier baselines. Do not edit original
source snapshots to make them look current or create another numbered active PRD.

## Repository layout

- `Docs/` holds working documents and HTML source presentations; `Docs/Archive/`
  holds source history, Word drafts and image snapshots. There is one active PRD.
- `godot/` holds the playable building, avatar/camera and verification helpers.
- `agents/`, `demo/` and `tests/` hold the standalone Python prototype, example
  and tests. Its old names/state are not the current gameplay specification.
- `tools/` holds model-staging and Godot launch helpers.
- `trials/building-review/` holds the canonical GLB, static browser viewer and
  vendored dependencies used by the launcher. It is not a disposable trial.

The old web prototype, standalone Godot blockout, ignored classroom experiment,
Images folder and brainstorm MP3 were removed at Dennis’s request. The transcript
remains archived; tracked experiments remain in Git history. There are no separate
Documents/presentation roots. Generated Godot caches and runtime model copies
remain ignored. Building-reference photography and a later model update are
still planned.
