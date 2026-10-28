# Pursuit The Journey project plan

**Single active PRD · Updated October 27, 2026 · Team: Lady D and Dennis**

**Current phase:** the October 27 gameplay discussion replaces the earlier
checklist-and-three-star demo with a question-and-challenge journey. The route
and first challenge are selected. Temporary playtest settings and a sample
Mr. P interface now allow integration work without waiting for final content.
Lady D owns the real questions and completion rules. This is a design update,
not an implemented game loop.

Work from `develop`. Use this plan for scope and decisions,
[Agent-Flow.md](Agent-Flow.md) for the intended coordination contract and
[Building-Review.md](Building-Review.md) for the existing playable environment.
[Docs/README.md](README.md) indexes the working documents. Original material in
[Archive](Archive/README.md) is historical evidence, not another specification.
The latest discussion below takes precedence over older source wording.

## Approved first-demo decisions

The latest discussion explicitly changes earlier approvals. These decisions
are the current baseline; unresolved details are listed separately.

| Topic | Current decision |
| --- | --- |
| Title and player | **Pursuit: The Journey**, single-player. Use **player** in game-design descriptions. |
| First challenge | **Make an Agent:** assemble a broken robot by answering questions about what makes an agent. Represent the parts in 2D; breaking apart the player’s 3D model is not required. |
| Previous checklist | Retired from the first-demo scope. Recognizing check-in, submission and helping a teammate is no longer the selected activity. |
| Previous rewards and win condition | Remove the three required stars, Show Up / Do the Work / Be a Teammate, and the separate peer-help objective. Completion now follows the required questions and robot challenge. Numeric score uses the temporary settings below until playtesting informs final values. |
| Entrance | Arrange **Sense → Decide → Act**, then enter the revealed code to unlock the doorway. The first local implementation uses three step buttons with per-session digits, a hint, reset and unlimited retries without energy costs. |
| Elevator | Complete a point-and-shoot mini-game to unlock travel upstairs. It is a progression gate, not merely an optional arcade game. |
| Check-in | **Upstairs after elevator arrival**, at reception. The player supplies a name, then sees simulated photo/check-in confirmation. The former ground-floor check-in plan is superseded. |
| Classroom introduction | A short sequence shows classroom entry, the Program Manager announcing daily stand-up, crowd chatter, then the instruction to get to work. |
| Mr. P introduction | After the classroom sequence, the player sits and opens a laptop, transitioning into **Mr. P’s purple world**. Mr. P is encountered there, not at the elevator exit. |
| Purple world | A separate presented game space representing focused work with the platform, not a literal new room in the real Pursuit building. Use “purple world” or “portal,” not “mental room,” in player-facing language. |
| Mr. P | A floating, subtly animated ghost with hat and a slightly sinister, witty tutor persona. He is persistent and responsive, without making the interaction needlessly aggravating. Lady D leads his design. |
| Live AI | Mr. P is intended to be a **live AI-driven character**. Claude is the selected provider direction for him and Dial-a-Friend; model, credentials availability, backend and request budgets are not yet verified or defined. This supersedes the scripted-only Platform and single-live-Helper-request limit. |
| Question presentation | A large laptop-style screen is central, with multiple-choice answers and a visible Dial-a-Friend control. Witty, original agent-related questions should teach relevant course concepts. Correct feedback is green and incorrect feedback red; there is no separate stoplight system. |
| Correct answer | Validate it and advance immediately. Use the temporary reward schedule below during development. |
| First incorrect submission | Rephrase the current question and allow another attempt. |
| Second incorrect submission | Offer stronger help. Help is not forced and does not automatically complete the question. |
| Starting energy and error cost | Start at **10** and deduct **1 per incorrect submission**. Other penalties have not been selected. |
| Zero energy | Offer **Dial-a-Friend**; completing the supportive friend interaction restores a full energy bar and allows continued play. This recovery can be repeated. Temporarily restore to 10 and retain the question's attempt count. |
| Help declined | Do not force help. Mr. P may encourage the player; the unanswered task remains unfinished. At zero, temporarily pause answer submissions and keep recovery available. |
| First build scope | One robot challenge. The clone challenge and additional challenge rooms are future scope. |
| Ending | After the robot challenge, return to Mr. P’s questions. When the required set is complete, return to the classroom for congratulations, a short simulated assessment/wait and a fictional advance to L3, with celebratory presentation. No actual course grade or enrollment changes. |

