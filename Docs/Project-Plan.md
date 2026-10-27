# Pursuit The Journey project plan

**Working plan · Updated October 26, 2026 · Team: Lady D and Dennis**

**Current phase: documentation cleanup and reference collection. Final gameplay
design is on hold until Lady D's pending gameplay work is pushed and reviewed.**
The decisions below are the current working baseline, not a claim that the
complete gameplay experience has been finalized or implemented.

This is the single active scope and decision record for Level 1, The Foundation.
It records Dennis's approved demo decisions and keeps future design work
separate. Use this
file for scope, [Agent-Flow.md](Agent-Flow.md) for the intended interaction
contract, and [Building-Review.md](Building-Review.md) for launch instructions
and the existing environment. The [archive](Archive/README.md) preserves dated
sources; they are evidence of earlier thinking, not competing specifications.

Work from `develop`. The building/camera feature was merged and pushed in
`305b179` on October 26; its temporary work branches were removed. The
[agent flow and completion contract](Agent-Flow.md) explains the loops and
the gap between the current Python prototype and the intended Godot integration.
Lady D's [October 26 presentation sources and feedback](Archive/2026-10-26/Source-Notes.md)
are retained for provenance. The approved decisions below supersede older
wording on the same topic. The design backlog at the end contains only work
that has not been decided; it does not reopen these decisions.

## Approved first-demo decisions

Dennis confirmed these decisions in the October 26 review conversation. They
define the documentation baseline; this documentation update does not implement
them in game code or imply that Lady D has already reviewed every change.

| Topic | Current decision |
| --- | --- |
| Game title | **Pursuit: The Journey**. The Climb is the former title. |
| Check-in role | **Check-In Console**, a self-service station. Greeter is its former role name and remains the existing Python class name. |
| Players | **Single-player**. Five architecture roles do not mean five players or five visible NPCs. |
| First Platform activity | Use the **Foundation checklist** to test the Mr. P interaction in the first demo. It asks the player to identify check-in, project submission and helping a teammate among distracting options. |
| Later question sequence | Lady D's question sequence is a **separate later milestone**. It is not a competing first-demo activity. Consider integration after its questions, answer rules, follow-up paths, help behavior and completion condition are authored and reviewed. Until a replacement is agreed, the checklist remains the first-demo activity; this does not make the checklist a permanent extra stage before a future question sequence. |
| Correct submission | Advance immediately after validating the correct answer; never require extra wrong attempts. Completing the checklist earns Do the Work once. |
| First incorrect submission | Restate the current question or task and allow another attempt. |
| Second incorrect submission | **Offer stronger help**. This is a help offer, not a forced AI call or automatic completion. The earlier five-try/five-re-ask proposals do not apply. |
| Starting energy | **10**. This sets starting energy only; recovery, a maximum and zero-energy behavior are not yet defined. |
| Incorrect-submission cost | **1 energy point per incorrect submission**. Costs for other actions have not been approved. |
| Checklist teaching goal | Recognize the three Builder habits: showing up, doing the work and helping others. Selecting the correct set demonstrates recognition; it does not itself perform a project submission or a peer-help action. |
| Check-in feedback | Show a brief celebratory Show Up reward popup, inspired by an item-acquisition moment. Exact visuals/audio remain design work; no existing game's assets or sounds have been selected. |
| Activity introduction | After the player exits the upstairs elevator, Mr. P appears and explains the activities. Dennis approved this introduction point; Lady D owns its character, dialogue and activity design. A Program Manager introduction is not an approved substitute. |

One incorrect submission to the checklist means one submitted selected set
that fails its answer rule, not one point for each wrong checkbox in that set.
The activity's detailed answer options and feedback still need design. Help
must not award Do the Work or mark an unanswered task complete.

The full Level 1 target still requires Show Up, Do the Work and Be a Teammate.
The exact peer-help activity remains undesigned; the suggested scripted
classmate has not been approved or added to the scope.

## Next work and pending partner handoff

Dennis plans to ask Lady D to push her pending gameplay work so it can be
reviewed on `develop`. He expects this on October 27; that is his reported
expectation, not a verified push or a confirmed commitment from Lady D. The
exact branch name is not confirmed. The October 26 remote inspection found
no submission-named branch; `feature/walkthrough-mode` is a different existing
branch and must not be assumed to contain the pending games.

