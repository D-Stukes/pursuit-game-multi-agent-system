# Builder companion and scripted NPC conversations

The Builder companion now provides a small, player-triggered help loop, separate
from Lady D's Mr. P. Dial-a-Friend belongs to her Mr. P work, not this social
NPC coordinator; the existing sample recovery is only a shared-rule fixture.
The compact cast uses five reused humanoids: the entrance host, Builder,
Program Manager and two reception people. Lady D's separate Mr. P is the sixth
character. Only the Builder's explicit help choices can use the provider;
the other four roles have authored greetings, topics and local backgrounds.
All social histories retain two recent exchanges per character. The Manager
also presents the existing scripted classroom sequence. Social roles now have
small post-conversation walking routines; Mr. P remains separate in the
[active PRD](Project-Plan.md#npc-cast-and-behavior-plan).

## In the game

Approach and face the Builder near the entrance, use the nearby contextual E prompt and choose **What
should I do next?**, **Give me a hint**, or **Break it into steps**. The greeting
is always scripted. Default local help needs no key or backend; it reads the
same game-authored hint catalogue as the provider tools. For adaptive wording,
explicitly launch with `--agents` and select a help option. Entering a room,
ordinary greetings, walking and background remarks never invoke Claude.

The conversation UI shows the character and dialogue, without provider names
or scripted/local reply labels. Loading and connection notices are generic.
Developer checks read internal reply provenance; visual labels do not establish
whether a response came from the API.

The companion reads the current verified objective and the live pipe/shooter
observation. It can name the next authored pipe connection without rotating a
tile, testing a circuit or exposing the door code. After a shooter win, it
separates the earned gate from physical arrival: on the street/ground floor it
still directs the player to press E at the lower cab; upstairs it directs the
player to the reception Check-In Console. Developer bypass does not become an
earned win in these facts.
The player can return to this street companion for later help; following or
relocating the companion throughout the building is not implemented.

Memory contains at most two topic/reply exchanges, a chosen explanation style
and a small hint count. It is session-local and belongs only to that companion;
there is no summarizer call. Close/Esc restores movement. Settings, developer
travel or leaving the interaction cancels a pending reply. Changed observations,
late responses, wrong identities and duplicates cannot add phantom memory.
Service failure, timeout or exhausted budget uses a labelled local hint without
awarding progress. A request received by the backend may finish its bounded
provider work after game-side cancellation; cancellation does not undo spend.

Both reception characters also have E/Talk and three scripted topics. After the
player contacts both, a later reception entry can play four authored public
lines with a 60-second cooldown. These never use Claude or private Builder
history. Contacted actors resume their authored walking/activity routine after
each conversation. Characters with no player contact remain idle.

## Roles and walking routines

The session loads authored roles and placements from
`godot/assets/characters/population.json`, with matching dialogue profiles in
`npc-dialogue.json`. No model request assigns the cast.

| Social role | Reused actor | Routine after conversation |
| --- | --- | --- |
| Entrance host | StreetWestB | Short sidewalk walk, wave, return. Scripted controls, entrance and route topics. |
| Builder companion | StreetWestA | Short sidewalk walk, interaction gesture, return. Existing optional help loop is unchanged. |
| Program Manager | ClassroomTeaching | Short classroom walk, interaction gesture, return. Scripted classroom topics. |
| Reception guide | ReceptionA | Short reception walk, interaction gesture, return. |
| Fellow Builder | ReceptionB | Short reception walk, wave, return. |

E starts a conversation and pauses the actor. Escape/Close ends it, restores
player movement and activates/resumes that actor's routine. Repeated conversations
retain the current waypoint/activity time. A completed, verified classroom
introduction also contacts the Manager and starts its routine once; cancellation
does not activate an untouched Manager.

These are authored local routes, not free navigation through the building.
`NPCRoutineState.gd` validates bounded, level offsets, speeds and activities.
`AmbientNPC.gd` uses a [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
and supporting-floor queries. Walls, locked gates, people and furniture remain
physical obstacles: the character waits and retries when a path clears, without
teleporting or inventing a route around it.

One population physics loop pauses routines during any conversation, public
exchange, Settings, puzzles, elevator travel, classroom presentation or purple-world
visit. Far-away characters and the other floor pause without losing state.
Animation work is separately culled by distance and camera visibility.
Idle/Walk/Run loop metadata is copied per actor; meshes/materials and source
assets remain shared. Normal routes walk; Run is an available capability.
No movement, greeting, activity or public exchange invokes Claude or changes
course energy, score, gates or completion.

`verify_routine_state.gd` covers activation, pause/resume, malformed settings and
an unseen three-point route with a different home and speed. `verify_routines.gd`
uses actual E/Escape conversations for all five roles and physics movement,
including obstacle wait/resume, floor checks, Settings and floor culling.

## Provider boundary

The existing local backend uses the official Anthropic Python SDK, pinned to
2.3.0 in `backend/requirements.txt`. Builder schema 2 has four read-only tools:
`read_current_objective`, `inspect_current_challenge`, `get_approved_hint` and
`recall_my_conversation`. A reply must observe the objective and, for hint/steps,
its approved hint. Successful turns return model/tool counts and input/output
tokens; the backend also counts received tokens for rejected responses. No
shell, file, movement, gate, energy, score or completion tool is exposed.

The loop permits three model requests and four tool calls, 180 output tokens
per request, a six-second elapsed deadline and no automatic SDK retries. A
service process defaults to 60 model requests, at most 12 per minute and two
concurrent dialogue requests. Godot supplies bounded observations and owns
memory. The service stores no conversation history. Grounding and limits do
not prove that every live generated sentence is correct or enjoyable.

For the configured Haiku 5.5 Builder, requests explicitly disable thinking and
use low effort so the short response cap remains available for tools/dialogue.
The current question label and requested steps style are supplied immediately;
other configured models are not given Haiku-specific settings. Haiku's default
thinking shares the output cap, as described in the
[migration guide](https://platform.claude.com/docs/en/models/haiku-5-5/migration-guide).

The service binds to 127.0.0.1, rejects browser origins/unexpected Host headers,
limits JSON to 16 KiB and logs no dialogue or credentials. The ignored backend
.env is read only by the optional service. The launcher strips provider
credentials from Godot import/game processes. SDK telemetry is disabled; the
configured default model remains `claude-haiku-5-5`. The Windows/Godot Builder
connection was tested with the real API on October 28, including tool calls,
rendered replies, usage and unchanged game progress. The first run exposed a
truncated next-step reply; the bounded recheck passed after the request-setting
fix. This is a small live sample, not a general quality/latency/cost guarantee.
Other machines/models and live Mr. P/Helper remain unverified. Mock checks use
no real key/provider call.
No hosted backend or deployment is part of this game.

The Builder implementation follows the existing SDK's
[client tool round trip](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview),
with game-owned validation and a finite wait for the next player action.

## Upstairs check-in

In normal play, the reception computer opens the **Check-In Console**. After
both puzzle gates are verified and the player arrives upstairs, enter a display
name, take a simulated photo of the game avatar, then choose **Confirm check-in**.
This uses no camera or provider. Name and photo remain in the current session;
there is no real enrollment or roster check. Closing before confirmation clears
the draft. Reopening a completed check-in shows its receipt. Settings and
developer travel cancel an unfinished form without awarding progress.

The Orchestrator checks controller evidence, upstairs location, interaction
ownership, stage and session before publishing the arrival once. Directions,
unconfirmed photos and repeated signals cannot complete check-in. Energy,
score, questions and robot parts are unchanged. The next objective is the
classroom stand-up. Developer review retains every computer's purple-room art preview
and cannot confirm check-in. Mr. P's content is separate.

## Program Manager classroom handoff

Choose **Continue to classroom** after check-in, or close the receipt and walk
through the double doors. A short fade stages the player at the existing
doorway, checks its clearance and walks the avatar inside. The existing
`ClassroomTeaching` actor reuses the existing female-formal model as a generic
Program Manager: a wave, daily stand-up
caption, a brief synthetic crowd murmur with a caption, then the get-to-work
instruction. A presentation camera keeps the speaker visible; the normal player
camera and movement return afterward. The final likeness/name/voice are not
supplied, and no real person or microphone is recorded.

Settings pauses the presentation time, crowd audio and Manager animation;
Resume keeps the sequence's ownership. Developer travel or enabling bypass
cancels an unfinished sequence without completing it. A later classroom entry
can restart it. A blocked doorway cancels safely rather than moving through it.
The Orchestrator accepts the ordered entry/stand-up/crowd/get-to-work evidence
once, then sets **Use a classroom computer**. This is `mr_p_pending`, not a
question, robot or course completion. No energy or score changes. The Manager's
local walking routine starts after the verified introduction; cancellation does
not activate an untouched Manager.

`verify_check_in.gd` and `verify_classroom.gd` exercise the state and scene
boundaries. `play_arrival.gd` captures actual walking, typed-name and button input
plus the classroom handoff at 800x600. Its earlier entrance/shooter wins are
explicit fixtures. Fresh consumer checks regenerate an isolated Godot import
cache from retained assets; they do not establish fresh tool installation,
native Mac support or user acceptance.

## Backend setup

Use Python 3.11+ from the repository root. Create a project environment and
install the pinned dependencies:

```sh
python -m venv .venv
```

On Windows:

```powershell
.venv\Scripts\python -m pip install -r backend/requirements.txt
.venv\Scripts\python -m backend.server
```

On Mac:

```sh
.venv/bin/python -m pip install -r backend/requirements.txt
.venv/bin/python -m backend.server
```

Copy `backend/.env.example` to `backend/.env` when the key is available and set
`ANTHROPIC_API_KEY` there. The actual `.env` is ignored by Git. Environment values
override the file. A service without a key returns `provider_unconfigured` and
makes no provider requests; its health endpoint is still available.

For a combined game/service launch, use:

```powershell
# Windows, from the repository root
& ".\Play Game.cmd" --agents
```

```sh
# Mac, from the repository root
.venv/bin/python tools/run_game.py --agents
```

The launcher starts a hidden loopback service on an available port, passes only
its URL to Godot and stops its own service when the game exits. Missing key
selects local preview. Normal launch without `--agents` starts no backend and
needs no Python SDK. When running the Godot editor directly, start the service
separately and add `--npc-provider=claude --npc-agent-url=http://127.0.0.1:8765`
as game arguments. Those flags contain no provider credentials.

## Wire contract and verification

`POST /v1/npc/turn` accepts Builder schema 2: request/NPC/topic identity,
this companion's bounded memory and a validated game observation. Replies echo
identity and contain dialogue/usage; they carry no permitted world mutations.
The legacy reception schema-1 backend contract is retained for compatibility;
the game now handles reception dialogue locally. `GET /health` reports
configuration readiness, not verified provider access.

Use the project environment for `python -m unittest tests.test_builder_help`
and the existing protocol/SDK tests. Mock tests verify held-out board/shooter
states, memory isolation, tool results, bounded loops, usage and errors. The
optional-launcher tests read backend configuration; omit those when a check
must not read the user's real .env.

`python tools/verify_npc_service.py` runs Godot through actual localhost HTTP
and the installed SDK against an in-process mock provider. It checks Builder
correlation, usage, stale/duplicate results, cancellation, finite fallback,
local URL/redirect enforcement and zero-provider scripted chatter. Pass
`--project <isolated Godot fixture>` for a fresh consumer. No real key or
provider connection is involved.

Check contextual help, changing state, memory, modal ownership and UI sizes:

```sh
godot --headless --path godot --script res://developer/tests/verify_builder.gd
```

Capture a rendered conversation with the mock provider:

```sh
python tools/verify_npc_service.py --script play_builder --output "<absolute evidence directory>"
```

`play_builder.gd` walks
from the normal street spawn and uses E/Enter/Esc; its PNGs and receipt are
explicitly labelled as a fixture. Direct execution uses local preview.
`play_npc.gd` retains the separate scripted-reception capture after player contact.

For an explicitly authorized live test, use the ignored local key through:

```sh
python tools/verify_builder_live.py --output "<private absolute evidence directory>"
```

This opens rendered Godot, permits three selected help turns and at most nine
model requests, and saves screenshots plus a sanitized live audit. The key
stays in the local backend process. `--topics next steps --max-model-requests 4`
restricts a recheck further. This utility is never invoked by normal launch or
the mock tests. Live captures are labelled `mode: live`, `fixture: false`;
local fallback is a failed live result, not a substitute for API evidence.

Official references:

- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python)
- [Tool-call lifecycle](https://platform.claude.com/docs/en/agents-and-tools/tool-use/handle-tool-calls)
- [Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)

## October 29 playtest changes

Social roles rotate three greetings and use different replies for repeated
topics. The dialogue offers “Go explore” to end the chat and resume a route.
After both entrance and elevator gates pass (including independent developer
skips), nearby actors can begin their local routes without a first conversation.
The Program Manager keeps the verified introduction as its activation gate.

Reception guide and builder take alternating authored errands through the same
elevator anchors as the player, walk downstairs, pause, and return home. One
NPC reserves the cab at a time; a player ride and an NPC ride cannot overlap.
Arrival waits if the player occupies the destination. Conversations, menus and
other modal activities pause errands. Public reception exchanges require both
reception actors to be present. These are bounded routes, not free navigation
or additional AI calls. `verify_npc_travel.gd` checks the physical round trip,
reservation, floor support, pause and absence of earned progress.


The classroom stand-up can be skipped after physical entry using its button or
Space. This records explicit skipped presentation evidence, not watched beats;
the Manager becomes available through the existing arrival handoff. Final name,
appearance and voice remain content decisions. Repeated floating E labels are
hidden; one nearby HUD prompt identifies the selected interaction.