The previous three-star finish, teammate task, stoplight, ground-floor check-in,
elevator-exit Mr. P appearance and checklist-first sequence are superseded.
Historical files and existing prototype code can still contain them; they are
not current requirements. The retry thresholds, starting energy and error cost
remain unchanged.

## Temporary development placeholders

Dennis approved these settings for development and playtesting. They are
**temporary, replaceable defaults**, not final balance decisions or evidence
that the runtime implements them. Keep them configurable and review them once
the interaction is playable. The established starting energy, incorrect-answer
cost and first/second-error behavior remain the baseline.

| Setting | Temporary behavior |
| --- | --- |
| Starting / maximum energy | 10 / 10. |
| Incorrect submitted answer | Deduct 1 energy once. |
| Correct answer | Add 1 energy, capped at 10. |
| Completed robot challenge | Add 3 energy, capped at 10. |
| Completed friend recovery at zero | Restore energy to 10; repeatable when zero is reached again. |
| Attempts | Count per question; reset on the next question. Energy recovery retains the count. |
| First / second wrong answer | Rephrase after the first; offer stronger help after the second. |
| Third and later wrong answers | Continue offering help and allowing retries while energy remains. No new escalation threshold. |
| Declining recovery at zero | Keep recovery available; pause answer submissions until recovery completes. |
| Score | 10 points per completed question and 30 for robot completion. Never reward the same completed question/challenge twice. |

### Sample Mr. P interface

Before connecting the real Mr. P, use a stub: a development component that
stands in for his implementation. It receives a sample question, the player's
selected answer and that question's attempt count. A sample answer key produces
feedback and a temporary result: `retry`, `question_complete` or
`challenge_complete`. The coordinator applies the applicable progress and
rewards once. These are placeholder result names, not a finalized transport or
production schema. They do not authorize free-form AI text to grant completion.

**Lady D remains responsible for Mr. P's actual prompts, choices, answer rules,
explanations, question count/order and completion rules.** Sample questions and
keys are disposable development fixtures; they must be labelled as samples and
must not become required final content. The exact field names, robot event
mapping and live interface can be refined when her implementation connects.
Unfinished content does not block building the surrounding game with this stub.

Use a temporary completion result to exercise the already selected ending:
finish Mr. P's required work, return to the classroom, show results being
assessed, then celebrate fictional advancement to L3. Sample completion tests
prove only the integration path, not the finished questions or learning outcome.

## Goal and player journey

Teach the player to recognize and apply basic agent concepts through playful
questions and a robot-assembly challenge. L1/L2 course topics can inform original
content; the selected first challenge is agent-related. Exact lesson sources
and answer keys need review. Do not claim course alignment or copy specific
platform questions without reviewing the actual material.

### Selected walkthrough

1. **Outside the building:** approach the entrance and press E. Select Sense,
   Decide, Act in that order, then Check order. Each step carries one digit;
   the solved sequence reveals their three-digit code. Enter that code and
   choose Unlock entrance, then return to the building and walk through.
   A hint gives the order; Reset order allows retries. Escape closes the panel
   without granting entry. Progress/code persist for the running session;
   a new game process relocks it and chooses new digits. No real building code
   or security service is used.
2. **Inside and up the ramp:** reach the elevator. Complete its shooter game
   before the elevator permits upstairs travel. The encounter’s controls,
   enemies, victory condition and retry rules need authoring.
3. **Upstairs reception:** enter a name. Show a simulated photo moment and
   checked-in confirmation. A real webcam, roster lookup, voice input or real
   identity verification is not approved by this description. The name’s role
   and validation remain to define.
4. **Classroom sequence:** show the player entering; the Program Manager calls
   daily stand-up; play brief crowd chatter; she tells everyone to get to work.
   Keep this sequence short. Exact name spelling, dialogue, likeness/voice
   assets and transition controls need confirmation; no recording is authorized
   by this plan.
5. **Laptop and purple world:** the player takes a seat and opens the laptop,
   transitioning to Mr. P’s world. He floats beside the central question screen;
   Dial-a-Friend is visible. No new physical room in the reference building is
   implied by this transition.
