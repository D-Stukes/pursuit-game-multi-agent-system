# Agent flow and completion

This records selected interaction behavior and a recommended integration
design for Godot, updated
October 26, 2026. It expands the presentation's loop explanation and addresses
the supplied feedback about check-in, Mr. P and verified exits. The
[project plan](Project-Plan.md) owns scope and decisions; the
[original October 26 sources](Archive/2026-10-26/Source-Notes.md) preserve
proposals that still need agreement. No game behavior was changed by this document.
The gameplay baseline comes from the plan. The state-publication sequence
below is an engineering recommendation for enforcing verified, earned rewards,
not a claim that its API design is approved or implemented. The final section
states what the existing code actually does. The
[approved first-demo decisions](Project-Plan.md#approved-first-demo-decisions)
own the current names, activity, retry rule and energy values. Missing design
details are listed separately under [future design work](Project-Plan.md#future-design-work).
Historical source wording does not override those decisions.

Lady D's October 27 PRD and charts have been received and reconciled here and
in the plan. They contain no playable challenge or agent integration. A complete
authored example activity and the final integration interface are still needed;
do not treat the documentation handoff as an implemented gameplay loop.
The [archived source disposition](Archive/2026-10-27/README.md) explains how
the original draft maps to the approved rules.

## Shared state and ownership

One shared game state records the player's zone, energy, stoplight, stars and
event log. Agents read this state before deciding what to do. They submit
changes through their permitted actions; sharing a state does not give every
role authority to award rewards or advance objectives.

| Role | Responsibility |
| --- | --- |
| Orchestrator | Activate one interaction agent, verify its handoff and choose the next allowed step. |
| Check-In Console | Validate explicit self-service check-in and request the Show Up award once. Legacy Python code calls this role Greeter. |
| Platform / Mr. P | Validate the authored task and peer-help actions, own retry rules and supply completion evidence. Lady D owns this implementation. |
| AI Helper / proposed Dial-a-Friend | Supply guidance and return control to the suspended task. It cannot mark answers correct or award stars. |
| Scorekeeper | Read approved state and display stars, energy and stoplight. It does not mutate scores. |

The proposed visible Program Manager can introduce class and direct the player
to Mr. P. It is distinct from the invisible Orchestrator; its detailed scope
is future design work. Peer and Program Manager feedback cannot bypass task verification.
This is a single-player game: system roles are not players or a count of
visible NPCs. A scripted teammate NPC has not been approved.

The existing Python state also includes credits and maximum energy. Question
IDs, task status, attempts, current day, completed question set, suspended task
and event/session evidence are proposed integration data, not existing fields.
Avoid a separate UI score or provider-owned progress record that can disagree
with the authoritative state.

Keep physical location and task progression separate. `zone` represents where
the player is; completing check-in sets a classroom objective but does not
teleport the player or claim that they have arrived there. Task completion,
the active interaction owner and a suspended Helper task need their own state.
The current prototype's linear zone list is not that integrated location model.

## Outer system turn

1. Accept a player action and read the current state. If no interaction is
   active, wait for a valid interaction trigger; movement alone earns no reward.
2. Orchestrator routes it to the active interaction agent for this objective.
3. That agent runs one Sense → Decide → Act step and supplies its permitted
   result, including completion evidence when claiming success.
4. Orchestrator checks the handoff recipient, allowed reason and evidence
   against that role's postcondition. For verified objective completion,
   publish completion, its single reward and the objective transition together.
   For a verified Helper result, resume the suspended task without a reward.
   On rejection, keep the objective and its unearned reward unchanged;
   diagnostic logging is allowed.
5. Scorekeeper displays that verified state; the player sees feedback and can act again.

The recommended reward API publishes verified completion and its award
together. Agents and UI widgets must not grant unearned rewards. The exact
API remains engineering design work; the current Python prototype mutates
state earlier and does not implement this recommendation.

One outer turn ends after its action and feedback. It does not require the
objective to be complete. The next player input starts another turn, often
with the same active agent. “One agent active” means one interaction owner at
a time: Check-In Console, Platform or temporarily Helper. Orchestrator is the coordinator
and Scorekeeper is a read-only observer, not additional concurrent interaction
owners. Five architecture roles therefore do not mean five simultaneous agents.
The repeated task loop spans these outer turns; it is not a blocking inner
`while` loop that runs without new input. The chart's moving ball pausing for
two illustrated agent cycles does not specify the runtime scheduler.

## Inner Sense Decide Act loop

**Sense** reads the player's input and relevant state: location, energy,
progress and current task. **Decide** chooses an allowed move such as welcome,
wait, ask, re-ask, hint or request completion. **Act** performs an allowed
action and submits its state change for validation; authoritative completion
and rewards follow the publication rule above. The same task repeats on later
input until a verified outcome or an explicit support/pause transition occurs.
Wait for input or a bounded
provider result rather than repeatedly polling or calling an LLM.

| Outcome | What happens next | Progress or reward |
| --- | --- | --- |
| Verified objective-completion evidence | Publish the objective's completion, single reward and next objective together. | Award the defined objective once. |
| Verified Helper result | Resume the suspended Platform task. | No objective completion or star. |
| First incorrect submission | Restate the current question/task and allow another attempt. | No completion or star; deduct 1 energy. |
| Second incorrect submission | Offer stronger help; do not force a live request or advance the task. | No completion or star; deduct 1 energy for the incorrect submission. |
| Missing or ambiguous input | Keep the same objective and explain the required input. Classification as an incorrect submission must be specified in the task's input rules. | No completion or star; do not invent an additional cost. |
| Player accepts or independently requests help | Pause question handling, route to Helper, then resume that question with its progress retained. | Help alone earns no task star. No help-action energy cost has been approved. |
| Helper timeout/error | Return scripted guidance within the request budget and resume. | No provider-failure penalty or automatic success. |
| Player closes the interaction or pauses within the session | Preserve the task in that session and show how to resume. Persistence across application restarts is unresolved. | No completion. |

Success ends an objective. A graceful fallback ends or suspends an attempt
and offers another supported path; it does not prove the objective succeeded.
The first-error restatement and second-error stronger-help offer are the
approved rule; they replace the older retry proposals. A correct answer
advances immediately. Start at 10 energy and deduct 1 per incorrect
submission. Recovery, maximum energy, behavior at zero, further-error feedback
and counter resets are future design details, not alternate current rules.
Counts used in a presentation animation do not specify retry behavior.

For an objective agent, `done: false` means keep the objective active and await
input; it does not mean rerun automatically. `done: true` requests verification
of that agent's specific result. Define and validate an explicit postcondition
for each role: objective completion for Check-In Console/Platform, guidance delivery or
fallback for Helper. A permitted Helper result returns control without completing
the Platform objective. A completed outer turn alone needs no success handoff.

## Handoff and capability boundaries

The existing envelope `{ done, to, reason }` names the handoff recipient, not
the next interaction agent. A result from Check-In Console, Platform or Helper
goes to `to: "orchestrator"`. The coordinator chooses the next owner after
verification. A Check-In Console result addressed directly to Platform must
not bypass that check. Use `checked_in` as the existing prototype's check-in
reason; formal identifiers for other results remain interface design work.

Separate an incorrect submitted answer from an invalid handoff. A validated
incorrect answer applies the approved one-point energy cost once. A malformed,
misaddressed or unsupported completion claim is rejected without minting a
star or inventing a player-error penalty. Duplicate delivery of the same event
must not duplicate an award or energy deduction; exact event IDs and replay
handling still need implementation design.

Lady D's tool names below are useful capability descriptions, not existing
endpoints or a decision to introduce an HTTP service or LLM coordinator. Core
coordination and validation remain scripted for the current demo.

| Capability | Intended result and permission |
| --- | --- |
| `read_game_state` | Read the authoritative state for the active interaction; no mutation. |
| `get_question` | Read authored activity content. The first demo still uses the checklist; a per-level/daily bank is later design work. |
| `check_answer` | Evaluate a submitted answer against the authored rule and return correctness, feedback and evidence; it does not itself grant a star. |
| `write_game_state` | Publish only validated changes through the shared-state boundary, including objective progress, error counts and energy. |
| `award_star` | Apply one earned objective award after verification, with duplicate-event protection. Helper and Scorekeeper have no award permission. |

The source draft's endpoint paths and Orchestrator prompt are examples, not
implemented services or executable requirements. Choose the payload schema,
transport and update mechanism together with the Platform owner before coding.
A UI refresh or feedback message cannot substitute for the recorded evidence.

## Check-in flow

Approach the ground-floor desk → open the prompt → explicitly select
**Check in as a Builder** → Check-In Console validates the explicit action and supplies
its evidence with `{ done: true, to: "orchestrator", reason: "checked_in" }`
→ Orchestrator verifies it → record check-in, award Show Up once and set the
classroom objective in the same verified state update → display a celebratory
Show Up popup → the player travels upstairs. After the upper-elevator exit,
Mr. P appears and explains the activities. Lady D owns the introduction's
dialogue and encounter design; it is not an Orchestrator character appearance.

Idle input, asking for directions, closing the prompt and invalid input keep
check-in incomplete. Revisiting the desk shows existing progress without a
second award. Completion evidence must identify the explicit check-in action
and session. After publication, that session has one check-in record and one
Show Up award. A UI message, preexisting star flag or `done` alone is insufficient
evidence for a new check-in. Exact event field names remain to be specified.

The Python prototype currently accepts `ask_directions` as check-in and verifies
only the Show Up flag. Its zone is still `reception`; the Godot desk is on the
ground floor. Reconcile those semantics before connecting the systems.

## Mr. P flow

For the approved first demo: show the Foundation checklist → accept the selected
set → validate against the authored correct set → if wrong, deduct 1 energy
and retain the task; restate on the first error and offer stronger help on the
second → if correct, submit the task/answer evidence immediately
with a completion handoff → Orchestrator verifies it → publish task completion,
one Do the Work award and the peer-help objective together → display the result.
Selecting “Help a teammate” in this checklist does not itself earn Be a Teammate.

Be a Teammate needs its own observed action and validated evidence. Completing
Level 1 requires all three verified objective records and their single awards;
finishing a question, using Helper or exhausting a zone list cannot substitute
for that condition. The concrete peer-help action is still a blocking design
decision for the full loop, as listed in the plan.

Lady D's proposed next layer adds an introduction by the Program Manager,
entry into a purple Mr. P room, a laptop question screen and a finite authored
daily set. These remain later design inputs. What a day means and any calendar
or reset behavior have not been selected. The later question milestone needs
authored questions, answer rules, follow-up paths, help behavior and a
completion condition before integration is reviewed. Each proposed question
needs an ID, accepted answer/validation rule and next
question or branch. A correct answer receives acknowledgment and advances;
a wrong answer receives a rephrased question, hint or supported retry. Branches
must have defined exits so follow-up questions cannot create an endless chain.
Complete the day only when all required questions on the applicable path have
verified completion. How that maps to the demo's Do the Work star is pending.

The checklist remains the first-demo activity until an agreed scope change;
the later sequence is not an unresolved alternative for that demo. A bounded
question set and a help offer are separate guarantees: a hint alone cannot
guarantee that every player finishes. The later activity needs a supported
recovery or exit design without awarding unearned success.

## Helper detour and live AI boundary

Question active → request Dial-a-Friend → preserve question, attempt count and
completed answers → Orchestrator activates Helper → receive bounded live
guidance or scripted fallback → Orchestrator returns to Mr. P at that question
→ player submits an answer → Platform validates it normally.

Helper completion means guidance was delivered or fallback was shown. It
does not satisfy the Platform's postcondition and must not advance the player
to the next zone. If the prototype's `done` field is reused, it describes the
Helper's own result and must be interpreted as a return to the suspended task,
not as a generic instruction to call `_advance`. The existing handoff payload
has no explicit return type; define that distinction before integration.
This is a temporary detour, not a mandatory linear stage between every
Platform task and Scorekeeper update.

Keep authored question rules and rewards deterministic for the current demo.
A live Helper can answer without making Mr. P AI-driven. The selected demo target
is one bounded live request at its help moment, with scripted fallback; provider,
timeout and repeat-request policy are undecided. Multiple provider choices and
dynamic Mr. P dialogue are proposed expansions. The Godot/Python connection
is also undecided. Provider text must not write authoritative state, choose
rewards or declare success.

## Gameplay acceptance cases to implement

These are future gameplay acceptance criteria, reconciled from Lady D's eval
card. They are not claims that the existing movement or Greeter tests already
cover the integrated game. Author executable tests when integration is approved.

| Case | Required observable result |
| --- | --- |
| Explicit check-in | Record the explicit action and award Show Up once. Directions, idle input and closing the prompt do not complete check-in. |
| Correct first submission | Verify the authored answer, award Do the Work once and advance immediately without requiring wrong attempts. |
| First then second incorrect submission | Starting at 10, the first incorrect submission leaves 9 energy and restates the task; the second leaves 8 and offers stronger help. Neither completes the task or awards a star. |
| Helper completion or provider failure | Deliver guidance or scripted fallback, then return to the unfinished task without a task star or a provider-failure energy penalty. |
| False or misaddressed completion | Reject missing/incorrect evidence or a non-coordinator recipient; no unearned star or objective advance. |
| Replayed result | A repeated event does not award another star or deduct energy again. |
| Feedback display | Scorekeeper reads approved state and cannot correct or change it by writing its own rewards. |

Numeric behavior at zero, later-error help behavior and cross-session resets
are deliberately outside these cases until their recorded design questions
are resolved. An instructor-review proposal is not an automatic completion
path and cannot satisfy the three-star Level 1 win condition without evidence.

## Presentation layers and implementation limits

For Dennis's Orchestrator work, the integration still needs physical interaction
triggers, an active-objective model, the shared-state/handoff schema, verified
completion handling, duplicate-event protection and the Helper return/fallback
path. Lady D supplies the Platform's task rules and completion evidence through
the agreed interface. The coordinator routes those results; it must not invent
or duplicate her task-validation rules. Review the authored activity and any
subsequent implementation before building the adapter or defining the final
complete playthrough.

Use the overview to show Player → Orchestrator → Active Agent → Shared State
→ Scorekeeper → Player. Put check-in and Mr. P/Helper detail on separate flows,
each showing its verified success exit, retry and help-return path. This
addresses the supplied LaNice/Lanise feedback without overcrowding the overview.

The current Python `Agent.step` implements one Sense → Decide → Act call;
`Orchestrator._verify` checks recipient, allowed reason and the agent's
postcondition. `GameState.award_star` avoids duplicate awards for the lifetime
of that state object; this is not cross-session persistence. However,
`Orchestrator._advance` follows a linear zone list; a suspended-task Helper
return and the richer completion evidence above are not implemented. `_advance`
also changes `state.zone` without Godot movement; it must not be treated as
proof of physical arrival. Its final-zone log is not proof that all three
gameplay objectives are complete.
The Greeter awards its star during `act` before `_verify` runs. Rejection does
not roll back prior mutations, and the base `Agent.postcondition` returns true
unless overridden. Those prototype behaviors do not meet the integration
contract above and must be reconciled before gameplay rewards are connected.

The Godot default scene currently implements the building, avatar, movement,
camera and elevator playtest. The desk is scenery. Python agent integration,
check-in interaction, Mr. P, live Helper, question banks and the full Foundation
loop remain unfinished. Neither the HTML diagram nor this contract proves
those features run in Godot.
