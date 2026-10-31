# Pursuit The Journey project plan

**Single active PRD · Updated October 29, 2026 · Team: Lady D and Dennis**

**Current phase:** the October 27 gameplay discussion replaces the earlier
checklist-and-three-star demo with a question-and-challenge journey. The route
and first challenge are selected. Temporary playtest settings and a sample
Mr. P interface now allow integration work without waiting for final content.
Lady D owns the real questions and completion rules. The shared session and
scripted Orchestrator now connect the entrance/elevator gates, upstairs check-in
and the Program Manager classroom introduction. An explicit developer-only
sample course now exercises question, challenge-receipt and recovery progress.
Lady D's live course content, the playable robot challenge and the ending
presentation remain separate work; this is not an implemented full game loop.

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
| Entrance | Approach the panel beside the closed doors. Complete one verified pipe circuit to reveal a four-digit session code, then enter it on the number pad. Leading zeros, clear, backspace and wrong-code feedback are supported. Unlock awards one reserve +1 energy pellet without overfilling energy. Three remaining boards are optional, have distinct palettes and award no extra pellets. Hints, resets and retries cost no energy. |
| Elevator | Complete a point-and-shoot mini-game to unlock travel upstairs. It is a progression gate, not merely an optional arcade game. |
| Check-in | **Upstairs after elevator arrival**, at reception. The player supplies a name, then sees simulated photo/check-in confirmation. The former ground-floor check-in plan is superseded. |
| Classroom introduction | A short sequence shows classroom entry, the Program Manager announcing daily stand-up, crowd chatter, then the instruction to get to work. |
| Mr. P introduction | After the classroom sequence, the player uses a laptop, transitioning into **Mr. P’s purple world**. The current playtest uses E and a fade; a seated animation remains a presentation decision. Mr. P is encountered there, not at the elevator exit. |
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
**temporary, replaceable defaults**, not final balance decisions. The sample
adapter implements these rules; final content and balance still need review.
Keep the settings configurable. The established starting energy, incorrect-answer
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

The current fixture lives in `godot/developer/course/sample-course.json`, with
three sample questions and one answer-shaped challenge checkpoint. That count
and checkpoint do not define Lady D's final lesson or implement the robot game.
After verified check-in/classroom completion, enter the purple world and use
**F3 -> Sample course (temporary)**. Review bypass does not grant access or
completion. The shared Orchestrator owns energy, attempts, score and completion;
the sample panel reads it. Escape, Settings and developer travel preserve course
progress and cancel any unfinished recovery. A new world starts fresh.

At zero the fixture presents a supportive scripted message, then requires an
explicit confirmation before refilling energy. Declining or closing leaves
recovery available and the task unanswered. No live Helper or model call is
used. A full required sample path publishes `ending_pending`; it does not show
the fictional assessment/L3 ending or award real course advancement.

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

1. **Outside the building:** approach the keypad left of the closed entrance
   doors. The puzzle opens automatically; acknowledge the short guide. Rotate pipes
   with click/Enter; Tab or arrows selects a tile. Connect the left IN terminal
   to the right OUT terminal, then choose Test circuit. Loose pipes may remain
   disconnected. The first verified board reveals a four-digit session code.
   Enter it on the number pad and choose Unlock entrance. The doors open with a
   quiet chime and brief fragments, or static confirmation with reduced motion.
   Three optional boards grow to 5×5 and use distinct palettes. Reopen them from
   Pause → Help & objective. Closing preserves the code, board and unlock.
   One reserve pellet is awarded per real unlock; use it from Help when course
   energy is below its maximum. Developer bypass and bonus replays earn nothing.
   A new run resets the puzzle and code. No real building code/service is used.
2. **Inside and up the ramp:** reach the elevator. Complete its shooter game
   before the elevator permits upstairs travel. E at the lower cab opens the
   spaceship shooter; Launch flight starts it. WASD/arrows move, holding Space
   shoots, P pauses and Esc closes while retaining the run. Clear three waves
   (5, 6 and 7 drones), then choose Ride upstairs. Three shields and unlimited
   full-run retries are temporary arcade settings. A win unlocks this session's
   later rides; descent is free. It does not use Mr. P's energy or score rules.
3. **Upstairs reception:** enter a name. Show a simulated photo moment and
   checked-in confirmation. A real webcam, roster lookup, voice input or real
   identity verification is not approved by this description. The implemented
   session display name is trimmed, must contain 1-32 characters and rejects
   control characters. It is not matched against a real roster.
4. **Classroom sequence:** show the player entering; the Program Manager calls
   daily stand-up; play brief crowd chatter; she tells everyone to get to work.
   The implemented sequence uses a generic character, scripted captions,
   synthetic crowd sound and pause/cancel handling. Final name, likeness/voice,
   and dialogue remain presentation decisions; no recording is authorized by
   this plan. A Skip introduction button / Space is available after entry.
5. **Laptop and purple world:** the player uses a laptop with E and a fade,
   transitioning to Mr. P’s world. Chair-based sit/stand animations use deliberate
   C input. The Mr. P visual floats beside the central question screen;
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
| Check-In Console | Handle upstairs name entry, a simulated avatar photo and explicit check-in confirmation. The removed Python prototype's Greeter name is historical only. |
| Platform / Mr. P | Live AI tutor/persona and authored activity owner. Lady D leads content and character behavior; validation and progression must follow agreed rules. |
| AI Helper / Dial-a-Friend | Part of Lady D's Mr. P domain: provide guidance or supportive recovery dialogue, then return to the unfinished task. No real-person phone call is in the selected scope. |
| Scorekeeper | Display authoritative energy, numeric score and progress. Read-only display; no independent awards or separate stoplight. |