6. **Questions:** answer an authored set of witty, agent-related questions.
   Apply the approved retries and energy cost. Correct answers can restore
   energy and increase score using the temporary settings above. Three
   questions were suggested as a small target; exact count and sequence are
   still to be confirmed, not a ten-question daily requirement.
7. **Make an Agent:** at an authored point, unlock and transition to a distinct
   challenge room. Answer agent-concept questions to assemble the displayed
   broken robot. Parts begin beside the robot; this is not a scavenger hunt.
   The completed robot comes alive; walking/motion is a desired presentation
   detail, not yet implemented. Exact required parts and answer rules remain
   to author.
8. **Return and finish:** return to the purple world and finish any remaining
   required questions. Return to the classroom, congratulate the player and
   explain that this was the final challenge in a fictional completed cycle.
   Show a brief assessment/wait, then celebrate advancement to L3 with lights
   and a future-facing exit or vista. The earlier L2 ending suggestion was
   replaced by the final L3 narrative. Another playable course level is not
   part of this build.

Winning the robot challenge alone does not finish the game if required
questions remain. The ending requires validated completion of the authored
question path and the one robot challenge, following the preceding gates.
The exact question set and robot completion rule must exist before this can be
an executable acceptance test. The assessment is a story sequence, not a live
instructor-review service or a new wait for an external decision.

## First challenge and learning content

**Make an Agent** is the selected challenge. Show a disassembled 2D robot and
let validated answers assemble it piece by piece until it activates. The
player answers about agent concepts; the robot is the visual reward. Building
or deploying a real agent in an external coding environment has not been
selected as a requirement.

Author the questions and visual mappings together. The discussion suggested
reasoning/decision-making as the head and handoff as hands. Those are optional
visual metaphors, not technical definitions. A single agent does not need to
handoff to another agent. Distinguish its own observe/decide/act cycle from a
multi-agent coordinator’s routing. Define successful completion and bounded
support rather than teaching that an agent necessarily loops forever or until
it succeeds. Claims about course definitions of bot, skill and agent need the
actual course source before they become answer keys.

Original questions should be playful and relevant, with clear answer rules
and explanations. Exact prompts, choices, difficulty, question order, robot
parts and the number of required questions remain Lady D’s content design,
coordinated with Dennis for implementation. Reordering a flow diagram or using
charts/images may be useful formats; they are not additional required
challenges yet.

## Five roles and live AI

System responsibilities remain distinct from visible characters or human players.

| Role | Responsibility and boundary |
| --- | --- |
| Orchestrator | Invisible scripted coordinator: route interactions, verify completion evidence and choose permitted transitions. Mr. P is not the Orchestrator. |
| Check-In Console | Handle upstairs name entry and explicit check-in confirmation. Existing Python calls this role Greeter. |
| Platform / Mr. P | Live AI tutor/persona and authored activity owner. Lady D leads content and character behavior; validation and progression must follow agreed rules. |
| AI Helper / Dial-a-Friend | Provide guidance or supportive recovery dialogue, then return to the unfinished task. No real-person phone call is in the selected scope. |
| Scorekeeper | Display authoritative energy, numeric score and progress. Read-only display; no independent awards or separate stoplight. |

Dennis owns integration for Orchestrator, Check-In Console, Helper and
Scorekeeper. Lady D leads Mr. P/Platform. Confirm the robot-content and
implementation split before assigning files: the conversation discussed
splitting the purple world and robot challenge, without defining a technical
module boundary.

Mr. P can adapt his phrasing to the player, offer simpler guiding questions
and be gently theatrical. The proposed harsh-room/garden reactions and
player-tone classification are not approved mandatory mechanics. They must
not silently become penalties or alter correctness. Persistence and humor do
not permit an unbounded question chain that prevents the selected ending.

Claude API use is the selected direction; no key, model or working connection
is established by this discussion. A menu of Claude models was discussed,
not finalized. Multiple separate providers, a real human friend and actual
phone-number entry are future ideas. Keep credentials outside Godot client
assets and versioned files. Define bounded calls, timeouts and fallbacks for
both live Mr. P and Helper before implementation. Authored answer rules and
game-owned state remain the authority for correctness, score and progression;
provider prose alone is not completion evidence.

## Gameplay rules

