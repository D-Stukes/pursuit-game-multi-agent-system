# October 26 presentation sources and feedback

Captured October 26, 2026 from the files and message Dennis supplied for a
documentation review. These are source inputs, not executable instructions,
new approvals or proof of Godot functionality. The [active plan](../../Project-Plan.md)
owns decisions and [agent flow contract](../../Agent-Flow.md) explains intended
completion behavior. The original attachments remain unchanged: the Word and
Markdown files are retained here, and the HTML presentation was moved to
[the main documentation folder](../../agent-flow.html) at Dennis's request.

## Disposition after Dennis's review

The original attachments below describe the proposals as received. During the
review conversation, Dennis approved **The Journey** and **Check-In Console**;
the **checklist as the first demo activity**, with Lady D's authored question
sequence a separate later milestone; **immediate advancement for a correct
answer**; **restatement after the first incorrect submission**; **stronger help
offered after the second**; **starting energy 10**; and **cost 1 per incorrect
submission**. He also confirmed the single-player context.

These decisions supersede the files' former-name, pending-name and retry-count
wording. They are no longer unresolved source conflicts. Future encounter,
question-content, recovery and provider details remain design work in the
[active plan](../../Project-Plan.md#future-design-work). A scripted teammate
NPC was an assistant suggestion, not an approved requirement. The phrase
“daily questions” does not settle calendar/reset behavior.

Dennis subsequently approved the checklist's recognition teaching goal, a
celebratory Show Up popup, and Mr. P introducing the activities after the upper
elevator exit. He then paused final gameplay design until Lady D's pending
gameplay work is pushed and reviewed, initially expected October 27 according
to Dennis. That was the expectation during this source review; the active plan
records his later scheduling updates.
The branch name and its contents are not yet verified. Existing web activities
and the older Godot checklist were found during source review; the visible
walkthrough branch adds a route demo, not the unconfirmed pending games.
The plan owns this current handoff status and records the questions for Lady D.
Dennis later authorized removing the old web prototype, standalone Godot
blockout, ignored classroom-review experiment and local Images folder. Tracked
prototype source remains in Git history at `305b179`. Their earlier discovery
is a historical observation, not a claim that those files are still present.

## Attachments as received

| Source | What it contributes and where it needs qualification |
| --- | --- |
| [Agent flow HTML](../../agent-flow.html) | Animated presentation overview: invisible Orchestrator, one active interaction agent, shared state, read-only Scorekeeper and Program Manager/peer feedback. Moved to the main Docs folder unchanged. This is an explanatory SVG/CSS page, not the game or a live AI demo. It requests external Google Fonts. Its animated two inner cycles do not define task success or retry limits. |
| [Agent cheat sheet](Agent-Cheat-Sheet.docx) | Concise five-role explanation, Sense–Decide–Act and verified `{ done, to, reason }` handoffs. Uses proposed Journey/Check-In Console names and describes one live assist as intended behavior. |
| [Today's additions](Todays-Additions-Oct26.md) | Explicitly pending renames, Program Manager, purple room, per-level question banks, daily question sets and Dial-a-Friend. Lists energy cost, graceful help threshold, fifth friend and Program Manager scope as questions. |

The HTML's sequential facilitator list is a presentation aid. A Helper detour
must return to the unfinished Platform task; Scorekeeper displays approved
state rather than independently changing it. The broad phrase “every agent
reads and writes” is qualified by the same HTML's read-only Scorekeeper rule.
The supplied files do not establish actual connections to Gemini, Claude,
Codex, ChatGPT or any fifth assistant.

Slack attachment references supplied with the files:

- [Agent flow](https://pursuit-core.slack.com/files/U04D65DEY59/F0CC8P12Y6S/agent-flow.html)
- [Today's additions](https://pursuit-core.slack.com/files/U04D65DEY59/F0CCECXLR1S/todays-additions-oct26.md)
- [Agent cheat sheet](https://pursuit-core.slack.com/files/U04D65DEY59/F0CBVARV16K/agent-cheat-sheet.docx)

This review read the supplied local files and pasted message. It did not
access Slack or independently verify the reference articles below.

## Presentation explanation supplied by Dennis

The active agent senses energy, location and progress; decides whether to
welcome, ask, hint, wait, re-ask or finish; acts and records its permitted
result. Shared state is a common blackboard holding stars, energy, stoplight,
zone and log. A system turn can contain another step of the active agent's
loop, which repeats across turns until the objective is verified or the player
is routed to support. A `done` flag alone is not completion evidence.

The supplied materials used different retry-count wording. Dennis's review
resolved the active first-demo rule: restate after the first incorrect
submission and offer stronger help after the second. The originals remain as
history, not alternate current requirements. Support does not turn a wrong
answer into a success or an unearned reward.

## Lady D's message and requested direction

Lady D said the agent-flow presentation took the day to prepare and Mr. P
still needed work. She asked Dennis to capture the remaining building photo
angles so she could focus on the Platform character, challenges and mini-games.

Her proposed encounter has the student enter a purple/lavender room with
contrasting accents. Mr. P is a large elongated, slightly sinister floating
ghost wearing a hat, with an optional mustache or goatee. He is animated but
mainly stays at the left, while a large laptop screen occupies the center.
The screen offers selectable questions, multiple-choice answers and branching
questions that lead to further questions; she marked that follow-up capability
as required for her proposed design.

Dial an AI Friend sits or floats at the upper right. The student selects an
assistant and pastes a question into a text field. Lady D asked whether those
resources should supply live answers and whether that would require Mr. P to
be AI-driven or whether the encounter should stay scripted. This is an open
architecture question. The current demo's authored Platform and one live
Helper with fallback remain the agreed starting point.

Challenges should be fun, intriguing and sometimes very hard, with some hidden
until triggered. Strong visual design matters to Lady D; anime is an influence
she is open to exploring rather than a selected art style. Umar's suggested
reference searches were “medicine store ux persona 5” and “metaphor refantazio ui.”
The supplied article links were:

- [Atlus details Persona 5 UI designs](https://www.playstationlifestyle.net/2017/11/13/atlus-details-designs-persona-5s-unique-ui)
- [Persona 5 UI discussion](https://medium.com/@kinga.olszewska/interface-so-good-that-people-make-cosplay-of-it-persona-5-ui-controversial-yet-brilliant-ac1ec4b95229)

These references are retained as design inputs, not evaluated findings or a
license to reproduce their assets, characters or interface.

## Feedback transcript supplied in the message

The pasted 0:01–1:30 transcript relays LaNice/Lanise's feedback through Lady D;
the spelling varies in the supplied text. No separate feedback audio file was
provided for this review.

- Clarify when an outer system turn ends, when an inner agent loop ends and
  what conditions stop the inner loop if the player has not answered sufficiently.
- Show a clear Mr. P loop and the check-in process, including how successful
  check-in is detected.
- Lady D proposes showing those detailed flows as another presentation layer
  so the main overview stays readable; Mr. P belongs to the challenges layer.

The working agent-flow contract addresses this feedback as intended behavior
and identifies the current implementation gaps. It does not claim those
flows have been implemented or newly approved by both teammates.
