# Pursuit The Journey project plan

**Single active PRD · Updated October 27, 2026 · Team: Lady D and Dennis**

**Current phase:** the October 27 gameplay discussion replaces the earlier
checklist-and-three-star demo with a question-and-challenge journey. The route
and first challenge are selected; exact content, rewards and integration still
need definition. This is a design update, not an implemented game loop.

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
| Previous rewards and win condition | Remove the three required stars, Show Up / Do the Work / Be a Teammate, and the separate peer-help objective. Completion now follows the required questions and robot challenge. A numeric score is desired; its calculation is unresolved. |
| Entrance | Solve a puzzle to obtain the building-entry code. The specific puzzle and code behavior still need design. |
| Elevator | Complete a point-and-shoot mini-game to unlock travel upstairs. It is a progression gate, not merely an optional arcade game. |
| Check-in | **Upstairs after elevator arrival**, at reception. The player supplies a name, then sees simulated photo/check-in confirmation. The former ground-floor check-in plan is superseded. |
| Classroom introduction | A short sequence shows classroom entry, the Program Manager announcing daily stand-up, crowd chatter, then the instruction to get to work. |
| Mr. P introduction | After the classroom sequence, the player sits and opens a laptop, transitioning into **Mr. P’s purple world**. Mr. P is encountered there, not at the elevator exit. |
| Purple world | A separate presented game space representing focused work with the platform, not a literal new room in the real Pursuit building. Use “purple world” or “portal,” not “mental room,” in player-facing language. |
| Mr. P | A floating, subtly animated ghost with hat and a slightly sinister, witty tutor persona. He is persistent and responsive, without making the interaction needlessly aggravating. Lady D leads his design. |
| Live AI | Mr. P is intended to be a **live AI-driven character**. Claude is the selected provider direction for him and Dial-a-Friend; model, credentials availability, backend and request budgets are not yet verified or defined. This supersedes the scripted-only Platform and single-live-Helper-request limit. |
| Question presentation | A large laptop-style screen is central, with multiple-choice answers and a visible Dial-a-Friend control. Witty, original agent-related questions should teach relevant course concepts. Correct feedback is green and incorrect feedback red; there is no separate stoplight system. |
| Correct answer | Validate it and advance immediately. It can earn energy/score under a reward schedule still to define. |
| First incorrect submission | Rephrase the current question and allow another attempt. |
| Second incorrect submission | Offer stronger help. Help is not forced and does not automatically complete the question. |
| Starting energy and error cost | Start at **10** and deduct **1 per incorrect submission**. Other penalties have not been selected. |
| Zero energy | Offer **Dial-a-Friend**; completing the supportive friend interaction restores a full energy bar and allows continued play. This recovery can be repeated. The numeric refill depends on the unresolved maximum; do not assume a new maximum or counter reset. |
| Help declined | Do not force help. Mr. P may encourage the player; the unanswered task remains unfinished. Later-error behavior still needs an exact rule. |
| First build scope | One robot challenge. The clone challenge and additional challenge rooms are future scope. |
| Ending | After the robot challenge, return to Mr. P’s questions. When the required set is complete, return to the classroom for congratulations, a short simulated assessment/wait and a fictional advance to L3, with celebratory presentation. No actual course grade or enrollment changes. |

The previous three-star finish, teammate task, stoplight, ground-floor check-in,
elevator-exit Mr. P appearance and checklist-first sequence are superseded.
Historical files and existing prototype code can still contain them; they are
not current requirements. The retry thresholds, starting energy and error cost
remain unchanged.

## Goal and player journey

Teach the player to recognize and apply basic agent concepts through playful
questions and a robot-assembly challenge. L1/L2 course topics can inform original
content; the selected first challenge is agent-related. Exact lesson sources
and answer keys need review. Do not claim course alignment or copy specific
platform questions without reviewing the actual material.

### Selected walkthrough

1. **Outside the building:** solve an entrance puzzle, receive its code and
   unlock the entrance. Puzzle type, code generation and stuck-player support
   are not yet defined.
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
   energy and increase score once the reward schedule is defined. Three
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
  maximum, cap behavior and replay protection need a written reward table.
- At zero, a repeatable supportive Dial-a-Friend interaction restores a full
  bar. Its exact completion action and fallback must be specified. No automatic
  game-over, forced reset, negative energy or extra attempt charge is selected.
- Help is optional; declining it does not complete an answer. The precise
  interaction available while at zero and after declining recovery remains
  unresolved.
- Refilling energy does not imply resetting attempt counters. Counter scope,
  reset events and feedback on third/later mistakes remain open.
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
| Default Godot scene | Playable building, third-person avatar/camera, stairs/ramp, elevator transfer and decorative streets. No integrated gameplay loop. |
| Existing ground-floor desk | Scenery from the previous plan. It is not the selected check-in location; moving/removing it is future implementation work. |
| Entry/elevator gates | Not implemented. The current elevator allows transfer without the selected shooter. |
| Upstairs check-in/classroom | Reception and classroom exist; name entry, simulated photo and stand-up sequence are not connected. |
| Mr. P and robot | Character HTML/diagrams are source assets, not a live Godot character, authored question bank or playable robot challenge. |
| Python prototype | Standalone legacy Greeter/Orchestrator/shared state, with energy 8, stars and stoplight. These are legacy behavior, not current rules. It is not connected to Godot. |
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
`trials/building-review/`; Godot assembles its current rooms at runtime. Dennis
still plans remaining building-reference photography and a later model update.
Physical floors, the game slice and curriculum L1/L2/L3 are different concepts.

## Current assets and next milestones

1. **Author the complete slice:** write the entrance puzzle, shooter win/retry
   rules, exact Mr. P question path and robot questions/parts. Confirm learning
   sources, energy/reward table and the final ending sequence.
2. **Agree the integration contract:** shared state, stage transitions, validated
   result/evidence, repeat-event handling, live AI transport and fallbacks.
   Confirm ownership before implementing Platform or its adapters.
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
- [ ] **Entry puzzle:** puzzle mechanics, code behavior, completion proof and
  help/retry/exit path if the player cannot solve it.
- [ ] **Elevator shooter:** controls, victory condition, difficulty, retry/help
  path and whether either gate uses the same energy rules as Mr. P’s questions.
- [ ] **Check-in:** name validation, confirmation event, simulated photo sequence
  and interruption handling. No real roster or camera integration is assumed.
- [ ] **Energy and score:** maximum, gains per correct answer/challenge, cap,
  exact full-bar recovery amount and replay rules. Starting 10 and incorrect
  cost 1 are settled.
- [ ] **Zero-energy interaction:** recovery dialogue completion trigger, scripted
  fallback, decline/cancel behavior and availability of retries at zero.
- [ ] **Attempts:** per-question or per-challenge counts, reset events and
  third/later-error feedback. Energy refill alone is not an agreed counter reset.
- [ ] **Live Mr. P and Helper:** Claude model, available credentials/budget,
  request limits, timeouts, fallback content, persona examples and evaluation.
  Neither role may award completion through free-form output.
- [ ] **State and handoffs:** event/session IDs, expected stage, question/answer
  evidence, challenge result, one-time rewards and suspend/resume semantics.
  Select Godot/Python/backend transport and prevent duplicated validation logic.
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