- A valid correct answer advances immediately; do not require extra mistakes.
- Start with 10 energy. First incorrect submission: deduct 1 and rephrase.
  Second: deduct 1 and offer stronger help. These count actual submitted
  answers, not incidental UI clicks or provider failures.
- Correct answers and challenge wins can increase energy/score; amounts,
  maximum and cap behavior use the temporary settings above. Apply rewards once
  per verified completion; final balance awaits playtesting.
- At zero, a repeatable supportive Dial-a-Friend interaction restores a full
  bar. Its exact completion action and fallback must be specified. No automatic
  game-over, forced reset, negative energy or extra attempt charge is selected.
- Help is optional; declining it does not complete an answer. Temporarily pause
  submissions at zero while keeping recovery available.
- Temporarily count attempts per question, resetting on the next question.
  Recovery retains attempts; third/later errors continue to offer help/retries
  while energy remains. Final tuning follows playtesting.
- No three-star system, required teammate-help objective or stoplight.
  Green/red answer feedback and a possible low-energy blink are separate UI
  cues, not permission to restore that removed system.
- Help, provider failure, repeated UI events or an animation finishing cannot
  fabricate a correct answer or duplicate rewards.
- Finish after the required questions and one robot challenge, then show the
  narrative ending. Scores do not replace completion evidence.

## Implementation status

| Area | Verified existing state versus the selected design |
| --- | --- |
| Default Godot scene | Playable building plus the local entrance-puzzle increment, third-person avatar/camera, stairs/ramp, elevator transfer and the photo-based two-floor environment with reception, classroom, commons and both street frontages. The full agent gameplay loop is not integrated. |
| Ground-floor desk | Removed from the current environment; selected check-in remains upstairs. |
| Entry/elevator gates | Entrance ordering puzzle, code input and physical lock are implemented locally. Elevator shooter is not implemented; the current elevator still allows transfer. |
| Upstairs check-in/classroom | Reception and classroom exist; name entry, simulated photo and stand-up sequence are not connected. |
| Mr. P art | A private native Blender master and animated GLB are available in the isolated Godot character review. Idle, Welcome, Guide and paired eyelid morphs are asset motion, not live AI or authored questions. See [Character-Assets.md](Character-Assets.md). |
| Robot art | The UNIT 74 interpretation has a private native master, rigged GLB, seven registered transparent part layers and Idle/PowerOn/Assemble clips. The isolated review shows 3D modules and 2D overlays; question content and playable challenge logic remain separate work. |
| Agent integration | The disconnected legacy Python prototype was removed during cleanup. The planned Orchestrator and facilitator contracts are not implemented in the Godot playtest yet. |
| Live AI | No provider integration verified. |

Lady D’s documentation PR #11 was merged into `develop`; its unique assets are
under Docs and originals under Archive. Duplicates and unrelated research were
removed. It delivered no playable challenge or agent code. The old browser
walkthrough branch and merged documentation branch have been deleted; work
continues from `develop`. No unpublished branch or delivery date is assumed.

The old web game included a shooter, but its removal was authorized earlier.
Its tracked source remains in Git history at `305b179`; do not claim it is
currently playable or that the new elevator encounter is already implemented.
Review reuse before porting it. The canonical building GLB remains under
`trials/building-review/`; Blender, Godot and the browser viewer now share the
photo-based assembly. Godot reads gameplay anchors from the assembly manifest.
Physical floors, the game slice and curriculum L1/L2/L3 are different concepts.