Resume gameplay design only after the new commits are available for inspection:
identify the actual branch/commits, review the activities and run their relevant
checks, then agree which parts to incorporate into the first demo and later
design. Do not finalize a replacement task, cast or full gameplay loop before
that review. The checklist remains the working first-demo activity until an
explicit scope update; the newly discussed submission/debugging puzzles are
unselected suggestions, not additional requirements.

Meanwhile, Dennis will capture the remaining Pursuit reference photographs
and use them to guide a later 3D-model update. The immediate repository work
is documentation and folder review. No model update, new gameplay code,
partner message or scheduled monitoring is part of this documentation pass.

### Historical activity source

During source review, the older web prototype contained Bug Blaster, a
Platform question storm, scripted AI rescue, teammate-help choices and a
volunteering scene. The old Godot blockout contained the three-action checklist.
Dennis subsequently authorized removing those experiments from the working
tree on October 26. Their tracked source remains in Git history at `305b179`;
they are not current files or a replacement for Lady D's pending branch.

Review the actual incoming work before choosing reusable activities. The old
web teammate scene awarded its star for choosing to help, without verifying
actual debugging assistance; that historical behavior is not the integrated
game's completion rule. The prior inspection read source without playtesting it.

## Implementation status

| Area | Status on October 26 |
| --- | --- |
| Default Godot scene | `BuildingPlaytest.tscn`: playable building, third-person avatar/camera, stairs/ramp, elevator transfers and decorative street. |
| Ground-floor check-in desk | Scenery only. No player check-in prompt, dialogue, star or Python connection in this scene. |
| Python agents | Standalone legacy `GreeterAgent`/Orchestrator/shared-state prototype; two Greeter tests pass. Its names, energy defaults and check-in semantics have not been updated to this baseline. |
| Foundation gameplay integration | Planned: check-in, checklist task, Helper, peer-help action, rewards, energy and stoplight. |
| October 26 purple room, Program Manager and question banks | Proposed next-layer design; not implemented in the default Godot scene. |

The architecture's single shared state is a requirement for the integrated
game. The separate prototypes do not currently share one runtime state.

## Players characters and system roles

The game is single-player. The current playtest has one player avatar and no
interactive NPCs. Lady D's visible Mr. P and Program Manager are design inputs,
not implemented NPCs or a locked final cast. The Check-In Console is a station;
AI Helper is accessed through an interface; Scorekeeper is a display; the
Orchestrator is invisible. None of those responsibilities requires an extra
human player. A scripted classmate was suggested during review but not approved.

## Goal and player journey

Build a stylized single-player Godot game in which the player experiences the start of the
Pursuit journey: show up, do the work and help a teammate. Facilitator agents
run the experience. Getting hired is the wider story; this build covers Level 1.

The route is street → ground entrance/check-in desk → stairs or right ramp
→ ground-floor elevator forecourt → elevator transfer → second-floor landing
→ player's right turn → reception → direct double-door entry into the classroom.
Reception's open side passage also reaches the hallway and commons/open area;
that detour is not required to enter the classroom.

The approved opening is: explicit console check-in → one Show Up award and
celebratory popup → objective to go upstairs → elevator transfer → Mr. P
appears after the player exits the upper elevator and explains the activities.
His dialogue, task screen and the subsequent encounter remain Lady D's design
work to review with her incoming branch. Introducing an activity is not the
same event as completing it, and earns no additional star.

The brown-door room and reception's separate single-door room exist in the
model but their doors are locked in the current playtest. They are outside
the accessible route. The larger ground-floor side spaces are also locked.
Physical ground/second floors and game Level 1 are separate concepts; the
elevator transfers between physical floors, not between game levels.

## Current assets and next milestones

