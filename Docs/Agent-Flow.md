# Agent flow and completion

**Updated October 27, 2026 after the gameplay discussion.**
The [project plan](Project-Plan.md) is the single active PRD. Its
[approved decisions](Project-Plan.md#approved-first-demo-decisions) replace the
former checklist, three-star finish, stoplight and ground-floor check-in.
This document describes intended coordination and recommended engineering
safeguards. It does not implement the gameplay or claim an agreed final API.
Original diagrams and archived drafts preserve earlier designs, not current
runtime requirements.

## Shared state and ownership

One authoritative game state should record the physical location, current
stage, question progress, robot progress, energy, numeric score and event log.
Exact fields and transport still need agreement. There is no current gameplay
requirement for stars, a stoplight or a separate teammate objective. Legacy
Python fields do not determine the new schema.

| Role | Responsibility |
| --- | --- |
| Orchestrator | Invisible scripted coordinator: select the permitted interaction, verify results and choose the next allowed stage. |
| Check-In Console | Validate upstairs name entry/check-in confirmation and supply evidence. The Python prototype calls this role Greeter. |
| Platform / Mr. P | Live AI tutor plus authored question/challenge interaction. Lady D leads design; game-owned rules verify answers and challenge completion. |
| AI Helper / Dial-a-Friend | Provide task guidance or the zero-energy supportive recovery interaction; return to the unfinished task. |
| Scorekeeper | Display authoritative energy, numeric score and progress, without independently changing them. |

Five roles are responsibilities, not five players or five NPCs. The Program
Manager is part of the classroom introduction, not the Orchestrator. There is
no real-person calling service in the selected scope. Entry-puzzle and shooter
controllers supply game results to the coordinator; they do not imply new LLM
roles. Their precise module ownership remains to agree.

Keep physical location, stage, active interaction owner and suspended task
separate. An event saying “checked in” does not itself prove that the player
has moved into the classroom. An automatic classroom/portal transition is a
specific presentation action whose completion must be handled explicitly.

## Outer system turn

1. Accept a player action at the current stage and read authoritative state.
2. Route it to the permitted game controller or interaction owner.
3. Run its Sense → Decide → Act step, or await a bounded live AI result.
4. Validate the action/result against the expected stage and authored rules.
   For successful completion, publish the verified progress, applicable reward
   and next permitted stage together. For help, resume the unfinished task;
   apply energy recovery only for the defined recovery result.
5. Display feedback and wait for the next player action or explicit scene event.

This publication sequence is an engineering recommendation; the exact API is
not implemented. Reject unsupported completions without advancing the task.
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

Name validation, duplicate confirmations and interruption handling need an
explicit contract. A real roster, webcam, microphone or identity service is
not implied. Directions, merely arriving upstairs or closing the prompt do
not substitute for the selected name-entry/confirmation interaction. No Show
Up star is awarded. The ground-floor desk is existing scenery from the old
plan, not the new check-in location.

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
balance and ending controls remain to review.

## Helper detour and live AI boundary

Active question → request Dial-a-Friend → preserve the task/question and
progress → activate Helper → bounded live guidance or scripted fallback →
resume the same task → validate the player’s next answer normally.

At zero energy, distinguish a recovery request from ordinary task guidance.
The selected supportive friend interaction restores a full bar on its defined
completion. Temporarily restore to 10 and keep the attempt count. Recovery
trigger, fallback and cancel behavior still need design. At zero, declining
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

These are future acceptance cases, not existing executable coverage. Use
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

The current Python `Agent.step` performs one Sense → Decide → Act call.
`Orchestrator._verify` checks recipient, reason and the agent postcondition.
However, `_advance` follows a linear zone list and changes location without
Godot movement; it cannot express the new stage graph or Helper return.
Greeter treats `ask_directions` as check-in and awards a star before verification.
The base postcondition returns true unless overridden; rejection does not
roll back earlier mutations. Energy 8, stars and stoplight remain legacy
prototype data. These gaps must be reconciled before connecting it to the game.

Godot currently supplies building movement, camera and elevator transfer.
It has no entrance puzzle, elevator shooter gate, upstairs check-in, classroom
sequence, live Mr. P/Helper, authored question set, robot challenge or ending.
This documentation update changes none of that runtime code. The older web
shooter can be reviewed in Git history; it is not a game currently integrated
with the elevator.
