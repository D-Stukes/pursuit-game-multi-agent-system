# Ideation Synthesis
## "Pursuit: The Climb" — Brainstorm Review & Decisions

**From:** Voice brainstorm, Lady D & Dennis (`Pursuit_Game_Ideation1_10_21_26.mp3`)
**Date of session:** October 21, 2026
**Prepared:** October 21, 2026
**Transcription:** done locally on this Mac (Whisper) — the recording was not uploaded anywhere.
**Purpose:** Organize the free-flow ideas into something you can review, decide on, and build from — plus updated tool recommendations with these ideas as context.

---

## 1. The Big Picture (what this session added)

Your earlier docs (PRD + Level 1 Design Doc) defined the *structure*: real players, facilitator agents, a Level-1 walk through the real Pursuit building, 3 stars, a stoplight.

This brainstorm added the **soul**: the idea that the game isn't just *about* Pursuit — it dramatizes the real emotional experience of being a student (information overload, assignments piling up, learning to lean on AI, bringing strengths from your past). The standout concept — **personifying the Platform** — turns a real pain point into the game's central character and, conveniently, into a clean multi-agent story.

---

## 2. Idea Catalog (organized & status-tagged)

**Status key:** ✅ **Agreed** (you both liked it) · 🟢 **Consider** (promising, fits scope) · 🟡 **Stretch** (great, likely post-MVP) · ⚪ **Parked** (keep for later levels)

### A. The Personified Platform  ✅ **Agreed — headline idea**
- The Pursuit platform (which "talks too much" and answers with a paragraph when you want a sentence) becomes a **character** — a serious, powerful cartoon figure: *"I'm the Platform. I'll help you through this course… but you must answer ALL my questions."*
- Framed like a **Dr. Strange / Dr. Who** figure who conjures worlds and tries to keep you in them answering endless questions, while a **clock ticks** and **assignments pile up** (e.g., "7 assignments left today").
- **The twist / hidden objective:** a flashing **"Use AI"** button. The player discovers that the way to beat the Platform's endless questions is to **use AI** — *"Congratulations, you discovered Hidden Objective #1: use AI to help with common challenges."*
- **Why it's gold for this class:** it's a natural **multi-agent** setup — one agent (the Platform) overwhelms you; another agent (an **AI Helper**) rescues you. That tension *is* the lesson.

### B. Living Characters (agents)  ✅ **Agreed**
- 1–3 **living characters** modeled on Pursuit personalities (composites, not real named individuals) that **adapt** how they talk/interact based on how you engage them — "like a living human."
- Maps directly onto our **facilitator agents** (Greeter, Facilitator, Scorekeeper) — this just gives them more adaptive personality.

### C. "Phone a Friend" Help  🟢 **Consider**
- A *Who Wants to Be a Millionaire*–style **"dial a friend"** lifeline to help you get through a hard task without losing energy.
- Low-cost, fun, and reinforces Pursuit's collaboration value. Could be how the **AI Helper** is summoned.

### D. Energy / Power Meter  ✅ **Agreed (simple version, from the start)**
- A visible **energy meter** (e.g., "power pellets" — 7 as a placeholder) that **drops on failures** and **recharges on success / level-up**, with Mario-style floating pickups.
- **Decision reached in the session:** add a **simple** energy meter *from the beginning*, tied to the player's failures and successes. (A fuller "character meter" is a stretch.)
- Pairs naturally with the existing **stoplight** (🟢🟡🔴) — energy is the number, stoplight is the mood.

### E. Character Creation (choose your student)  🟢 **Consider (keep simple)**
- At game start, pick **what kind of student you are** — quiet, outgoing, curious, goal-driven — plus light customization (style/outfit/voice).
- **Superpowers from past careers:** management, teamwork, taking direction, fast learning.
- **"Weapons" = real skills:** communication, understanding code, adaptability.
- **Decision reached:** do a **simple** character setup now; full RPG customization + "character meter" only **if time allows**.
- Nice touch: experience/strengths give a **starting bonus** (more pellets, or slower energy loss) — models how students really do arrive with different strengths.

### F. "Test Your Superpower" beats  🟡 **Stretch**
- In class/team moments, prompts to **"test/level up your superpower"**; wrong answers cost energy. Fun, but more systems to build.

