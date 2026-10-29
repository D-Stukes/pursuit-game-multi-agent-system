# Agent flow and completion

**Updated October 29, 2026 for the shared session and sample course adapter.**
The [project plan](Project-Plan.md) is the single active PRD. Its
[approved decisions](Project-Plan.md#approved-first-demo-decisions) replace the
former checklist, three-star finish, stoplight and ground-floor check-in.
This document distinguishes the connected gate/arrival/sample foundation from real course
coordination. The later Mr. P/Helper interface is not a finalized API.
Original diagrams and archived drafts preserve earlier designs, not current
runtime requirements.

## Shared state and ownership

The connected local session records physical zone, current objective, active
and suspended interaction, verified gates, energy/score and event log. An
explicit developer sample also records question attempts/results and checkpoint
completion. Real Mr. P/Helper transport and robot gameplay still need integration.
There is no current gameplay
requirement for stars, a stoplight or a separate teammate objective. Legacy
Python fields do not determine the new schema.

| Role | Responsibility |
| --- | --- |
| Orchestrator | Invisible scripted coordinator: select the permitted interaction, verify results and choose the next allowed stage. |
| Check-In Console | Validate upstairs name entry/check-in confirmation and supply evidence. Greeter is a historical name from the removed Python prototype. |
| Platform / Mr. P | Live AI tutor plus authored question/challenge interaction. Lady D leads design; game-owned rules verify answers and challenge completion. |
| AI Helper / Dial-a-Friend | Lady D's Mr. P domain: provide task guidance or the zero-energy supportive recovery interaction; return to the unfinished task. |
| Scorekeeper | Display authoritative energy, numeric score and progress, without independently changing them. |

The Scorekeeper is the regular HUD, not another character or model loop.
`ProgressHUD.gd` renders energy/max, score and the intersection of completed and
required question/challenge IDs. `Main.gd` reads a copied snapshot when the
Orchestrator's shared revision changes; rendering cannot publish a game event.
Before a course is bound it shows Activities: not started, and temporary
developer work is labelled Sample activities. Puzzle/arrival progress continues
to use the existing objective; those gates do not award course activity counts.

Five roles are responsibilities, not five players or five NPCs. The Program
Manager is part of the classroom introduction, not the Orchestrator. There is
no separate social Helper implementation: Dial-a-Friend belongs to Lady D's
Mr. P work. The shared coordinator verifies recovery evidence only. There is
no real-person calling service in the selected scope. Entry-puzzle and shooter
controllers supply game results to the coordinator; they do not imply new LLM
roles. Lady D owns Mr. P, the robot challenge and Dial-a-Friend. The verified
completion handoff and robot part mapping still need agreement when her module
is connected.

The [approved NPC plan](Project-Plan.md#npc-cast-and-behavior-plan) uses scripted
hosts and background routines, one optional adaptive Builder and Lady D's Mr. P.
Movement and greetings do not require Claude. Ending a conversation resumes
that NPC's scripted routine; future public exchanges do not activate untouched
NPCs or run uncontrolled model conversations. The first Builder help loop is
connected: scripted greeting, explicit help choice, read-only observations,
bounded SDK/tool turn, validated reply and two-exchange memory. Reception
dialogue and contact-gated public chatter are scripted. The five humanoid social
roles are assigned alongside Lady D's Mr. P. Closed conversations resume local
collision-aware walking/activity; completed classroom presentation also contacts
the Manager. Other interactions, distance and floors pause these routines.
Course integration remains separate; social movement cannot publish rewards.

Keep physical location, stage, active interaction owner and suspended task
separate. An event saying “checked in” does not itself prove that the player
has moved into the classroom. An automatic classroom/portal transition is a
specific presentation action whose completion must be handled explicitly.

## Outer system turn

### Implemented session core

`SessionState.gd`, `SessionEvent.gd` and `GameOrchestrator.gd` provide the local
deterministic foundation. A session has an identity, objective stage, physical
zone, active/suspended interaction, earned gates, baseline course values and a
bounded event log. Read snapshots are deep copies. The connected event types
are `ENTRANCE_UNLOCKED`, `SHOOTER_WON`, `CHECK_IN_CONFIRMED`,
`CLASSROOM_INTRODUCED`, `COURSE_ANSWER_SUBMITTED` and
`COURSE_RECOVERY_COMPLETED`. Each requires the matching session, expected stage and
bound controller's real postcondition. Check-in requires the name, simulated
photo and explicit confirmation upstairs; classroom completion requires the
ordered entry/stand-up/crowd/get-to-work presentation. Arrival events also
require their interaction owner and cannot be awarded in review mode.
Exact event replays are idempotent; conflicting IDs, foreign sessions, premature
results and free-form `done`/Mr. P messages do not advance progress.

Review mode grants temporary inspection permission without earned gates or
changed NPC facts. Location changes do not complete objectives. Interaction
ownership prevents overlapping controllers; Settings can suspend and restore
the remaining owner. Course defaults are 10 energy and 0 score, with no gate
reward. Explicit sample question/recovery/checkpoint results use the adapter
below; the real robot scene is unchanged.

`verify_session.gd` checks these rules independently. `Main.gd`
binds the actual puzzle/shooter controllers to the coordinator, publishes their
verified signals and reads shared permissions for the physical entrance and
ascent. The HUD objective and NPC progress snapshots read the same source.
`verify_orchestrator.gd` checks the scene adapters, ownership and reset.
The upstairs Check-In Console and classroom controller now supply separately
verified arrival evidence. Lady D's Mr. P and robot activity remain separate;
the standalone ending consumes verified course completion after its interaction
closes.

### Intended full system turn

1. Accept a player action at the current stage and read authoritative state.
2. Route it to the permitted game controller or interaction owner.
3. Run its Sense → Decide → Act step, or await a bounded live AI result.
4. Validate the action/result against the expected stage and authored rules.
   For successful completion, publish the verified progress, applicable reward
   and next permitted stage together. For help, resume the unfinished task;
   apply energy recovery only for the defined recovery result.
5. Display feedback and wait for the next player action or explicit scene event.

Gate, arrival and sample-course events use the publication sequence above;
real Mr. P/Helper/robot results still need their adapters. Reject unsupported completions without
advancing the task.
Provider dialogue, a `done` flag or an animation alone cannot prove an answer
was correct. A presentation animation may satisfy its own transition event,
not a different puzzle or question postcondition.

One outer turn ends after processing one action/result and its feedback. The
same question may span many turns. One active interaction owner means one
player-facing conversation at a time, not five simultaneous LLM calls.
Orchestrator coordinates and Scorekeeper observes.

## Inner Sense Decide Act loop

**Sense** reads the action, stage and relevant state. **Decide** chooses an
allowed response: ask, rephrase, hint, wait, request help or submit evidence.
**Act** presents it and submits permitted changes for validation. Wait for new
input or a bounded provider result rather than running an automatic retry loop.

| Outcome | Result |
| --- | --- |
| Correct submitted answer | Verify the answer, apply its defined reward once and advance immediately. |
| First incorrect submission | Deduct 1 energy once, rephrase the question and retain the task. |
| Second incorrect submission | Deduct 1 once and offer stronger help; no forced call or automatic success. |
| Third/later incorrect submission | Temporarily continue offering help and allowing retries while energy remains; no new escalation threshold. |
| Player declines help | Do not force the detour or grant completion. Temporarily pause submissions at zero and keep recovery available. |
| Ordinary Helper result | Deliver guidance/fallback and resume the unfinished question. No automatic correct answer or reward. |
| Completed zero-energy recovery interaction | Temporarily restore to 10 and resume the unfinished task, retaining that question's attempt count. Recovery trigger/fallback details still need definition. |
| Missing/ambiguous input | Request the required input. Only a task’s defined incorrect submission incurs the error cost. |
| Provider failure | Use the defined scripted fallback; no player penalty or fabricated correctness. |
| Pause or close interaction | No fabricated progress. In-session resume, scene cancellation and cross-session persistence need exact rules. |

Starting energy is 10. The first two incorrect submissions produce 9 then 8
and the approved restatement/help offer, before any separate recovery reward.
Use the PRD's [temporary playtest settings](Project-Plan.md#temporary-development-placeholders):
maximum energy 10; +1 energy per correct answer; +3 for robot completion, both
capped at 10; score 10 per completed question and 30 for robot completion, with
no repeated completion rewards. Zero-energy recovery restores to 10 and can
recur. Count attempts per question, reset on the next question and retain the
count through recovery. These are approved temporary defaults for testing,
not final balance decisions or implemented behavior.

The teaching loop should have authored success conditions and supported
recovery/exit paths. Live Mr. P dialogue must not generate an endless required
question chain. A single agent’s observe/decide/act cycle is distinct from
multi-agent routing; handoff is not a required property of every single agent.

## Selected stage flow

Outside entrance puzzle → verified puzzle win/code → building entrance →
ramp/elevator → verified shooter win → upstairs elevator arrival → upstairs
check-in → classroom stand-up sequence → laptop → purple world/questions →
unlocked robot challenge room → verified robot completion → return to purple
world/remaining questions → return to classroom → narrative assessment and L3
celebration/ending.

The exact question count, challenge unlock point and return position need
content authoring. Three questions is a suggested small set, not a finalized
count. One robot challenge is in scope. The two early mini-games are required
route gates; their own failure/help rules still need definition. No gameplay
star system or teammate task is part of this flow.

### Check-in flow

After the elevator shooter and upstairs arrival, approach reception → supply
name → validate the defined check-in action → show simulated photo/confirmation
→ publish checked-in state once → play the classroom transition.

Name validation, a simulated avatar photo, explicit confirmation, duplicate
rejection and interruption handling are connected locally. A real roster,
webcam, microphone or identity service is
not implied. Directions, merely arriving upstairs or closing the prompt do
not substitute for the selected name-entry/confirmation interaction. No Show
Up star is awarded. The earlier ground-floor desk plan is superseded.

### Classroom and Mr. P flow

Classroom entry → Program Manager calls daily stand-up → short crowd chatter
→ instruction to get to work → seat/laptop → transition into purple world →
Mr. P presents the authored agent-related questions.

Mr. P is floating and subtly animated beside a central laptop-style screen.
He is witty, persistent and a little sinister, with supportive rephrasing when
the player struggles. His personality can adapt without changing validation
or inventing punitive mechanics. He does not first appear at the elevator.
The purple world is presented as a separate portal space, not a new literal
room in the reference building.

Submitted answer → game-owned validation → correct: apply the authored
energy/score reward and advance; incorrect: apply approved cost/retry behavior.
At the authored unlock point, transition to the robot challenge room. Validated
answers assemble the 2D robot from parts displayed beside it. Activate the
robot only after all required challenge evidence is verified; then return to
the question sequence. The exact parts, questions and completion predicate
must be authored before integration.

### Finish condition

Require validated completion of the selected question path and the one robot
challenge after the preceding route gates. Show the classroom return and
explain that this fictional cycle’s previous work is already complete. A
short simulated assessment leads to the selected L3 advancement celebration
and ending. It is not a real grade, enrollment change, instructor review or
another playable level. The robot challenge alone is not the end if required
questions remain. Score uses the temporary 10/30 completion values; final
balance remains subject to player review. The standalone ending offers Play
Again; confirmed Restart Run in Settings clears the session in the same engine
process. Preview Ending is developer-only and cannot award progress.

## Helper detour and live AI boundary

Active question → request Dial-a-Friend → preserve the task/question and
progress → activate Helper → bounded live guidance or scripted fallback →
resume the same task → validate the player’s next answer normally.

At zero energy, distinguish a recovery request from ordinary task guidance.
The selected supportive friend interaction restores a full bar on its defined
completion. Temporarily restore to 10 and keep the attempt count.
The sample fixture verifies a scripted message followed by confirmation, and
cancels unfinished recovery on close/travel. Real Helper content, fallback and
transport remain separate integration work. At zero, declining
recovery pauses submissions while leaving recovery available. Do not award an
energy refill on every ordinary help click unless a
future rule explicitly says so.

Claude is the selected provider direction for **both live Mr. P and Helper**.
The old scripted-only Platform and one-live-Helper-call limit are superseded.
This does not establish credentials, model IDs, a working service or unlimited
calls. Agree request budgets, timeout, repeat-request handling, transport,
fallbacks and persona examples before implementation. Model selection was
discussed but is not finalized. Real human calls and multiple providers remain
future ideas. Credentials must stay outside client assets and versioned files.

Mr. P’s live phrasing is separate from the authored validation rules. AI output
must not directly mutate rewards, invent correctness or choose unrestricted
stage transitions. If an answer needs semantic evaluation, define a bounded
validation contract and failure behavior; do not silently use conversational
agreement as proof.

## Handoff and capability boundaries

Retain the existing `{ done, to, reason }` concept only as a starting point.
`to: "orchestrator"` identifies the recipient; it does not select the next
interaction. `done: true` requests verification of a specific result, not a
generic advance. Formalize distinct results for a completed stage, ordinary
help, recovery, cancellation and presentation transitions.

Recommended evidence includes session/event ID, expected stage/question,
submitted action, validated result and any applicable challenge parts/reward.
Exact schema and API are open engineering decisions. Repeated delivery must
not duplicate score, energy gains, deductions or robot parts. A malformed
handoff is not automatically a wrong answer and must not charge the player.

For development before live Mr. P connects, use the
[sample interface](Project-Plan.md#sample-mr-p-interface): sample question,
selected answer and attempt count in; feedback plus `retry`,
`question_complete` or `challenge_complete` out, checked against sample keys.
These are replaceable fixtures/result names, not Lady D's final content or a
production schema. Lady D owns real questions, order and completion rules;
refine the interface with her implementation rather than blocking surrounding
game development on those details.

### Implemented sample-course contract

`CourseAdapter.gd` is a provisional authored-data validator and pure progress
reducer. Its replaceable package defines ordered activities, choices and sample
keys; it contains no live Mr. P behavior. The Orchestrator binds one adapter only
after verified check-in/classroom completion and purple-world arrival. Samples
require developer tools and cannot start from review-bypass progress.

Typed answer submissions carry the current activity ID, selected choice and
course revision. The coordinator also binds them to the current interaction,
stage, session and event ID. It validates the sample key, then publishes the new
course snapshot once. Wrong choices cost one and update attempts; malformed,
cancelled, stale or replayed submissions add no cost or reward. Every required
question and challenge checkpoint must verify before `ending_pending` is reached.
The sample challenge is an answer-shaped receipt fixture, not the robot game.

Recovery uses a separate identity and ordered started/presented/confirmed
evidence at zero. Cancellation invalidates that identity. A verified recovery
refills to the configured maximum without resetting attempts; ordinary hints
never refill energy. The temporary settings remain 10 maximum, +1/10 points per
question and +3/30 points per challenge. The shared snapshot is the authority;
presentation reads it instead of keeping another energy/score counter. These
local sample contracts do not finalize Lady D's transport or real content.

| Candidate capability | Boundary |
| --- | --- |
| `read_game_state` | Read authoritative state; no independent copy of progress. |
| `get_question` | Read the authored question/path. Not permission to generate unlimited required questions. |
| `check_answer` | Apply the agreed rule and return correctness/evidence; no independent reward publication. |
| `write_game_state` | Publish only validated changes, with replay handling and stage checks. |
| Reward operation, name to define | Apply approved numeric score/energy effects once. Historical `award_star` is not a current gameplay requirement. |

These are semantic capability descriptions, not existing endpoints or a
mandate to run an HTTP service. Dennis and Lady D must agree the boundary
without duplicating Platform validation in two places.

## Gameplay acceptance cases to implement

The entrance cases now have focused executable coverage in
`godot/developer/tests/verify_entrance.gd`; the remaining gameplay cases are
future criteria, not existing executable coverage. Use
temporary settings and labelled sample keys to test integration now; replace
the samples with Lady D's authored content for final gameplay acceptance.

| Case | Required observable result |
| --- | --- |
| Entrance gate | Puzzle completion permits entry with the defined code; no false completion. |
| Elevator gate | Verified shooter victory permits upstairs travel; arrival does not bypass the gate. |
| Upstairs check-in | Name-entry/confirmation records one check-in and starts the classroom sequence; no ground-floor task or star. |
| Classroom introduction | Stand-up/crowd/get-to-work sequence precedes laptop and purple-world transition. |
| Correct answer | Authored validation advances immediately and applies only the defined reward once. |
| First two wrong submissions | Energy 10 → 9 → 8; first rephrases, second offers stronger help; no question completion. |
| Help declined | No forced call or automatic success; retain the unfinished question. |
| Zero-energy recovery | Temporarily restore to 10 without resetting attempts; repeatable. Declining keeps recovery available and pauses submissions. |
| Live provider failure | Bounded fallback for Mr. P/Helper, no player penalty or false success; usable return to task. |
| Robot completion | Only validated required answers assemble/activate the robot; return to remaining questions. |
| End | Required question path plus robot challenge permits the classroom/L3 story ending; no three-star condition. |
| Invalid or repeated result | No unsupported transition or duplicate reward/cost/part. |
| Feedback display | Scorekeeper displays approved state without its own mutations or stoplight system. |

Maximum energy, reward amounts, attempt resets and zero-energy decline/retry
use the approved temporary settings above. Test them explicitly, then review
balance during playtesting. Persistence, authored recovery content and the
final live-interface details remain unresolved.

## Presentation layers and implementation limits

Use one overview for Player → Orchestrator → Active Interaction → Shared State
→ Scorekeeper → Player. Separate the route/check-in, Mr. P and recovery details
so success, retries, support and return paths are clear. Existing HTML/PNG
sources are historical presentations and have not been redrawn to match this
update; they are not executable coordination logic.

The disconnected Python agent prototype was removed during code cleanup. Its
linear zone advancement, energy 8, stars and stoplight did not implement this
gameplay specification. Git history retains that experiment. The replacement
Godot Orchestrator now connects the two game gates, Check-In Console and
classroom introduction, plus the explicit developer sample course. Live Mr. P/Helper and their remaining contracts are
future integration work.

Godot currently supplies building movement/camera, a four-level entrance
pipe/code puzzle with a session-only physical lock, and a three-wave spaceship
shooter that gates elevator ascent. Approach and face the keypad mounted left
of the entrance door, then press E to open the pipe puzzle. All four circuits
must pass before Welcome to Pursuit and the code are revealed; all 18 drones must be cleared before
the elevator unlocks. The computer portal enters the staged purple room.
Check-in requires the name, simulated avatar photo and explicit confirmation.
The classroom controller records actual entry and each timed stand-up/crowd/
get-to-work beat; Settings pauses it and cancelled travel leaves it incomplete.
These local results are verified by the shared Orchestrator. The objective
advances through entrance, elevator, verified check-in and the classroom
introduction to Mr. P pending. The explicit sample track can then publish
`course_active` and `ending_pending`; it does not implement Lady D's real course.
Once the completed course interaction closes, the standalone ending verifies
its ordered classroom results/assessment/L3 presentation before recording the
presentation receipt. Preview requires no course completion, preserves progress
and restores the originating position/view. Reaching the upper
floor is a location update, not proof of check-in. The art-review computer portal
remains accessible at its physical devices and cannot complete course work.
The event-driven social coordinator connects one Builder companion and two
scripted reception characters. Only a player-selected Builder help choice can
invoke the bounded Claude loop. It reads the objective, current pipe/shooter
observation, approved hint and its own two-exchange memory. Local help works
without a key. Reception greetings/topics and the four-line public exchange
are authored; chatter requires both reception characters to have met the player
and a later entry/cooldown. Replies cannot change course/puzzle results. Actual
Builder access was verified in a bounded Windows/Godot live Haiku 5.5 test on
October 28. Local preview, mock SDK checks and the live sample remain separate
evidence; broader reply quality, other models/machines and live Mr. P/Helper
are unverified.
See [NPC agents](NPC-Agents.md) for setup, contract and verification limits.
Live Mr. P/Helper, authored questions,
robot challenge remain Lady D's separate work. The classroom/L3 story ending,
developer preview and session-only replay are implemented around the existing
verified completion boundary. The older web shooter is
historical source; the current Godot shooter is a separate local implementation.
