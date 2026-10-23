# Pursuit document review

Read this page first. The 19 source documents are collected here so we can agree
on one project plan without treating every old draft as a current requirement.
Original Word files and the transcript are preserved. Markdown path references
were repaired where files moved; the source documents' competing ideas remain
available for comparison.

The inventory covers versioned project documents plus the additional develop
documents. Vendor licenses and ignored local fixture notes remain beside their
own files; the root/package READMEs are short navigation and launch pointers.

## Decisions agreed with Dennis on October 23

- **Five roles:** Orchestrator, Greeter, Platform, AI Helper and Scorekeeper.
  The Orchestrator coordinates and verifies handoffs; the Greeter handles
  check-in; the Platform presents tasks; the AI Helper assists; the Scorekeeper
  presents progress.
- **Hybrid first demo:** scripted Greeter, Platform, coordination and scoring;
  one live AI Helper call at the demo's help moment, with a scripted fallback
  if the call fails. Five roles do not mean five LLM calls. Provider selection,
  timeout and payload details remain implementation decisions.
- **Mini-game scope:** the first Godot gameplay demo focuses on the Foundation
  task and Platform/AI Helper loop. The existing web Bug Blaster stays optional;
  porting it to Godot and adding the keypad gate are deferred.
- **Character setup:** retain the existing five strengths: Great Communication,
  Tech Savvy, Coding Experience, AI Experience and Newbie + Curiosity. Outfits
  and a separate character-stat system are deferred; detailed bonus balancing
  remains implementation work.
- **Earned stars:** Show Up requires check-in, Do the Work requires completion
  of the short Foundation task, and Be a Teammate requires helping a peer.
  Using the AI Helper provides guidance; it does not automatically earn the
  work star.
- **Retained build direction:** Blender → full GLB → Godot. Three.js is the
  building review tool. Source photographs stay outside the shared review
  package. The combined building is a static, estimated model awaiting playable
  Godot integration.

These are Dennis's current consolidation decisions. They do not change the
original sign-off records or imply a new sign-off from Lady D.

## Recommended consolidation

Create one stable **Project-Plan.md**, rather than another numbered PRD. Use
v3's five-role structure, v2's October 23 building/Godot addendum, the useful
Level 1 and visual notes, and the supplied guides' ownership/handoff/fallback
checklist. Put unresolved choices in a short decision queue.

That plan should cover the goal, next playable milestone, player route,
responsibility of each role, handoff validation, failure behavior, gameplay
rewards and deferred features. Keep [Building-Review.md](Building-Review.md) as
the practical model-review guide and link the architecture from the plan.
Derive any future pitch from the agreed plan.

After the remaining choices are agreed, group the old PRDs, Word companions,
brainstorm and pitch as source history. Keep the two supplied guides as reference
material. Content merging, archival moves and deletions remain proposed; this
pass collects the files and records decisions.

## Conflicts and review order

| Topic | What differs | Disposition |
| --- | --- | --- |
| Agent count | v2 has three roles; v3 and the pitch have five. The generic guide suggests starting development with two. | **Resolved:** retain five project roles; a small two-role handoff test can still be the first implementation proof. |
| Live AI | The Level 1 document excludes LLMs; v2 proposes hybrid; v3 also suggests a live Platform. | **Resolved:** scripted core plus one live AI Helper call and scripted fallback. |
| Art and implementation status | v3 still describes real-photo backdrops, a photo-textured room and future photogrammetry. The main branch now has the manual building GLB and image-free reviewer. | Use the October 23 main-branch asset state. Retain the older claims as dated source history. |
| Mini-game scope | Earlier docs specify the Foundation task; v3 adds Bug Blaster, question-storm and a planned keypad gate. | **Resolved:** focus on the core Platform loop; other mini-games later. |
| Character setup | v2 proposes three student types; v3 proposes five weapon/strength choices. | **Resolved:** keep the existing five strengths; defer expanded customization. |
| Stars and handoffs | v3 awards Do the Work when the Helper is used; earlier documents require completing the task. | **Resolved:** three stars require three completed actions. Define precise validation and duplicate handling during implementation. |

