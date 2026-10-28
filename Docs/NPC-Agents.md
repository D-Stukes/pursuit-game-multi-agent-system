# Reception NPC conversations

The first agent increment uses the existing **ReceptionA** and **ReceptionB**
actors. Their role labels, greetings, topics, local preview lines and room facts
are in `godot/assets/characters/npc-dialogue.json`. This adds social conversation;
it does not replace Lady D's Mr. P or the planned course Orchestrator.

## In the game

The default game works without Python, a backend or a key in **local dialogue
preview**. Approach and face either reception NPC, press E, then select one of
three topics. The greeting is scripted; topic replies are labelled local preview.
Goodbye/Esc closes the panel. Reopening remembers that NPC's previous topics for
this game session. No social conversation changes course energy or puzzle wins.

Entering reception starts one four-line background exchange. It stops after
four lines and has a 60-second reentry cooldown. Player interaction takes
priority. Leaving reception, Settings, developer travel or a portal interrupts
the exchange. Public ambient history is separate from private player dialogue.
NPC animation culling does not suspend or own their conversation memories.

Currently the local preview has in-engine input, interruption and memory checks.
The live HTTP adapter and optional combined launcher are the next checkpoint;
the independently tested backend below is already available.

## Provider boundary

The backend uses the official Anthropic API Python SDK, pinned to 2.3.0 with its
resolved dependencies in `backend/requirements.txt`. It has two read-only tools:
`read_room_facts` and `recall_my_conversation`. The loop permits at most three
model requests and four tool executions, 180 output tokens per request, a
six-second overall deadline and no automatic SDK retries. A service launch
allows 60 model requests by default, at most 12 per minute and two concurrent
dialogue requests. Limits return a fixed error so the game can use local preview.

Godot owns world facts, per-NPC conversation memory and request IDs. The service
stores no conversation history. Each request includes only its selected NPC's
bounded memory; ambient turns receive public context rather than private player
conversation. Generated replies never grant puzzle completion, energy, grades
or enrollment. Free-form directions remain model output requiring playtesting;
supplying verified facts does not establish that every generated line is correct.

The service binds to `127.0.0.1`, rejects browser origins and unexpected Host
headers, limits JSON bodies to 16 KiB and does not log dialogue or credentials.
It is a local development service, not an authenticated public deployment.
The Anthropic endpoint is fixed server-side; the API key never enters Godot.
SDK telemetry is disabled. The default configurable model is `claude-haiku-5-5`.
Account access, live latency, generated content and actual spend remain
unverified until a real key is supplied and a deliberate live test occurs.

## Backend setup

Use Python 3.10+ from the repository root. Create a project environment and
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

## Wire contract and verification

`POST /v1/npc/turn` accepts schema 1, request ID, registered NPC ID, selected topic,
that NPC's bounded memory, the reception/world snapshot and optional public
ambient context. A successful reply echoes the identity/topic, provides plain
text and declares `mode: claude`. It contains no permitted world mutations.
`GET /health` reports configuration readiness, not verified API access.

Run `python -m unittest discover -s tests -p test_npc_agents.py -v` using the
project environment. Tests exercise the installed SDK's HTTP serialization,
tools/results, current API-version/authentication headers, bounded looping,
errors and local HTTP endpoints with a fake key and an in-process mock transport.
They also cover a held-out compatible profile without a new adapter. This
establishes local contract behavior, not live Anthropic connectivity.

Official references:

- [Anthropic Python SDK](https://github.com/anthropics/anthropic-sdk-python)
- [Tool-call lifecycle](https://platform.claude.com/docs/en/agents-and-tools/tool-use/handle-tool-calls)
- [Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