The combined building GLB and interactive reviewer are available in
`trials/building-review/`. The building was manually modeled in Blender from
photo references and firsthand layout corrections. Unseen areas and dimensions
remain estimates. The source GLB is unchanged; Godot reuses selected source
assemblies and builds different room shells at runtime. Its layout, check-in
desk and street scenery are not baked into the browser viewer's GLB. The Godot
playtest has generated collision and a CC0 animated test avatar. Agent
interactions and Foundation objectives still need integration.
The Godot scene also has a decorative exterior streetscape and bounded entrance
sidewalk; neighboring buildings are scenery rather than another playable area.
The [building review guide](Building-Review.md) covers launch, asset identity
and verification limits.

The retained standalone Python prototype includes Greeter/Orchestrator code from
`develop@9c38b3f`; its two existing Greeter tests pass. It is not yet wired into
the Godot playtest.

These implementation milestones remain queued until the partner handoff and
gameplay review above; they are not instructions to begin implementation now.

1. **Complete ground-floor check-in on the existing playable route.** The model
   import, movement, camera, collision, stairs/ramp, elevator transfer and
   reception/classroom route are implemented. The elevator uses an animated
   entry/fade/exit transition; its cab does not physically travel. The remaining
   gameplay increment is explicit desk check-in, verified completion and one
   Show Up award.
2. **Prove the Foundation loop.** Add the scripted Platform task, the AI Helper
   moment, a peer-help action, stars, energy and stoplight feedback. Demonstrate
   both a successful live Helper response and the scripted fallback.
3. **Polish the integrated slice.** Repeat the existing movement/collision
   checks after gameplay integration, then verify dialogue, rewards, readability,
   performance and restart behavior before expanding scope. Existing movement
   checks do not prove the unfinished gameplay loop.

## Five roles and hybrid dialogue

| Role | Responsibility and boundary |
| --- | --- |
| Orchestrator | Select one active interaction agent and verify handoffs before progression. A `done` flag alone is not proof. |
| Check-In Console | Handle explicit self-service ground-floor check-in and its completion condition. Legacy code calls this role Greeter. |
| Platform | Present the scripted Foundation task and verify task/peer-help actions. Live Platform dialogue is deferred. |
| AI Helper | Provide useful guidance through one live call at the demo's help moment, with scripted fallback. Its text cannot authorize rewards or progression. |
| Scorekeeper | Read shared state and display approved stars, energy, stoplight and progress. It cannot award rewards or change progress. |

Implementation ownership: Dennis's integration work covers Orchestrator,
Check-In Console, AI Helper and Scorekeeper. Lady D owns the Platform Agent;
agree its event/handoff interface and connect it without implementing a second
Platform Agent or duplicating its task-validation rules.

Five roles do not require five LLM calls. Check-In Console, Platform, coordination and
scoring stay scripted for this demo. The live Helper target is one bounded
request at the selected demo help moment, not five independent model calls.
Provider, timeout, repeated-request policy and the Godot/Python integration
boundary are unresolved; no live provider is currently connected.

### Next player interaction: ground-floor check-in

After entering the building, the player approaches the small ground-floor desk
at Godot coordinates `(0.62, 0.02, 0.40)`, before the stairs and ramp. The upstairs
reception remains a separate existing space. The desk is currently scenery;
the next implementation slice is an explicit
interaction prompt, scripted console welcome, and a **Check in as a Builder**
choice. A valid explicit check-in supplies completion evidence. The verified
state update records check-in, awards Show Up once and sets the classroom
objective. Asking for directions or closing
the conversation must leave that star unearned. Revisiting the desk must not
award it again. The existing Python Greeter currently treats `ask_directions`
as check-in; reconcile that behavior before connecting it to the game.

**Check-In Console** is the approved role name and self-service presentation.
The existing `GreeterAgent` class and current desk scenery are unchanged in
this documentation-only update; the role rename does not add a human greeter NPC.

The rest of the planned loop is classroom Platform task → optional AI Helper
guidance → verified task completion → peer-help action → three-star completion.
Dennis selected the existing checklist activity for the first Platform task:
identify **Show up / check in**, **Submit your project**, and **Help a teammate**
among the distracting busywork options. Submitting the correct set completes
this short Foundation task and earns Do the Work once. An incorrect set keeps
the task active and lets the player retry; AI Helper guidance is optional.
Selecting the peer-help checklist item does not complete the separate Be a
Teammate objective. That objective still needs an observable peer-help action.
This document describes intended gameplay; it does not implement dialogue,
rewards or a live provider.

