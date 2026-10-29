# Builder companion and scripted NPC conversations

The Builder companion now provides a small, player-triggered help loop, separate
from Lady D's Mr. P. One existing street actor stands near the entrance; the two
reception characters remain scripted. The sixteen-person visual population is
retained for this increment. The final six-character cast, movement/routines,
check-in/classroom sequence and Mr. P integration remain later work in the
[active PRD](Project-Plan.md#npc-cast-and-behavior-plan).

## In the game

Approach and face the Builder near the entrance, press E and choose **What
should I do next?**, **Give me a hint**, or **Break it into steps**. The greeting
is always scripted. Default local help needs no key or backend; it reads the
same game-authored hint catalogue as the provider tools. For adaptive wording,
explicitly launch with `--agents` and select a help option. Entering a room,
ordinary greetings, walking and background remarks never invoke Claude.

The companion reads the current verified objective and the live pipe/shooter
observation. It can name the next authored pipe connection without rotating a
tile, testing a circuit or exposing the door code. After a shooter win, it
separates the earned gate from physical arrival: on the street/ground floor it
still directs the player to press E at the lower cab; upstairs it describes check-in as
coming next. Developer bypass does not become an earned win in these facts.
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
history. The current ambient actors resume their idle presentation after a
conversation; full scripted walking/routines are not implemented yet.

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

The service binds to 127.0.0.1, rejects browser origins/unexpected Host headers,
limits JSON to 16 KiB and logs no dialogue or credentials. The ignored backend
.env is read only by the optional service. The launcher strips provider
credentials from Godot import/game processes. SDK telemetry is disabled; the
configured default model remains `claude-haiku-5-5`. Live access, latency,
content and spend remain unverified; mock checks use no real key/provider call.
No hosted backend or deployment is part of this game.

The implementation follows the existing SDK's
[client tool round trip](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview),
with game-owned validation and a finite wait for the next player action.

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

Official references:

- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python)
- [Tool-call lifecycle](https://platform.claude.com/docs/en/agents-and-tools/tool-use/handle-tool-calls)
- [Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