### G. The Living Room / Puzzle Room  🟡 **Stretch (strong for later)**
- A room that **changes as you interact** with it (touch the chalkboard, the trash can) — the room itself **is an agent**. Mysterious **text on the walls** instead of a voiceover, for atmosphere.
- Beautiful concept; likely richer than the 2-week Level-1 MVP needs, but a great candidate for a signature space later.

### H. Time Pressure & Assignment Backlog  ⚪ **Parked**
- A ticking **clock** and a running tally of **assignments owed** ("what you owe, what to do"). Evocative and true-to-life, but heavy for the MVP; revisit once core loop works.

---

## 3. Decisions Reached in the Session

1. ✅ **Personify the Platform** — both liked it; bring it in.
2. ✅ **Add a simple energy meter** that responds to failures/successes — *from the start.*
3. ✅ **Keep character setup simple**; full customization + character meter only if time permits.
4. ⚠️ **Scope caution (Dennis):** several ideas (full energy-as-character-system, time pressure, elaborate RPG) are **out of scope for ~2 weeks** — incorporate selectively.
5. ▶️ **Next actions named on the recording:** update the PRD with these ideas; Dennis reviews the PRD in **GitHub** and starts building the **3D environments**.

---

## 4. Recommended 2-Week Scope (my synthesis)

**Build now (MVP):**
- Level 1 walk-through (6 zones) — *already specced.*
- **3 facilitator agents** → reframe one of them as the **Personified Platform** (the adaptive "living character" that gives you the task and over-asks).
- **Simple energy meter** + existing stoplight.
- **Hidden Objective #1: "Use AI"** — a flashing button / AI Helper lifeline that lets you shortcut the Platform's questions. *This is the demo centerpiece.*
- **Simple character pick** (one screen: choose a student type that sets your starting energy).

**If time allows:** Phone-a-Friend lifeline · a light "test your superpower" beat.
**Later levels:** the Living Room puzzle agent · time-pressure clock · full character/superpower RPG.

---

## 5. Updated Tool Recommendations (with these ideas as context)

The core stack is unchanged — but the new ideas sharpen *how* we use it:

| Need | Recommendation | Why (updated) |
|------|----------------|---------------|
| **Game engine** | **Godot** (free, safe, stylized) | Still the right call for a stylized, Level-1 scope. |
| **3D environments** | Build in Godot from your photos as reference | Matches Dennis's plan to start on 3D now. |
| **The agents' logic** | Scripted state machines for most; **wire the Personified Platform to an LLM (Claude API)** | The Platform "talks too much" and adapts — a perfect, contained place to show **real** multi-agent behavior for the class, without making *every* agent an LLM. |
| **AI Helper / "Use AI" lifeline** | A second lightweight LLM call (or scripted) | Demonstrates the multi-agent point: one agent overwhelms, another assists. |
| **Energy meter + stars + stoplight** | A single Godot **autoload** (global state script) | Cheap to build; the Scorekeeper agent reads/writes it. |
| **Character creation** | One Godot menu scene | Keep to a few choices that modify starting energy. |
| **Version control** | **GitHub** (already in use) | Dennis is reviewing the PRD there; keep docs + project together. |

> **New strategic point:** the Platform-vs-AI-Helper tension gives you a crisp, *teachable* multi-agent architecture — exactly what a Multi-Agent Systems project wants to show. I'd make that the spine of the demo.

---

## 6. Open Decisions for You & Dennis

1. **Make the Platform one of the 3 agents, or a 4th?** (I lean: make it the **classroom Facilitator's** alter-ego, so we keep 3 agents.)
2. **LLM or scripted** for the Platform's dialogue in the demo? (LLM = strongest "wow" for the class; scripted = safest.)
3. **Energy meter visual:** pellets, a bar, or glowing dots?
4. **Character pick:** how many student types, and what starting bonus does each give?
5. **Do you want me to now update the PRD** (and Level 1 doc) to fold these decisions in, as the recording suggested?

---

*End of Ideation Synthesis v1. Full transcript saved alongside this doc as `Ideation-Transcript.txt`.*