## Later gameplay design inputs

Lady D's [presentation sources and feedback](Archive/2026-10-26/Source-Notes.md)
retain the detailed purple/lavender room, floating ghost/hat character,
laptop-style screen, Program Manager, branching questions, hidden challenges
and visual-reference ideas. They are design inputs for the incoming-work
review, not additional implemented features or alternatives to settled rules.

The approved upper-elevator introduction uses Mr. P. A Program Manager scene
and a final NPC cast have not been selected. The later question sequence needs
its authored content and completion rules before integration review; calendar
and reset behavior are not specified. The suggested multiple-provider friend
menu remains future design; the existing demo target is still one live Helper
request with scripted fallback. Live Helper guidance does not require a fully
AI-driven Platform.

Use the approved names, retry behavior and energy values above. Older source
wording is superseded. Neither a help offer nor provider text can complete an
unanswered task or award an unearned star. Lady D retains ownership of Platform
content and validation; agree the interface before connecting it.

## Gameplay rules

- **Show Up:** earn one star by completing check-in.
- **Do the Work:** earn one star by completing the short Foundation task, with
  or without Helper guidance. Clicking Use AI alone does not earn this star.
- **Be a Teammate:** earn one star by completing a peer-help action.
- Complete all three objectives to finish Level 1. An elevator-area star
  indicator is a proposed completion display, not an existing gameplay control
  or a transition to another playable level. Another level is outside this build.
- Start at 10 energy and deduct 1 per incorrect submission. Recovery, maximum
  energy, behavior at zero, stoplight thresholds and strength bonuses are
  future design decisions; the starting value and error cost are settled.
- Retain five strength choices: Great Communication, Tech Savvy, Coding
  Experience, AI Experience and Newbie + Curiosity. Defer outfits and a separate
  character-stat system.
- Discovering Use AI can reveal the hidden objective. Any bonus is separate
  from the three required stars and must not bypass their completion conditions.

## Handoffs and failure behavior to implement

Use one shared game state. The recommended integration design is: Check-In Console
validates check-in; Platform validates task and peer-help evidence; Orchestrator
verifies the requested outcome; one reward API applies each verified objective
award once; Scorekeeper displays the result. Publish completion evidence, its
reward and the objective transition together so a rejected event cannot leave
an earned-looking star. The exact API and evidence schema are not implemented.

Retain the existing `{ done, to, reason }` handoff concept and specify the session,
event/objective identifier, expected state and completion evidence around it.
Validate the recipient, allowed exit reason and actual completion evidence
before publishing a successful transition. `done: true` requests verification;
it does not grant progress. A Helper result returns to the suspended task,
whereas an objective-completion result can advance that objective. The current
linear Python handoff cannot express that distinction yet. Repeated events must
not award duplicate stars. Game code verifies actions; LLM output is guidance
rather than authoritative state.

If input or a handoff is missing, ambiguous or invalid, keep the current objective
and show the specific next action. Bound the Helper request and use scripted
guidance on timeout, provider error or unusable output. Bound automated provider
requests. Player-driven errors follow the first-demo rules: restate after the
first incorrect submission and offer stronger help after the second.
A provider failure must not penalize the player: offer offline guidance and
return to the task. The player must still satisfy its completion condition.
Keep API credentials outside the client and versioned files.

For presentation, keep one overview diagram and separate check-in and Mr. P
flows. Show the exact success condition, retry, help and return path in each;
see [Agent-Flow.md](Agent-Flow.md). Scorekeeper reads approved state and cannot
award rewards. “Every agent reads and writes” describes shared access in the
source notes, not unrestricted permission to change every field.

## Art and scope boundaries

Use Blender → GLB → Godot for the playable environment, and Three.js for review.
Retain the connected classroom and accepted building layout. Use original
stylized avatars, warm lighting, navy/white/cyan, wood, exposed ducts and red pipes
as the visual direction. Reference photographs stay outside the shared package;
the model's generated embedded materials stay with the GLB.