The remaining engineering work is to make those rules explicit: which role
validates each action, what evidence crosses a handoff, how repeated events avoid
duplicate rewards, and how a failed or ambiguous Helper response falls back.
Recommended starting point: Greeter verifies check-in; Platform verifies the
Foundation and teamwork actions; one shared-state reward API enforces one award
per objective; Orchestrator verifies transitions; Scorekeeper renders the result.
The live Helper supplies guidance, not authoritative reward decisions. This is
the implementation proposal to reconcile with the existing develop code, rather
than a claim that it has already been built.

The six-zone route and a smaller first playable milestone can coexist: the
current build milestone is movement/collision, an elevator transition and one
reception interaction, followed by the full Level 1 loop. The two-week estimates
are dated planning assumptions, not a newly confirmed deadline.

## Source inventory

| Documents | Role in consolidation |
| --- | --- |
| [PRD v1](Pursuit-Game-PRD.md) · [Word](Pursuit-Game-PRD.docx) | Older multi-level/interview concept; source history. |
| [PRD v2](Pursuit-Game-PRD-v2.md) · [Word](Pursuit-Game-PRD-v2.docx) | Main-branch baseline and latest building addendum. Word is the earlier snapshot. |
| [PRD v3](Pursuit-Game-PRD-v3.md) · [Word](Pursuit-Game-PRD-v3.docx) | Five-role design from develop; its older art/status claims need reconciliation. |
| [Level 1 design](Level-1-Design-Doc.md) · [Word](Level-1-Design-Doc.docx) | Player route, stars, interaction details; overlaps the PRDs. |
| [Ideation synthesis](Ideation-Synthesis.md) · [Word](Ideation-Synthesis.docx) · [transcript](Ideation-Transcript.txt) | Brainstorm provenance; suggestions are not all approved requirements. |
| [Visual direction](Visual-Direction.md) | Art references and style target; includes proposed features. |
| [Agent architecture](agent-architecture.html) | Five-role explanation and diagram from develop. |
| [Pitch](pitch-outline.md) · [Word](pitch-outline.docx) | Presentation from develop; refresh its claims after the plan is reconciled. |
| [Agent design guide](how-to-think-about-designing-agents.docx) | General design checklist: roles, payloads, missing/ambiguous input and bounded fallback. |
| [Handoff example](handoff-fallback-model-answer.docx) | Property-listing worked example. Borrow the method, not its rental rules or 72-hour deadline. |
| [Former project overview](Project-Overview.md) | Snapshot of the former root README. |
| [Building review guide](Building-Review.md) | Launch instructions, current GLB identity and known limits. |

The six Markdown/Word pairs are companion versions, not exact duplicates. Their
wording varies, and the v2 Word document lacks the latest Markdown addendum.
They should not be silently treated as interchangeable or deleted yet.

## Branch provenance and code boundary

The original 12 planning/reference files came from main at `8e6e982`. PRD v3,
the pitch and the architecture page were collected from develop at `9c38b3f`:
[architecture PR 1](https://github.com/D-Stukes/pursuit-game-multi-agent-system/pull/1),
[pitch PR 4](https://github.com/D-Stukes/pursuit-game-multi-agent-system/pull/4),
[PRD v3 PR 5](https://github.com/D-Stukes/pursuit-game-multi-agent-system/pull/5).
Those PRs were merged into develop, not main.

Only the five additional document files were collected. The Python Greeter,
Orchestrator, shared state, demo and tests are present on develop and were not
merged or executed in this document pass. Their existence there does not mean
they are integrated into the main-branch Godot game. The supplied guides were
reviewed for content; their Word layout was not changed or assessed.