Dennis owns integration for Orchestrator, Check-In Console, Scorekeeper and
the social NPC cast/routines. Lady D owns Mr. P/Platform, including
Dial-a-Friend's content, behavior and live help integration. The shared state
still verifies recovery and progression; it does not implement her tutor or
Helper. Confirm the robot-content and
implementation split before assigning files: the conversation discussed
splitting the purple world and robot challenge, without defining a technical
module boundary.

Mr. P can adapt his phrasing to the player, offer simpler guiding questions
and be gently theatrical. The proposed harsh-room/garden reactions and
player-tone classification are not approved mandatory mechanics. They must
not silently become penalties or alter correctness. Persistence and humor do
not permit an unbounded question chain that prevents the selected ending.

Claude API use is the selected direction for real Mr. P and Helper; their model,
budgets and working connections remain to integrate. The separate Builder loop
already has a local backend and bounded Windows/API verification. A menu of
Claude models for the course was discussed,
not finalized. Multiple separate providers, a real human friend and actual
phone-number entry are future ideas. Keep credentials outside Godot client
assets and versioned files. Define bounded calls, timeouts and fallbacks for
both live Mr. P and Helper before implementation. Authored answer rules and
game-owned state remain the authority for correctness, score and progression;
provider prose alone is not completion evidence.

## NPC cast and behavior plan

**Approved October 28.** Keep character roles separate from the five system
responsibilities above. The first target cast is six characters: an entrance
host, one optional adaptive Builder companion, the Program Manager, Mr. P and
two background people. Reuse existing character assets. The repair robot is a
challenge prop; Dial-a-Friend does not require an additional physical character.

| Character | Job and behavior | Local history and session memory |
| --- | --- | --- |
| Entrance host | Scripted welcome, controls and game introduction; explain the entrance puzzle. Combine greeter and introductory host into one character. | Authored role and directions; whether the player has seen the introduction. This character is distinct from the upstairs Check-In Console. |
| Builder companion | Scripted greeting; optional Claude follow-up for adaptive help with the entrance puzzle, shooter and exploration. Give it a concrete help goal rather than generating routine greetings. | Short authored personality, last topic, help already given and explicitly selected explanation preferences. |
| Program Manager | Scripted classroom stand-up, get-to-work instruction and ending presentation initially. | Current story stage and which presentation sequences have played. Exact likeness, name and voice remain separate content decisions. |
| Mr. P | Lady D's AI character, questions, persona, activity behavior and Dial-a-Friend. | Her authored content plus game-verified question/attempt state. Do not duplicate her implementation in the social NPC coordinator. |
| Two background people | Authored remarks, gestures and small scripted routines. | A small authored background, a few lines and a met-player flag; no independent LLM loop. |

Assign authored roles, models and starting locations locally when a new session
starts. No model call is needed to invent the roster. Basic idle, walk, run,
wave and interaction animations are reusable movement capabilities, not AI
decisions. Navigation must respect collision, occupied paths and locked gates.
The humanoid actors now reuse idle/walk/run/wave/interaction clips on bounded
local walking routes. They wait at obstructions and preserve route state when
paused. Seated/standing transitions remain future presentation work; Mr. P
keeps his separate floating behavior.

### Player-triggered activation and bounded memory

- Before player contact, use idle or limited scripted routines with no Claude
  calls. A scripted greeting alone also makes no provider request.
- Invoke Claude only when the player requests adaptive follow-up help. Permit
  one player-facing conversation at a time, with bounded calls and cancellation.
- After **each NPC conversation ends**, that NPC resumes a small scripted
  walking/activity routine. This is not a trigger after the entire level ends.
- Background exchanges should initially use authored lines between previously
  contacted NPCs and a cooldown. Do not start autonomous model-to-model loops or
  activate uncontacted characters through those exchanges.
- Keep full biographies locally. Supply only the relevant short profile, at
  most two recent exchanges, structured remembered facts and relevant game state.
  Avoid an extra model request merely to summarize each finished conversation.
- Measure input/output usage as well as request counts. Walking, gestures,
  routine selection and ordinary greetings consume no Claude tokens.

Builder tools now read the current objective, relevant challenge state,
approved hints and its own memory. Two recent topic/reply exchanges and an
explicit explanation preference are retained. Future movement/gesture tools submit bounded
requests to game code for validation; they cannot unlock gates, complete a
challenge, award energy or alter course results. The first connected help loop
uses a reused street actor; local preview and bounded Claude transport are
separate from Mr. P's lesson and recovery rules.

Optional exploration work can add whiteboard/poster inspection, chair use or a
coffee-machine interaction. These are future candidate interactions, not new
required progression gates. Select the props before building them.

### Local operation and current implementation boundary

Players download the game/source from GitHub and run the game and its helper
service on their own machine, using their own ignored `backend/.env`. There is
no hosted game backend or cloud deployment in this plan. Claude requests still
need internet access to Anthropic. No key belongs in game assets or Git.

The compact social population has five reused humanoid actors: an entrance
host, Builder companion, Program Manager and two reception people. Lady D's
separate Mr. P completes the six-character cast. Greetings and topics for the
host, Manager and reception people are scripted, with two recent exchanges
per character. A four-line public exchange is permitted only after both
reception characters have met the player and a later room entry/cooldown.
Only an explicit Builder help choice can invoke Claude. Its schema-2 snapshot
separates earned gates from location, so a shooter win before riding still
produces lower-cab E guidance. Invalid/stale replies, cancellation and local
fallback cannot grant progress. Every closed conversation starts/resumes that
actor's local walking/activity loop; untouched people idle. A verified classroom
introduction also activates the Manager once. Menus, conversations, story/game
interactions, distance and floors pause routines. Blocked paths wait and retry
without bypassing collision or teleporting. New props and Mr. P remain separate.
The existing teaching actor presents a scripted
classroom introduction; it is a generic placeholder, with final name/likeness/voice still to author.
The Builder also has a bounded real Haiku 5.5 verification in Windows Godot;
other states/models, native Mac execution and broad generated-help quality need
further testing. Dennis selected this Builder increment before check-in.

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