The first Godot gameplay demo focuses on the Foundation/Platform/Helper loop.
The historical Bug Blaster is not part of the working tree or first-demo scope.
Porting it, adding the keypad gate, extra levels, full avatar customization,
additional agent roles and fully live Platform dialogue are deferred. Photogrammetry experiments
and the discarded photo-textured room are not the current build path.

## Questions for Lady D after her gameplay branch is available

These questions are recorded here, not sent to Lady D. Dennis asked that
Mr. P's content and challenge decisions remain with her rather than being
invented during integration planning.

- What activity does the incoming branch actually provide, and what should
  the player learn from completing it? Provide a complete example run so we
  can review it against the current checklist-first baseline.
- What does Mr. P say after the upper-elevator exit, how does the player open
  and answer his activity, and where does that encounter take place?
- What are the complete prompt, choices or permitted actions, correct-answer
  rules and completion evidence? For the checklist, the recognition goal and
  three correct action labels are already recorded above.
- What wording and help content follow the approved first-error restatement
  and second-error stronger-help offer? What happens if help is declined or
  the player continues to struggle?
- Which existing teammate-help or other activity should provide the separate
  Be a Teammate action, and what observed result proves the player helped?
  The old prototype's single help choice is available for review, not already
  selected for integration.
- For the later question sequence, what are the follow-up paths, finite exit
  condition and meaning of a daily set? What content belongs in the first demo
  versus a later milestone?

## Future design work

These are missing design details, not competing rules for settled decisions.
They will be addressed in the next design discussion. Do not infer answers,
claim the full gameplay loop is ready, or reopen the approved decisions above.
The responsibilities below follow the existing division of work; they do not
record a new agreement by Lady D about specific content.

| Topic | Responsibility | Detail still to define |
| --- | --- | --- |
| First-demo encounter | Lady D for challenge design; Dennis for integration | Exact checklist options, Mr. P's upper-elevator-exit dialogue, input controls and feedback presentation. The checklist is the working first activity pending incoming-work review. |
| Later question milestone | Lady D for challenge design; Dennis for integration | Author questions, correct-answer rules, follow-up paths, help content and a completion condition; review these before deciding integration. Define what a day means and whether anything resets by calendar time. |
| Stronger-help presentation | Lady D for task feedback; Dennis for integration | What the second-error offer displays, what happens if help is declined, further-error behavior and counter reset rules. Do not substitute a five-attempt threshold; the first-error/second-error rule is settled. |
| Peer-help completion | Lady D for the Platform validation rule; Dennis for integration | The separate observable helping action, its evidence and replay behavior. No teammate NPC or multiplayer feature has been approved. |
| Helper service and transport | Dennis, with Lady D for encounter UI | Provider, timeout, duplicate/repeated-request handling, credentials boundary and Godot/Python connection for the existing single-live-request target with fallback. Multiple providers and a fifth friend remain later design inputs. |
| State and reward API | Dennis, coordinated with Lady D's Platform interface | Exact handoff/evidence schema and publication mechanism. Agent-Flow.md's atomic publication sequence is an engineering recommendation; verified outcomes and no unearned or duplicate stars are the gameplay requirement. |
| Energy recovery and feedback | Dennis and Lady D | Recovery, maximum, behavior at zero, stoplight thresholds and any strength or discovery bonus. Starting energy 10 and cost 1 per incorrect submission are settled; other action costs are not approved. |
| Characters and environment | Lady D for character/challenge direction; Dennis for environment/integration | Program Manager's interactions, Mr. P presentation and purple-room placement/entry. Preserve the accepted playable layout until a change is agreed. The final NPC cast is not fixed. |
| Ending resume and restart | Dennis for state handling, with Lady D for task/reset design | Ending presentation, replay, in-session resume and save/reset behavior across application restarts. All three verified objectives remain the Level 1 win condition. |

The earlier two-week estimates and Monday-pitch wording are historical planning
assumptions, not a confirmed deadline or proof of completion. This review updates
documentation only; implementation remains a separate task.

Update this plan when decisions change. Use the
[October 23 decision review](Archive/Document-Review-2026-10-23.md) and
[archive index](Archive/README.md) for provenance, rather than reviving an older
PRD as a competing active specification. Refresh the pitch after the implementation
claims are verified.