The new October 27 reference photos have now been received and reviewed.
Dennis identified the reception entrance, far-end larger room, middle small
room, rightmost classroom door and hallway opening beside the chair in
IMG_4794. Use the
[photo-based layout correction plan](Building-Review.md#october-27-photo-based-layout-correction-plan)
for reference coverage and remaining estimation limits. Those confirmed door
destinations are implemented in the new assembly and supersede the earlier plan.
The internal approach to commons remains inferred; its blue/black passage follows
the photographs with a straight sightline; its length and diagonal bearing are estimates.
New photos do not by themselves establish exact dimensions. Further photography
or measurements may still be needed for unobserved details.

## Current assets and next milestones

1. **Develop in parallel with placeholders:** Dennis can build the game around
   the temporary settings and sample Mr. P interface. Lady D authors the real
   questions, answer/completion rules and content. Define entry-puzzle and
   shooter rules as those increments are built; do not wait for all content.
2. **Refine integration when connecting Mr. P:** replace sample content/results
   with Lady D's implementation, agree verified completion, shared state,
   repeat-event handling, live transport and fallbacks. Confirm module ownership
   before changing her implementation; do not duplicate her Platform logic.
3. **Build and verify in route order:** entrance gate, elevator gate, upstairs
   check-in/classroom, purple-world questions, robot challenge, return and ending.
   Use playable increments; preserve movement and layout outside approved changes.
4. **Review the complete run:** normal completion, wrong answers, declined help,
   zero-energy recovery, provider failures, repeated events and restart behavior.
   Existing movement checks do not prove these future gameplay features.

## Future design work

The selected route is defined. The details below are unresolved, not competing
versions of the route. Do not invent answers or treat brainstorm examples as
implemented requirements.

### Unresolved integration and player-state questions

- [ ] **Content:** exact question count/order, choices, answer keys, explanations,
  robot parts, challenge unlock point and return point. Review relevant course
  definitions before writing technical questions.
- [x] **Entry puzzle first increment:** Sense/Decide/Act ordering, session code,
  physical entrance lock, wrong-order/code rejection, hint, retry and close/reopen.
- [ ] **Entry puzzle player review:** playtest clarity and difficulty. The code
  is a gameplay gate, not production access control. F3 developer travel remains
  an explicit review bypass; normal 1/2/3 travel shortcuts are blocked until entry
  unlocks. No energy or score award is connected to this entrance increment.
- [ ] **Elevator shooter:** controls, victory condition, difficulty, retry/help
  path and whether either gate uses the same energy rules as Mr. P’s questions.
- [ ] **Check-in:** name validation, confirmation event, simulated photo sequence
  and interruption handling. No real roster or camera integration is assumed.
- [ ] **Energy and score review:** use the approved temporary 10 maximum,
  +1 correct answer, +3 robot completion, full recovery to 10 and 10/30 score
  values now. Review final balance after playtesting; this is not a start blocker.
- [ ] **Zero-energy interaction:** recovery dialogue completion trigger, scripted
  fallback and cancellation handling. Declining recovery temporarily pauses
  submissions at zero and leaves recovery available.
- [ ] **Attempt-rule review:** test the temporary per-question count, reset on
  next question, no recovery reset and continued help/retries after further
  errors. Change these defaults only through an explicit playtest decision.
- [ ] **Live Mr. P and Helper:** Claude model, available credentials/budget,
  request limits, timeouts, fallback content, persona examples and evaluation.
  Neither role may award completion through free-form output.
- [ ] **State and handoffs:** event/session IDs, expected stage, question/answer
  evidence, challenge result, one-time rewards and suspend/resume semantics.
  Start with the sample interface above; refine Godot/Python/backend transport
  and evidence when connecting Lady D's implementation, without duplicated
  validation logic. This does not require Dennis to author her question set.
- [ ] **Presentation:** exact Program Manager name/dialogue and permitted source
  assets, animation lengths/skipping, room transitions, robot activation and
  accessible feedback. Low-energy blinking and room objects moving are ideas,
  not mandatory mechanics yet.
- [ ] **Ending and persistence:** exact required set, score/energy presentation,
  fictional assessment duration, ending controls, replay and saved progress.
  L3 is a narrative destination, not an actual course assessment or new level.

### Future ideas, outside the selected first build

- Clone/reproduce-an-object challenge and further challenges.
- Questions on walls, chart inspection, flow-reordering puzzles, hidden
  mini-games, souvenirs and useful collectible rewards.
- Additional office arcade games or a living-office environment.
- Shrinking-room or garden reactions to repeated mistakes/player tone. No
  seven-error threshold, automatic transport or tone-based penalty is selected.
- Real human calls, multiple AI providers and an elaborate model menu.
- Additional playable levels, daily/calendar resets and real enrollment or
  instructor-assessment services.

Older strength choices and discovery bonuses are not required by this route;
review their purpose before bringing them into the slice. The former source
metrics and calendar estimates are not approved acceptance targets or deadlines.
Keep original drafts archived and update this plan when unresolved details are
agreed, rather than creating a second active PRD.
