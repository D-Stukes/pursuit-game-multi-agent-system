# Mr. P, classroom and robot build prompts

Lady D's November 1 feedback, turned into eight steps from the quickest win to
the ending. Lady D builds these herself; each step has a prompt to paste into
her AI coding tool. Decisions are recorded in the
[project plan](Project-Plan.md#lady-ds-classroom-feedback-and-build-prompts--2026-11-01).

## How to use this

- Open your AI coding tool in the repository folder.
- Start each new chat with the setup block below, then paste one step's prompt.
- Check the result in the game before moving on. Each step builds on the ones
  before it.
- New lines show as on-screen text for now. Recordings can come later.

## Already decided

- The user is called a **Builder** on screen, as Lady D's mentor suggested.
- Keep the six questions for now. Four more (including Daily Standup and Retro)
  come later.
- Mr. P explains each correct answer as on-screen text.
- Dial-a-Friend gives the correct answer and why, with **3 calls per game**.
  After a friend's help, Mr. P only congratulates.
- Mr. P and Dial-a-Friend stay scripted, with no live AI.
- The Program Manager keeps her title as her name. Her second line plays the
  first time the Builder comes back from the Platform with questions still
  unanswered. "Platform" is Lady D's word for Mr. P's purple world.
- The robot challenge comes after all the questions are answered correctly.

## Setup block

Paste this first in every new chat.

```text
I'm working on Pursuit: The Journey, a Godot 4.7 game. The game is in the godot/ folder. Before changing anything, read README.md and Docs/Project-Plan.md, then the files named in the task.

Rules:
- Work on a new branch off develop. Don't push or merge into develop until Dennis has reviewed it.
- Change only what this task needs. Dennis owns the NPC system (NPCLife, NPCConversations, NPCJourney and the npc-*.json files), so don't edit it.
- The user is called a Builder in everything shown on screen, never "player" or "student".
- Mr. P and Dial-a-Friend are scripted. Don't add live AI calls to them.
- When you're done, run the tests named in the task with: python tools/verify_environment_fresh.py --tests <names>
  (Run it from the repository folder. If python isn't found, try python3 or .venv/bin/python.)
  Tell me what passed or failed, and show me a screenshot of the change.
```

## Steps

| Step | Size | Needs from Lady D |
| --- | --- | --- |
| 1. Mr. P's words and explanations | Small | Approve 6 explanations |
| 2. 3D pressable answer buttons | Medium | |
| 3. Dial-a-Friend, 3 calls per game | Medium | |
| 4. Program Manager lines and podium | Small | |
| 5. Classmates and background chatter | Medium | |
| 6. Make the questions count | Medium | |
| 7. Robot challenge | Large | Write the agents and instructions |
| 8. The ending | Small | |
| Later: four more questions | | Write the 4 questions |

### 1. Mr. P's words and explanations

Quick, all in one file, and the explanations are reused by Dial-a-Friend in
step 3.

```text
In Mr. P's question room (godot/game/PurpleRoom.gd):

1. Change any on-screen wording that calls the user a student or player to Builder. For example, "Finally — new student." becomes "Finally — a new Builder."

2. When the Builder picks a wrong answer, Mr. P's on-screen line says exactly: "That is incorrect! Please try again."

3. After a correct answer, Mr. P explains why it's right, as on-screen text. Add an "explanation" to each of the six questions in QUESTIONS. Keep the green answer and the explanation on screen until the Builder presses Space or Enter, then go back to the question list. (Today it moves on by itself after 1.8 seconds.)

Before saving, draft the six explanations (one or two plain sentences each) and show them to me so I can edit them.

Leave the audio as it is. I'll re-record any clips that no longer match.

Tests: verify_purple_room
```

### 2. 3D pressable answer buttons

The biggest visual change Lady D asked for. It stays inside Mr. P's room.

```text
In Mr. P's room, the four answers on each wall board are thin flat tiles (godot/scenes/QuestionBoard.tscn, coloured by godot/game/PurpleRoom.gd). Turn them into 3D buttons:

- Raised off the board with visible depth, with the answer text on the front face.
- When the Builder picks a question (keys 1–6), that board glows white and pulses gently while they answer it.
- Choosing an answer presses it in visibly with a click sound, then it pops back. Keep the A–D keys and also let the Builder click a button with the mouse. (Today only the keys work, and movement controls are locked while answering.)
- Correct: the button turns green and stays green.
- Wrong: the button turns red, Mr. P's text says "That is incorrect! Please try again.", and the button goes back to normal so they can try again.

Keep the close-up camera that frames the board. For sounds, try godot/assets/audio/menu.wav, success.wav and error.wav first, and tell me if a better click sound is needed.

Add checks for the pressed, green and red states to godot/developer/tests/verify_purple_room.gd.

Tests: verify_purple_room
```

### 3. Dial-a-Friend, 3 calls per game

Reuses the explanations from step 1, so the friend and Mr. P always agree.

```text
Add Dial-a-Friend to Mr. P's room (godot/game/PurpleRoom.gd). The friend is an AI-friend character the Builder can call for help, but it is scripted: no live AI call.

- While a question is open, show a Dial-a-Friend button with the calls left, for example "Dial-a-Friend (F) · 3 left".
- The Builder gets 3 calls for the whole game, not 3 per question. When they're used up, the button says so and does nothing.
- Calling shows the friend's on-screen message: the correct answer and why. Use each question's explanation from the earlier step.
- The Builder still presses the answer themselves. After a friend's help, Mr. P only congratulates them (for example "Well done!") and doesn't repeat the explanation.
- Keep the calls left when the Builder leaves the room and comes back. Note which questions used a friend; we'll decide later whether that changes the score.

This replaces the older Dial-a-Friend rule in Docs/Project-Plan.md (restoring energy at zero). Update that part of the plan to match.

Tests: verify_purple_room (add a check that a 4th call is refused)
```

### 4. Program Manager lines and podium

Moves to the classroom. It doesn't depend on Mr. P's room.

```text
Update the Program Manager in the classroom. Today she fades in as a flat picture where Mr. P stood (godot/game/characters/ClassroomCast.gd and ClassroomMrP.gd) and plays a recorded good-morning with no text. A second, 3D Program Manager also walks near the front of the room (ClassroomTeaching in godot/assets/characters/population.json).

- Keep her name as "Program Manager".
- When she appears after Mr. P, show her first line as on-screen text: "Good morning everyone! I need you to do your Daily Standup and then get to work in your Platform. I will be checking your progress, so let's go!" Keep the current recording playing.
- After that greeting she goes to a desk or podium at the front of the classroom and stays there. The building has no podium yet, so add a simple one.
- Only one Program Manager should be in the room. Ask me whether to keep the flat picture or the 3D figure before removing either. The 3D one is part of Dennis's people system, and removing it changes the cast that verify_roles and verify_npc_life check.
- The classroom computers stay locked until Mr. P and the Program Manager finish talking. ClassroomMrP.speaking() checks her recording and her picture's fade-in, so keep that lock working if you move or replace her.
- The first time the Builder comes back from the Platform (Mr. P's purple room, see godot/game/ComputerPortal.gd) with questions still unanswered, she says: "Ok, how is everyone doing? If you need help, or have any blockers, please let me know!" Only once per game.
- Her last line belongs to the ending. Leave it for a later step.

Tests: verify_classroom, verify_classroom_entry, verify_cast, verify_portal, verify_roles, verify_npc_life, verify_population
```

### 5. Classmates and background chatter

Makes the classroom feel busy. Also independent of Mr. P's room.

```text
The classroom has no other students. Add some seated Builders and quiet background chatter:

- Seat about 6–10 classmates at the classroom desks, using the building's real chairs (godot/game/ChairSeats.gd finds them). Leave a free computer for the Builder.
- Reuse existing people models. Only godot/assets/characters/quaternius-casual/Casual_Hoodie.glb has sitting animations (Sitting_Idle_Loop, Sitting_Talking_Loop); the models in quaternius-population don't. Vary the classmates (colours, idle or talking) so they don't all match, and ask me before retargeting animations onto other models.
- They stay seated and don't need to talk to the Builder. Keep them separate from Dennis's walking NPCs and out of godot/assets/characters/population.json.
- While the Builder is in the classroom, play low, on-and-off chatter that fades in and out and stops when they leave. godot/game/ClassroomSequence.gd has a generated murmur (_crowd_murmur) to start from, or suggest a free recorded crowd sound and tell me its license.
- ClassroomSequence.in_classroom() only covers the front of the room (x between -14.9 and 2.9). The back of the room, where the robot bench is, reaches about x = -17, so use the whole classroom when deciding where the chatter plays.

Check that the game still runs smoothly and tell me how many classmates you added.

Tests: verify_classroom, verify_classroom_entry, verify_cast, verify_roles, verify_npc_life, verify_population
```

### 6. Make the questions count

Today finishing the questions changes nothing in the game. The robot needs to
know when they're done.

```text
Mr. P's room keeps its results to itself: finishing all six questions adds no score, unlocks nothing and never leads to the ending. The game already has a pipeline for this. godot/game/CourseAdapter.gd handles questions, explanations, score and energy, and godot/developer/course/sample-course.json (loaded by SampleCourse.gd) is a stand-in course that uses it. Connect Mr. P's questions to it:

- Turn the six questions and their explanations into a real course definition, with one "challenge" step at the end for the robot. Every step, the challenge included, needs prompt, rephrase, hint, explanation, 2–6 choices and a correct_id (see CourseAdapter._validate).
- SampleCourse.gd only loads with Developer Tools; the real course must load in normal play. The orchestrator only accepts answers after claim("course") and begin_course(adapter), while the Builder is in the purple room (see GameOrchestrator.gd).
- Send each answer through the game's orchestrator (godot/game/GameOrchestrator.gd, COURSE_ANSWER_SUBMITTED) the same way the sample course does, so score and progress show on screen.
- The adapter expects steps in a fixed order, but Mr. P lets the Builder pick any question. Suggest how to handle that before changing it.
- The adapter takes 1 energy for each wrong answer. Ask me whether to keep that.
- When all six are right, Mr. P tells the Builder to go back to the classroom and fix the robot.

Tests: verify_course, verify_course_ui, verify_session, verify_purple_room
```

### 7. Robot challenge

Needs step 6 so it only opens after every question is right.

```text
After all six questions are right, the Builder assembles the broken robot and turns it on. The robot is already lying in pieces on a workbench in the classroom (godot/scenes/characters/RobotRepair.tscn, godot/game/characters/RobotRepairDisplay.gd). Its model (godot/assets/characters/authored/robot.glb) has seven parts and Idle, Assemble and PowerOn animations. RobotRepairDisplay.gd spreads the parts by moving bones and switches the AnimationPlayer off, so bringing the parts together means animating those offsets back to zero before PowerOn.

The bench is in the back of the room, outside ClassroomSequence.in_classroom() (which stops at x = -14.9), so detect the Builder near the bench directly.

How it works:
1. Walking up to the bench and pressing E opens the challenge.
2. The Builder picks agents for the job. At least 2 are needed.
3. The Builder picks the right instructions in the right order, one multiple-choice step at a time. A wrong pick says try again and keeps their progress.
4. When the order is right, the parts come together, the robot stands up and powers on.
5. Report completion by answering the course's challenge step from the previous task with its correct choice id, through the orchestrator like the questions. The unused robot_parts field in the course state isn't needed.

Agents and instructions (use mine if filled in; otherwise draft them and show me before building):
- Agents to choose from (mark the right ones):
- Instructions in the right order:
- Wrong instruction choices:

First check whether the PowerOn animation includes standing up. If it doesn't, tell me what's missing.

Tests: verify_cast, verify_course, plus a new test for the challenge
```

### 8. The ending

Last, because it plays after the robot is running.

```text
When the robot is running and the course is complete, the game goes back to the classroom for the ending (godot/game/EndingSequence.gd). Start that ending with the Program Manager at her podium saying, as on-screen text: "Great job today! Let's keep building, and get ready to present next week!" Then continue to the existing results and L3 celebration.

Tests: verify_ending
```

### Later: four more questions

For when there's time. It uses the buttons, explanations and Dial-a-Friend from
steps 1 to 3.

```text
After the first six questions are right, the boards in Mr. P's room switch to four more questions, including Daily Standup and Retro. Use the same 3D buttons, explanations and Dial-a-Friend. Add the four questions to the course from the "Make the questions count" step so they count too.

Here are the four questions, their answer choices, the right answer and a short explanation for each:
1.
2.
3.
4.

Tests: verify_purple_room, verify_course
```
