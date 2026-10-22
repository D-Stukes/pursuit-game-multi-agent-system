# Product Requirements Document — v3
## "Pursuit: The Climb" — A Multi-Agent Career Journey Game

**Authors:** Lady D & Dennys
**Date:** October 22, 2026
**Course:** Pursuit L2 — Week 5, Multi-Agent Systems
**Status:** Current working spec — supersedes v2 (Oct 21)
**Repo:** github.com/D-Stukes/pursuit-game-multi-agent-system

---

## 0. What changed since v2

v2 locked the design. v3 reflects what we've since **built and decided**.

| Area | v2 | v3 (now) |
|------|----|----------|
| Agents | Described (3, conceptual) | **5 agents** with a defined loop + handoff protocol; architecture diagram done |
| First agent | Not built | **Greeter wired, tested, and verified** (Python) |
| Art / 3D | "stylized, Godot later" | **Stylized realism**; web prototype + **photo-textured 3D proof-of-concept**; photogrammetry planned |
| Process | Direct commits | **Git flow: feature → develop → main** with PRs; `.env` ignored before any key |
| Character creation | 3 student types | **Weapon picks** (communication, tech, coding, AI, newbie+curiosity) |
| Mini-games | Hidden bonus | + **elevator shooter** (Bug Blaster) and the **Platform question-storm** |

---

## 1. Vision

A playable journey through the Pursuit Fellowship. **Real people** (students or staff) climb the real Pursuit path toward the shared goal: **getting hired**. The AI pieces are **facilitator agents** — they run the experience; they are not opponents. We dramatize the real student experience (information overload, assignments piling up, learning to lean on AI) while keeping it genuinely fun. Scope: **Level 1**, done well.

**Industry / functional area:** education & workforce development (edtech) · career-readiness and onboarding. We chose it because we know it firsthand, the roles map cleanly to agents, and progress is measurable.

---

## 2. The Agents (5)

Agents coordinate through one **shared game state** (a blackboard); an **Orchestrator** activates one per zone. Full write-up + diagram: `Documents/agent-architecture.html`.

1. **Orchestrator** — coordinator; activates the right agent by zone; verifies handoffs before advancing.
2. **Greeter** *(built)* — reception; checks the player in; awards the **Show Up** star.
3. **The Platform** — classroom facilitator / antagonist-helper; floods the player with questions ("answer them all") and drains energy until they learn to use AI. Purple top-hat ghost villain.
4. **AI Helper** — the "Use AI" lifeline; cuts 100 questions to the 3 that matter; awards **Do the Work** + reveals Hidden Objective #1.
5. **Scorekeeper** — observer/HUD; turns shared state into stars, the energy meter, and the stoplight; triggers the hidden bonus.

---

## 3. The Agent Loop & Handoff Protocol

Every agent runs **sense → decide → act**:
- **Sense** — read player input + shared state.
- **Decide** — apply role logic (scripted for most; the Platform can be LLM-driven via the Claude API).
- **Act** — update the shared state and return a **handoff**.

**Handoff message:** `{ done, to, reason }`. When `done` is true, the **Orchestrator verifies before advancing** — three checks:
1. addressed to it (`to == "orchestrator"`),
2. the `reason` is one the agent may legitimately exit with (`exit_reasons`),
3. the agent's **postcondition** holds (e.g., the Greeter's Show Up star was actually awarded).

If any check fails, the handoff is **rejected** and the agent stays active. *(This is implemented and tested — see §7.)*

---

## 4. Level 1 — "The Foundation"

**Goal:** earn **3 stars** — *Show Up · Do the Work · Be a Teammate* — then ride the elevator's **★ floor** to clear the level.

**Zones (built from real photos):** Street → Ground-floor hall → Elevator → Reception → Lobby → Classroom.

**Core systems:**
- **Stars** (3 Foundation objectives) · **Energy meter** (drops on busywork, restored by using AI) · **Stoplight** (🟢🟡🔴, coaches not punishes).
- **Character creation = pick your weapon:** Great Communication · Tech Savvy · Coding Experience · AI Experience · Newbie + Curiosity (each sets starting energy).
- **Hidden Objective #1 — "Use AI":** the flashing lifeline that beats the Platform.

**Mini-games:** elevator **Bug Blaster** shooter (clear GitHub/code/AI errors) · the Platform **question-storm** · a **keypad code-gate** (planned).

---

## 5. Art & 3D Direction

**Target:** stylized realism — grounded in the real Pursuit spaces, like our reference games (see `Documents/Visual-Direction.md`).

- **Now:** web prototype uses the **real photos as scene backdrops**; a **photo-textured 3D room** proof-of-concept (Three.js) lets you walk around the classroom.
- **Next:** either **model the rooms in Godot** (controllable depth) or **photogrammetry** (Polycam/Luma) for true walk-around 3D — which needs a dense, overlapping photo sweep of each space (capture checklist to come).
- **Characters:** original stylized avatars; the Platform is our own purple top-hat villain (no copied IP).

---

## 6. Technology & Tools

| Need | Choice |
|------|--------|
| Game engine (target) | **Godot** (free) |
| Fast prototype / demo | **Web** (HTML/JS, Three.js for 3D) |
| Agent logic | **Python** (`agents/`), scripted; **Claude API** planned for the Platform |
| 3D source | real photos as reference/textures; photogrammetry later |
| Version control | **GitHub** + Git flow |

---

## 7. Current Status (what's built)

- ✅ **Playable web prototype** — splash, weapon pick, elevator shooter, reception, the Platform, Use-AI beat, stars/energy, win. (Shareable link.)
- ✅ **Photo-textured 3D room** proof-of-concept (classroom).
- ✅ **Agent architecture** diagram + explanation.
- ✅ **Greeter agent wired, verified, and tested** — `agents/` + `demo/run_greeter.py` + `tests/test_greeter.py` (waits when no check-in; advances only on a verified handoff; both tests pass).
- ✅ **Monday pitch outline + script.**
- 🔜 Next agents: the Platform (LLM-driven), then Scorekeeper; keypad mini-game; Godot rooms.

---

## 8. Process & Practices

- **Git flow:** each feature on its own branch → **PR into `develop`** → only tested code reaches **`main`**.
- **Secrets:** `.env` is git-ignored (added before any key exists); a committed `.env.example` documents needed keys with no secrets.
- **Collaborators:** Lady D (owner) and **Dennys** (`antunishdPursuit`, write access).

---

## 9. Open Decisions (remaining)

1. Platform dialogue — **scripted vs. LLM** for the demo (leaning hybrid: scripted + one real LLM call).
2. Energy meter visual (pellets vs. bar).
3. 3D path — **Godot modeling vs. photogrammetry** first.
4. Keypad mini-game — what reveals the code.

---

## 10. Links

- **Repo:** github.com/D-Stukes/pursuit-game-multi-agent-system
- **Playable game, 3D room, architecture diagram:** see pinned links / `Documents/` and `prototype/`.

---

*End of PRD v3 — current working spec for the team.*