The shared-state increment connects only the already playable entrance and
elevator gates, upstairs check-in and the classroom introduction. Its objective order is entrance -> elevator -> check-in -> classroom -> Mr. P pending;
physical location and interaction ownership remain separate from that objective.
Questions, robot completion and the ending must
not be fabricated by that foundation. Lady D's Mr. P content remains separate.

| Area | Verified existing state versus the selected design |
| --- | --- |
| Default Godot scene | Playable building plus the local entrance-puzzle increment, third-person avatar/camera, stairs/ramp, elevator transfer and the approved-blueprint two-floor environment with photo-based finishes, reception, classroom, commons and both street frontages. The full agent gameplay loop is not integrated. |
| Ground-floor desk | Removed from the current environment; selected check-in remains upstairs. |
| Entry/elevator gates | One required entrance pipe circuit/code lock, three optional boards and the lower-cab spaceship shooter are implemented. The first verified circuit reveals the four-digit entry code. Clear all 18 shooter drones in three waves to unlock ascent for the session. Settings → Developer Tools → bypass skips both gates for inspection; it grants no completion or rewards. Returning to play restores any undefeated gate. |
| Upstairs check-in/classroom | Reception supports display-name entry, an avatar photo and verified explicit confirmation. Continue to classroom stages a collision-checked doorway walk, Program Manager stand-up, synthetic crowd response and get-to-work instruction. Closing the receipt and entering the classroom also starts it. Settings pauses the presentation; developer travel cancels it for later replay. |
| Mr. P art and purple room | The rigged Mr. P is now in the compact hexagonal purple room. The reception display offers check-in in normal play; the other displays expose one nearby E: use computer HUD prompt. Developer review retains all 17 art-preview routes. A fade enters the room, and its return pad restores the originating position/view. Six wall panels are visual previews. No question, challenge or story completion is granted; Lady D owns the real content and behavior. See [Character-Assets.md](Character-Assets.md). |
| Robot art | The UNIT 74 interpretation has a private native master, rigged GLB, seven registered transparent part layers and Idle/PowerOn/Assemble clips. The isolated review shows 3D modules and 2D overlays; question content and playable challenge logic remain separate work. |
| Shared state and Orchestrator | The local Godot session verifies entrance/code and three-wave shooter results, publishes gates and objective together, rejects stale/duplicate/unsupported completions and owns active/suspended interactions. Physical gate, elevator permission, HUD objective and NPC progress facts read this state. Review travel earns nothing. Baseline energy 10 and score 0 remain unchanged; real entrance unlock adds one reserve pellet without overfilling energy. Check-in verifies a name, simulated avatar photo and explicit confirmation upstairs. Ordered classroom presentation evidence advances to Mr. P pending once. Course facilitator contracts remain separate. |
| Sample course adapter | Developer-only fixtures validate authored choices and publish course results through the Orchestrator. First/second/later errors, capped energy, per-question attempts, one-time 10/30 score awards, recovery identity/cancellation and required-set completion use the approved temporary settings. The explicit sample panel is available only after verified arrival and purple-world entry with review bypass off. The challenge checkpoint is a test receipt, not the robot game; completion reaches an ending-ready boundary. Lady D's real module is unchanged. |
| Ending and fresh runs | The standalone classroom results, brief assessment and L3 story presentation wait for verified course completion and interaction release. The Developer Tools ending preview never earns progress and returns to the original view. Play Again and confirmed Settings Restart Run recreate session progress without closing Godot. Save/load is outside this pass. |
| Player-facing progress / Scorekeeper | The regular HUD reads energy/maximum, score and verified required-set activity counts from shared state, including player-only mode. A static energy meter accompanies the numeric value. Gates/arrival alone show Activities: not started; the developer track is labelled Sample activities. The display refreshes on shared revisions and cannot award progress, change rules or call a provider. Lady D's question/help interface remains separate. |
| Builder and scripted NPCs | Five reused humanoids implement the entrance host, Builder companion, Program Manager and two reception people. The Builder retains optional bounded help. Other conversations and contact-gated public exchanges are scripted. Each role retains two recent exchanges and resumes its local collision-aware walking/activity loop after conversation; verified classroom presentation also contacts the Manager. Routines pause for interactions, obstacles, distance and floors, with no provider requests or progress awards. See [NPC agents](NPC-Agents.md). |
| Live AI | Builder help was verified in Windows Godot with real Haiku 5.5 on October 28, alongside mocked contract checks. The live test exercised tools, generated replies and bounded usage; a next-step truncation was fixed without raising the output cap. This is a small sample, not broad reply-quality or performance validation. Mr. P and Helper remain unconnected; native Mac and other model/account setups remain unverified. |

Lady D’s documentation PR #11 was merged into `develop`; its unique assets are
under Docs and originals under Archive. Duplicates and unrelated research were
removed. It delivered no playable challenge or agent code. The old browser
walkthrough branch and merged documentation branch have been deleted; work
uses `develop` as the integration branch; check live Git state for current feature branches.

The old web game included a shooter, but its removal was authorized earlier.
Its tracked source remains in Git history at `305b179`; do not claim it is
currently playable. The current Godot shooter is a new local implementation
with drawn ships and bounded projectile state. The canonical building GLB remains under
`trials/building-review/`; Blender, Godot and the browser viewer now share the
blueprint assembly. Godot reads gameplay anchors from the assembly manifest.
Physical floors, the game slice and curriculum L1/L2/L3 are different concepts.

The October 27 reference photos have been received and reviewed. On October 28,
Dennis reapproved the original blueprint as the authority for room connections.
Photos guide appearance and proportions, rather than replacing that topology.
The ramp continues forward into the ground hallway, with elevators on the left.
Upstairs, turn right toward reception; its direct classroom doors and Hallway 2
follow the drawing. Hallway 2 passes two small rooms and joins the commons
without a wall or door. Hallway 1 ends at the bathrooms behind the shafts.
Dennis's subsequent October 28 clarification confirms a reception doorway to the
additional front room beside the classroom, superseding the drawing's access-TBD label.
See the [blueprint and photo guide](Building-Review.md#approved-blueprint-and-photo-references).
Dimensions are estimates; unobserved details are not claimed as measured facts.

The latest October 28 walkthrough revision keeps those connections and adds
1 m of width and 1.8 m of depth to reception relative to the preceding correction.
Its estimated footprint is 9.4 by 5.74 m; Hallway 2 has about 3.18 m clear width.
The classroom retains about 82.4% of its floor area, with complete furniture
assemblies relocated rather than stretched or discarded. The additional-room
door is included in the approved door inventory and geometry/movement checks.
The ground yellow side-room door and reception's
separate-room door are locked for the current playtest. The bench sits against
the wall opposite the lifts, and the kitchen runs along the bathroom-side wall
at Dennis's confirmed marker. The lounge is relocated to clear the kitchen and
island. Elevator position and scale are unchanged. These are environment/access
adjustments, not new gameplay or check-in implementation.

## Current assets and next milestones

The latest October 28 increment moves the rigged Mr. P from his temporary
classroom position into the hexagonal purple room. Any computer or laptop can
open that room through the E interaction and a fade, except that normal reception
use opens the Check-In Console. Check-in and the classroom introduction are
implemented. The purple room remains an art preview independent of course
completion; opening it early cannot complete a lesson. The rigged
robot stays face-up on the classroom repair bench in seven separated modules. Five
social people from the player's Quaternius collection populate the entrance,
reception and classroom. Their shared resources, explicit placements and capped
idle processing are documented in [Character Assets](Character-Assets.md).
The room follows the supplied lavender-wall/cream-trim/grey-carpet reference,
with six preview question panels. These models and transitions are ready for
review and later integration. They do not implement Mr. P's questions, the robot
challenge or the gameplay agent loop. The one-required, three-optional pipe puzzle is now the
implemented entrance activity and replaces the earlier ordering puzzle.

The shared session and deterministic Orchestrator now connect the existing
entrance puzzle and elevator shooter. Typed gate events require the current
session, expected stage and actual controller completion. Exact replays do not
repeat publication; rejected results leave the current task unchanged. The
ordinary objective reaches **Mr. P pending** after check-in and the classroom
introduction. Explicitly opening the developer sample enters `course_active`
and, after verified sample results, `ending_pending`. Neither gates nor arrival
sequences grant course rewards.
Physical zone, objective and interaction owner are separate facts. A new world
starts a new session; R/developer travel preserves earned progress. No disk save
or cross-launch persistence is implemented.

Next, connect
Lady D's implementation through the provisional adapter boundary. Sample
retries, help, zero-energy recovery and checkpoint rewards work locally;
the real content, Helper and robot-game mapping still need integration. The
standalone ending now consumes the verified course boundary after the course
interaction closes. The approved temporary rules have not changed. Do not accept conversational
prose as an answer key or fabricate completed content while she works.

Lady D owns Mr. P's questions, persona, answer/completion rules, the robot
challenge and Dial-a-Friend.
The reusable cast scene is an art/integration boundary: the Orchestrator is an
internal coordinator. The Builder now has one optional adaptive help loop, while the reception
characters are scripted. The five selected humanoid roles now have bounded
post-conversation routines; free navigation between rooms and seated transitions
are not implemented. These interactions cannot award progress
or replace the five course responsibilities. Connect
Mr. P, Helper and robot challenge through adapters when their implementation is
ready, without introducing a second source of truth or duplicating content logic.

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
- [x] **Entry pipe puzzle:** one required circuit, three optional circuits with
  distinct palettes, four-digit number pad and physical door unlock,
  incorrect-path/code rejection, finite hint, current-level reset and close/reopen.
- [ ] **Entry puzzle player review:** playtest clarity and difficulty. The code
  is a gameplay gate, not production access control. F3 developer travel remains
  an explicit review bypass. The 1/2/3 travel shortcuts work only while developer
  bypass is enabled, including after both gates are earned. Normal Settings and
  Developer Tools are separate views. Developer bypass awards no energy or score. Verified entrance unlock stores
  one reserve pellet.
- [x] **Elevator shooter first increment:** three-wave local spaceship shooter,
  18-drone verified victory, three shields, unlimited retry, pause/close/reopen,
  session unlock, Ride upstairs handoff and reversible Developer Tools bypass.
- [ ] **Elevator shooter player review:** review difficulty and pacing with
  players. Current arcade settings are temporary; course energy is separate.
- [x] **Check-in:** name validation, confirmation event, simulated photo sequence
  and interruption handling. No real roster or camera integration is assumed.
- [x] **Classroom introduction:** staged doorway walk, generic Program Manager
  captions/gestures, synthetic crowd murmur, pause/cancel handling and verified
  computer objective. Final likeness/name/voice remain content decisions.
- [ ] **Energy and score review:** use the approved temporary 10 maximum,
  +1 correct answer, +3 robot completion, full recovery to 10 and 10/30 score
  values now. Review final balance after playtesting; this is not a start blocker.
- [ ] **Lady D / Mr. P: real Helper recovery:** the sample has ordered supportive-message and
  confirmation evidence, decline/cancel handling and refill. Real Helper content,
  transport and fallback must connect without bypassing that verification.
- [ ] **Attempt-rule playtest review:** sample checks cover per-question count,
  reset on next question, no recovery reset and continued help/retries. Change
  these defaults only through an explicit playtest decision.
- [ ] **Lady D / Mr. P: live tutor and Helper:** Claude model, available credentials/budget,
  request limits, timeouts, fallback content, persona examples and evaluation.
  Neither role may award completion through free-form output.
- [x] **Gate state and handoffs:** local session/event IDs, stage validation,
  real entrance/shooter evidence, idempotent completion, shared permissions,
  interaction ownership, reversible review and fresh-world reset.
- [x] **Sample course state and handoffs:** authored choice validation, activity/
  revision/interaction/session/event identity, one-time rewards and zero-energy
  recovery evidence. Close/reopen preserves the current step; late/replayed
  results cannot add progress or cost. Alternate sample counts/order/settings
  use the same adapter. Samples are not final course content.
- [x] **Social NPC cast and routines:** five humanoid roles beside Lady D's
  separate Mr. P; scripted host/Manager/reception topics, two-exchange histories,
  post-conversation walking/activity, collision/floor checks, safe obstacle waits
  and interaction/distance pauses. Movement cannot award progress or use Claude.
- [x] **Player-facing progress HUD:** shared energy/max meter, numeric score
  and activity counts appear outside the developer panel. Before a course is
  bound, show not started; label the developer course as sample. Completion
  counts come from required/completed IDs, with no local rewards or progression.
- [ ] **Real course integration:** refine Godot/Python/backend transport and
  evidence with Lady D's implementation, without duplicated validation logic.
  Lady D owns robot gameplay and its content; agree the verified part mapping
  with her. Dennis does not
  need to author Lady D's actual questions to build the surrounding adapter.
- [ ] **Presentation:** exact Program Manager name/dialogue and permitted source
  assets, animation lengths/skipping, room transitions, robot activation and
  accessible feedback. Low-energy blinking and room objects moving are ideas,
  not mandatory mechanics yet.
- [x] **Standalone ending and replay:** fade to the classroom, show the bound
  course's energy, score and required-set results, a short fictional assessment,
  L3 celebration and Play Again. The Developer Tools ending preview is available
  before completion and restores the original position/view and progress.
  Settings Restart Run asks for confirmation; replay resets the session inside
  the same engine process with bypass off. Progress is session-only; save/load
  is not planned for this pass. L3 is a narrative destination, not an actual
  course assessment or new playable level.
- [ ] **Final ending integration and player review:** connect Lady D's verified
  complete required set and release the course interaction. Confirm pacing and
  story copy with a human playtest; the developer sample is not her real course.

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

## October 29 playtest fixes

This increment keeps Mr. P separate. The elevator shooter retains eighteen
drones and three shields, with faster motion and telegraphed double bursts
then three-shot fans in waves two and three. The check-in form now bounds
wrapped content inside a scroll container; the first-open blank purple panel
was text laid out above the viewport. Photo confirmation is still explicit.
The classroom crowd cue removes its generated noise bed and plays more softly.

NPCs rotate greetings and local replies, offer an explore choice, and can
start local routes after both gates pass. Two reception actors also make
physical, authored elevator errands. No extra provider calls or course rewards
come from these changes. Building-Assembly.md records the two-metre classroom
extension, relocated plant, closed small-room doors and confirmed commons
photo references IMG_4798–IMG_4803. Further room styling remains a user review.

### Entrance approach and rear-wall placement follow-up

The retained front door leaves now start closed and pose open only when the
entrance is earned or explicitly bypassed. Their own colliders follow the same
pose; they are excluded from the fixed building collider. The former tinted
lock rectangle is removed, and the keypad stays at its existing wall mount.
Within 1.15 metres, a clear approach automatically opens the puzzle without
camera aiming or E. The first visit explains rotation, circuit testing and
the code. Escape keeps the panel closed until the player steps away and
returns; acknowledged guidance does not repeat during the run.

The robot and its bench now move together against the extended rear wall.
Both retained plants and the complete bin assembly are tucked into the rear
corners. This is a placement correction; the commons accent pass is not a
full photographic recreation. More room views can guide the next visual pass.

### Commons reconstruction from new room photographs

The twelve October 29 photographs supersede the earlier commons accent pass.
The room now uses shared white desk rows, caster office chairs, central grey
and charcoal lounge seating, light wood tables, wood-sided quiet booths, window
shades, blue storage surfaces, clothing storage and detailed overhead services.
The prior circular rug and yellow cushions are removed. The kitchen wall,
room footprint, portal states, robot placement and entrance flow stay fixed.
The room proportions are estimates within the approved shell. Verify the
played room with `verify_commons.gd` and the updated commons review views.

## October 29 clarity changes: items 1–7

- Conversations close with **Thanks**; Esc remains available.
- The lower elevator prompt explains that winning its game unlocks the second
  floor. An unlocked elevator offers travel rather than another game.
- The first approach to the stairs after entry displays movement/ramp guidance
  for nine seconds. The elevator objective's Help page retains the instructions.
- Classroom plants remain against the rear corners. Saved bounds and an actual
  aisle walk verify that no plant remains in the middle.
- Physical signs identify Classroom, Reception and Commons. The three quiet
  booths retain their door labels. These use the canonical building asset.
- Shooter enemies use red bodies and yellow wings. Player shots are green
  beams; enemy shots use amber diamond silhouettes. Shooter rules are unchanged.
- Walking into a real chair does not request sitting. C remains the deliberate
  sit/stand input and is ignored while gameplay controls are inactive or locked.


### Presentation round: approved items 8–14

- Unlock: original quiet chime, brief fragments and a reduced-motion alternative.
- Intro: first-launch exterior camera with upward text, Skip, Continue, static
  reading and Help replay. The generated sky uses the supplied cloud and warm
  sun references; provenance is in `godot/assets/sky/provenance.json`.
- Entry: one required circuit, four-digit keypad, three optional colored boards
  and one non-farmable reserve pellet. Spending it restores exactly one energy
  only during course play when below maximum.
- Music: Hymn downstairs, Discovery in the shooter, and saved upstairs selection
  from Electric Dreams, Horizons and Helios. Tracks crossfade, previews stop
  after eight seconds, and saved volume controls and quiet footsteps remain.
- Dialogue: selected student choices use local OS speech before the NPC response.
  Text remains visible. Closing, muting or disabling speech cancels the utterance.
- Items 15–17 were deferred in that round and are implemented in the navigation
  round below.

Verification: 86 Python tests, 33 presentation checks, 115 entrance checks,
54 course checks, native macOS speech
start/end and response-order/cancellation checks passed. Automated tests cover
small-window intro/keypad layouts, gate evidence, optional replays, reserve
idempotence and soundtrack selection. Native previews cover intro, unlock and
Audio controls. Windows OS speech still requires a Windows playtest.


### Navigation round: approved items 15–17 and entrance sidelights

Approved scope: extend entrance sidelights to the closed leaf pivots without
moving walls or narrowing the 2.52 m doorway; add a read-only guidebook with
controls, current objective and floor maps; replace repeated floating E labels
with one contextual HUD prompt; add an 18-second in-engine panoramic camera
sequence before the existing introduction text. No branches or pushes.

Acceptance: native front/top-down door views and ray collision at both former
slits; map textures rendered from the actual GLB with the same world projection
as player/objective markers; B/M/Esc keyboard and pause-menu access; small-window
fit; unchanged progression; retained physical room signs; intro Skip/Replay and
reduced-motion restoration. Camera storyboard and map previews are shown during
implementation. Persistent intro/audio preferences remain owned by their current
settings files. Guide/map selection and camera playback are temporary UI state.


Navigation round implementation: JourneyGuide owns Objective/Controls/Map pages;
Main owns B/M/Esc and movement locking through the existing menu interaction.
BuildingMap draws actual-floor textures plus read-only player/objective markers.
Physical signs remain; repeated floating E labels are hidden and existing target
selection drives one contextual HUD prompt. IntroCameraPath owns the same four
poses used by the shown storyboard and live 18-second panorama. Text follows
for 24 seconds. Skip restores the original camera and controls at any phase;
reduced motion immediately uses the final still and static text. Replaying
upstairs uses a temporary visual student at the entrance, without teleporting
the real player or changing progress. The scene is rendered in-engine rather
than introducing a pre-rendered video dependency.

Verification on macOS: 88 Python tests; 36 new navigation checks; 115 entrance,
65 portal, 37 check-in (including B/M name typing), 49 controls, 67 NPC and 32
developer review checks passed. Native Blender verification: 79 checks passed.
Native screenshots cover both floor maps, small-window guidebook, closed/front
and top-down entrance, four camera storyboard poses and live intro text.
Windows and a user playtest remain unverified. No branches, commits or pushes.


### Six small follow-ups: approved implementation scope

This round addresses the saved extra-navigation-hints toggle, complete street
map coverage, deliberate chair-based sitting, classroom introduction Skip,
small-window guide/map usability and stale documentation. Program Manager
identity/voice, broader player reviews, Windows and Lady D's work remain deferred.
Existing navy/cyan UI, building geometry, gates, audio preferences and developer
bypass remain unchanged. No branch, commit or push.

Acceptance: hints default off and preserve other preferences; ground map shows
the whole walkable street with engine-matched markers; zoom/pan/Fit and text
scroll work at 800×600 and 1280×720; sitting needs a reachable same-floor chair
and standing finds a clear floor point; collision alone cannot sit; Skip is
available only after real classroom entry, is recorded explicitly and restores
camera/controls without course rewards. Check pause, interruption and repeat
input, plus the surrounding gameplay regressions and native renders.


Six follow-ups completion (macOS, working tree on develop):

| Requirement | Result | Evidence |
| --- | --- | --- |
| Saved extra navigation hints | PASS | Default off; Display toggle; isolated preference reload preserves intro, motion and voice settings; hidden during modals. |
| Full street map | PASS | Ground render covers all four street-bound corners; former missing marker at Godot [0,0,18] remains inside map. Model and texture hashes are bound by tests. |
| Deliberate chair sitting | PASS | Actual exported seat surfaces; same floor, proximity, wall and occupancy checks; anchored sit; clear standing position with a fallback when blocked; no collision-triggered sitting. |
| Classroom Skip | PASS | Button / Space after verified physical entry; unavailable during transfer or pause; explicit skipped evidence; no course reward; repeated input inert. |
| Narrow guide/map usability | PASS for local checks | Scrollable text, zoom buttons/wheel/keyboard, drag pan and Fit; bounds checked at 800×600 and 1280×720; native small and large captures inspected. Human usability review remains. |
| Documentation | PASS | Removed obsolete absent-sitting and floating-label claims; documented current controls, preference and skip behavior. |

Verification: 89 Python tests and 38 focused follow-up checks passed. Existing
controls 49, classroom 35, navigation 36, session 39, portal 65 and check-in 37
checks passed. Native Godot captures confirm seated chair alignment, whole-street
map, zoomed upstairs map, Display toggle, extra-hint overlay, small-window guide
and classroom Skip. Building geometry and all Lady D/Mr. P implementation are
unchanged in this round. No branches, commits, pushes or real preference changes
were made by the test harness. Restart the game process to load the updated code.

Deferred: final Program Manager identity/voice/dialogue; human puzzle/shooter,
room appearance, audio, NPC routines, cinematic and complete-route reviews;
Windows compatibility and optional live Builder verification. These checks do
not replace user acceptance or imply Lady D's content is integrated.


### NPC, shooter balance and audio/intro review — 2026-10-29

Reviewed the local develop working tree based on 1ee00b9 with native macOS
Godot 4.7.2. The full-route playtest is set aside. Lady D/Mr. P work is excluded.
No branches, commits or pushes were made.

- NPC behavior: 600 simulated seconds upstairs and 120 seconds at street level,
  using real movement/collision updates. Reception actors completed 28 elevator
  rides across both runs. No floor-support failures; longest continuous movement
  blockage was 0.5 seconds. Local pauses froze movement. Occupying a destination
  cab held the NPC safely until it cleared, then travel resumed and released the
  reservation. These accelerated checks do not replace a human routine review.
- Fixed obsolete host and Builder hints that required four pipe boards or E at
  the entrance panel. Guidance now describes approaching the panel, one required
  circuit, a four-digit entry code and three optional bonus circuits.
- Shooter balance: six input-only policies, 30 seeds each at 60 Hz. Stationary
  fire won 0/30; middle-width continuous sweep won 30/30 with no damage in 12.9
  seconds; edge-to-edge sweep won 11/30; enemy tracking won 15/30; predictive
  tracking won 29/30. These are automated policy results, not human win rates.
  Later-wave difficulty remains a concern because one simple pattern dominates.
  Difficulty is unchanged. A later tuning pass should challenge that pattern,
  then compare the same pilots and a human playtest.
- Audio: offline source measurements and existing runtime trims place all five
  music tracks within about 0.8 LUFS at default 50% Master/Music settings (roughly
  -33 to -34 LUFS). Estimated footstep peak is about -76 dBFS at defaults and
  -64 dBFS at maximum, consistent with barely audible steps. These estimates
  are not speaker loudness measurements or subjective listening approval.
- Native playback: music advances; shooter/upstairs transitions and rapid music
  choices retire old loops; Audio preview cancels when leaving the page; focus
  pauses/resumes music. Intro replay, panorama-to-text, static reading, Skip,
  timed finish and upstairs camera/control restoration pass without earning
  progress. Native reception choice speech starts and cancellation works.
- Fixed focus loss: the intro now holds its camera and timer while backgrounded;
  an active shooter pauses and requires explicit Resume after returning.

Verification: NPC 67, NPC travel 12, shooter 37, audio 35, navigation 36, new
focus/guidance 13 and native audio/intro 16 checks passed. Native teardown logged
four ObjectDB instances at exit; this is a remaining test cleanup warning, not a
verified sustained runtime leak. Native screenshots were inspected for intro
text and wave-three warning presentation. Windows, full-route playthrough,
human difficulty/readability/listening approval and optional live Builder calls
remain unverified. Saved player audio preferences were preserved.

Review artifacts are in the chat's layout-review folder: npc-behavior-review.json,
npc-street-review.json, shooter-balance-review.json, audio-level-review.json,
audio-intro-review.log and focus-guidance-review.log.


### Commit checkpoint before shooter tuning — 2026-10-29

Rechecked the accumulated develop working tree before making the new shooter
change. All 89 Python tests pass using the project virtual environment with
local loopback access. Godot checks pass for pipes, entrance, shooter, elevator,
check-in, controls, classroom presentation, session, portal, developer review,
audio, NPC dialogue/travel, navigation, small follow-ups, focus/guidance, clarity,
commons, presentation rewards, layout, cast, population, orchestrator, developer
skips/disabled mode, restart and progress. Corrected one obsolete progress test:
the meter remains read-only, but the approved reserve pellet has an action button.
The separate character asset scene timed out; its Mr. P/robot asset review is
outside this round and is not reported as passing. Full-route human review and
Windows remain deferred. Remote develop matched the local base at fetch time.
This checkpoint records earlier approved changes as one integrated commit;
new shooter tuning follows in a separate verified commit.


Additional recheck: the NPC role test also assumed the old fixed return greeting.
It now checks the next authored greeting from the approved rotating dialogue;
all 19 role checks pass. The broader model/physics walk test needs more than the
initial 90-second runner limit and is being rerun with a longer allowance.
Neither timeout is counted as a passing check.


Model-walk recheck completed: 80 checks, zero failures. Updated three stale
expectations to match the approved furnished layout: two Hallway 2 doors must
block walking, and commons access follows the clear aisle around the dining
furniture. No geometry was changed. The suite initially exceeded the short
runner limit; the longer completed run reports its real result.


### Shooter pattern fix — 2026-10-29

Wave one retains its five drones, movement, single-shot speed and timing. Waves
two and three now mark the player's current horizontal row, hold that warning
in place for 0.9 seconds, then fire a beam for 0.2 seconds. Move up/down to leave
the marked band. Wave two schedules lanes every 2.4 seconds; wave three every
1.65 seconds. Existing burst/fan volleys, three shields, hit grace, pause, retry
and earned elevator rules remain. The amber warning covers the collision band;
steady dashed lines, a solid active beam and control text distinguish the states.

Verified against the same 30 seeds per strategy, with movement/fire inputs only:

| Policy | Before | After |
| --- | --- | --- |
| Fixed middle-width sideways sweep | 30/30 wins, zero damage | 0/30 wins; wave one still zero damage |
| Responsive pilot with vertical dodging | Not measured in original baseline | 30/30 wins, average 2.2 shields remaining |

Seven policies supplied 210 trials. These are deterministic automated results,
not human difficulty ratings. The committed receipt is
`Docs/Archive/Shooter-Balance-2026-10-29.json`; it includes seeds, file hashes,
all policy results and the native keyboard playthrough receipt.

Native Godot on macOS: real keyboard movement/fire cleared all 18 drones,
retained three shields, earned elevator travel, arrived upstairs and restored
controls, with no review bypass. Entrance setup used a separately verified pipe
fixture; this is a shooter playthrough, not a full-route claim. Native warning
and active-beam renders were inspected at 1280×720 and 800×450; modal bounds were separately
checked at 800×600. The render test
uses force_draw so an occluded macOS window does not stall its capture.

Checks after tuning: shooter 37, lane lifecycle/fairness 23, seeded balance 3,
elevator 31, orchestrator 38, session 39, focus/guidance 13, audio 35, navigation
36 and developer skips 16 all pass. Updated test pilots use ordinary two-axis
movement and fire, with no shield/enemy/progress edits. The elevator test now
reports a failed ride rather than waiting forever if a flight fails to finish.
Earlier rechecks passed 89 Python tests and the 80 model-walk checks. Native
flight teardown still logs two ObjectDB instances at exit; this does not prove
a sustained runtime leak. Windows, human balancing and full-route acceptance
remain deferred. No Lady D/Mr. P content or building geometry changed in this fix.

Reproduce the balance check with the project's Godot executable:
`godot --headless --path godot --script res://developer/tests/verify_shooter_balance.gd`
The default JSON output is in the ignored `godot/.godot/shooter-balance-review.json`.


Fresh-cache verification completed after fixing the fixture packager to include
current runtime scripts, test pilots, music, sky and map assets. A new optional
`--tests` selector makes the requested verification scope explicit. Starting
with an empty derived cache, Godot imported and passed shooter 37, lanes 23,
balance 3 (210 trials), audio 35, navigation 36 and focus/guidance 13 checks.
The importer could not save global editor preferences inside the sandbox;
resource import and all six selected suites completed successfully. This is
fresh-cache evidence, not a clean tool installation or Windows verification.

Command (with GODOT_BIN set to the installed Godot executable):
`.venv/bin/python tools/verify_environment_fresh.py --tests verify_shooter verify_shooter_lanes verify_shooter_balance verify_audio verify_navigation verify_focus_and_guidance`


### Developer Tools cleanup and intro panorama preview — 2026-10-30

Developer Tools now groups its controls under Gates, Travel and Previews, with
compact paired buttons, a two-line status readout, muted disabled buttons and a
focus ring on the free-exploration toggle that matches the other buttons. It fits
800×600 without scrolling. **Previews → Intro panorama** replays the 18-second
street panorama and introduction text from wherever the player stands; the
developer preview plays the camera motion even when Reduced motion is on, while
player replay from Help & objective still respects that setting. Esc or Skip
restores the original view and controls. No gate, energy, score or pellet changes.

Verification on macOS with Godot 4.7.2 (Homebrew): 89 Python tests; navigation 39
(three new preview checks), review 32, controls 49, developer skips 16, developer
disabled 16, course UI 34, ending 42, audio 35, progress 29, restart 18, small
follow-ups 38, presentation 33, focus/guidance 13 and classroom 35 checks passed.
Native captures confirmed the panel at 800×600 and 1280×720 and panorama frames
from the new button. The older `capture_developer_tools.gd` capture stalls at its
elevator-ride step on this Mac both before and after this change; that capture is
not reported as passing.


### Intro flow into play — 2026-10-30

Dennis found the end of the intro abrupt: the camera held still for the text,
then cut to the gameplay camera at a different distance and field of view while
the HUD appeared. The shots now flow continuously (no stops at shots 2 and 3).
The introduction text begins rising at 12 seconds as the camera keeps approaching,
and the final shot is the player's live gameplay camera, so the 38-second sequence
ends exactly on the playable view. The overlay fades over the last two seconds,
then the HUD fades in. Skip or Continue glides into the player view over one
second. A replay started away from the entrance ends behind its stand-in and
returns to the real player through a brief fade to black. Reduced motion still
shows the static text over the final view. No progress or gate rules changed.

Verification on macOS, Godot 4.7.2: navigation 46 (seven new intro checks:
text during the approach, stand-in framing, exact gameplay-camera arrival,
natural hand-off, HUD fade, Skip glide and glide completion), focus/guidance 13,
presentation 33, controls 49, classroom 35, small follow-ups 38, review 32,
restart 18, ending 42, developer skips 16 and audio 35 checks pass. A deterministic 30 fps render of the full
sequence measured a 0.0 m camera jump at the hand-off and a largest frame-to-frame
change in camera motion of 2 mm. Human review of pacing remains open.


Follow-up the same day: Dennis approved the intro pacing and removed the separate
**Continue to entrance** button, because **Skip intro [Esc]** already glides into
the player view. The intro now shows two centred buttons: Skip intro and the
motion toggle.


### October 30 playtest fixes

Dennis's playtest notes, handled as separate verified changes.

- **NPCs stay at their posts until you talk to them.** Clearing both gates used
  to start every non-Manager route and timed reception elevator errands, which
  looked like AI switching on by itself. Now only a closed conversation resumes
  that character's route, and reception errands start only from **Go explore**.
  No Claude call is involved; the live provider still needs `--agents`.
  Verification: NPC travel 13 (new check that cleared gates alone start no walk
  or errand), routines 58 and NPC 67 checks pass; Fable 5.1 review found no issue.
- **Entrance exit, shooter result and replays.** After the first real unlock the
  puzzle keeps its success message until the player leaves; Enter building or
  Esc then fades to black and places the player centred before the open doors
  instead of beside the keypad and the swinging leaves. The shooter's result
  screens ignore Space and hold their buttons for 1.2 seconds; Ride upstairs
  fades the arcade before the elevator. Both games offer Play again, and F near
  the keypad or lower cab replays a game already won. Replays use a fresh copy of
  the game state under a separate `replay` interaction, award nothing and restore
  the earned state on close. Verification: entrance 121, elevator 38, shooter 37,
  orchestrator 38, developer skips 16, controls 49 and review 32 checks pass.
  Fable 5.1 review found four small issues (Shift+Tab order, replay offered after
  developer bypass only, menu during the entry fade, the ride fade); all fixed.
- **Entrance rails, closed side door and classroom laptops.** The closed entrance
  leaves now have the bottom rails the source model always had (they were
  dropped by an unimported selection kind); the glazed reception door to the
  additional room beside the classroom is closed; and the second laptop on each
  of the six classroom tables, with its separate cyan display face, is turned to
  face its own chair. Rebuilt with Blender 5.2.3 on macOS (native checks 79),
  maps re-rendered. Verification: layout 166 (new laptop-vs-chair and on-leaf
  rail checks), building walk 79 (the additional-room door now blocks), entrance
  121, navigation 46, portal 65, controls 49, classroom 35 and 89 Python tests
  pass. Fable 5.1 review caught a first attempt that placed the rails 12 m along
  the facade; fixed and re-verified. See Building-Assembly.md.

