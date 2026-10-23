# Product Requirements Document — v2
## "Pursuit: The Climb" — A Multi-Agent Career Journey Game

**Authors:** Lady D & Dennis
**Date:** October 21, 2026
**Course:** Pursuit L2 — Week 5, Multi-Agent Systems
**Status:** Draft v2 — *for team review & sign-off*
**Supersedes:** PRD v1 (Oct 19) · incorporates the Level 1 Design Doc and the Oct 21 voice brainstorm

**Implementation update:** October 23, 2026 — see Section 11 for the static 3D review
handoff and Godot playable increment. The accompanying Word file is the earlier
October 21 snapshot. Existing sign-off checkboxes retain their original state.

---

## 0. How to Use This Doc (read first)

This version exists so **you and Dennis can agree on everything before building.** Nothing here is binding until you both check it off in **Section 10 (Sign-Off)**. Status tags used throughout:

- ✅ **Agreed** — both teammates liked it (from the brainstorm).
- 🟢 **Proposed** — recommended; needs a yes/no.
- 🟡 **Stretch** — do only if time allows.
- ⚪ **Later** — parked for levels beyond Level 1.

> **Timeline reality:** ~2 weeks. Everything below is scoped to ship **Level 1** well, not the whole game.

---

## 1. What Changed Since v1

| Area | v1 | v2 (now) |
|------|----|----------|
| **Players** | Implied AI characters | **Real people** — students or Pursuit staff |
| **Agents** | Opponents to "beat" | **Facilitators** — they run the game's actions |
| **Scope** | Full climb (L1→Penthouse) | **Level 1 only**, done well |
| **Engine/Look** | TBD | **Godot**, stylized/animated |
| **New headline idea** | — | **The Personified Platform** + "Use AI" hidden objective |
| **New systems** | Stars + stoplight | + **Energy meter** + **simple character creation** |

---

## 2. Vision

A playable journey through the Pursuit Fellowship. Real players climb from new student toward graduation and a job. The game mirrors the *real* Pursuit experience — showing up, doing the work, being a teammate, feeling the pile-up of assignments, and **learning to lean on AI** — while being genuinely fun.

**Design promise:** a real game (stars, surprises, a meter, a boss-like challenge) AND an honest reflection of Pursuit. Every fun mechanic maps to a real value: courage, preparation, teamwork, adaptability, communication.

---

## 3. Players & Agents

### 3.1 Players ✅
Real people — students or Pursuit staff — play the game.

### 3.2 Facilitator Agents ✅
Agents **run the game's features**; they are not enemies. Level 1 uses **three** (matching "start small, 3 agents"):

1. **The Greeter** — at the reception desk; welcomes the player, checks them in as a "Builder," awards the first star.
2. **The Facilitator / The Platform** 🟢 — the classroom guide. Proposed: give this agent the **Personified Platform** alter-ego (see 3.3). Runs the Foundation task and (lovingly) over-asks questions.
3. **The Scorekeeper / Guide** — ambient HUD voice; tracks **stars + energy + stoplight**, drops hints, triggers the hidden bonus.

> **Why multi-agent:** three independent agents with distinct jobs coordinate to move one real player through the level. The Platform-vs-AI-Helper tension (below) is the teachable core.

### 3.3 The Personified Platform ✅ (headline concept)
The Pursuit platform — which "talks too much" and answers a simple question with a paragraph — becomes a **character**: a serious, powerful figure who says *"I'll help you… but answer ALL my questions,"* conjuring tasks while a clock ticks and assignments pile up.

- **The twist — Hidden Objective #1:** a flashing **"Use AI"** button. The player discovers that the way past the Platform's endless questions is to **use AI**. On first discovery: *"Congratulations — you found Hidden Objective #1: use AI to help with common challenges."*
- **This is the demo centerpiece:** one agent (Platform) overwhelms; another agent (**AI Helper**) rescues. That tension *is* the multi-agent lesson.

---

## 4. Level 1 — "The Foundation"

### 4.1 Goal ✅
Earn **3 stars**, then ride the elevator's **★ floor** to clear Level 1:
1. ⭐ **Show Up** — check in (attendance).
2. ⭐ **Do the Work** — complete the Foundation task.
3. ⭐ **Be a Teammate** — help a peer.

*(The real building's elevator has a literal "★1" button — reaching the star floor = clearing Level 1.)*

### 4.2 The Zones (walk-through) ✅
Stylized Godot scenes built from our reference photos:

| # | Zone | Landmark props | Gameplay |
|---|------|----------------|----------|
| 1 | The Street (exterior) | Zipper Building, LIC skyline, autumn trees | Spawn; walk to entrance |
| 2 | Ground Floor Entry | vending machines, stairs + ramp, yellow door | Movement tutorial; reach elevator |
| 3 | Elevator Bank + Cab | grey doors, bins, **★1 panel** | Press ★1; short ride |
| 4 | Star Floor — Reception | neon Pursuit sign, "Guests/Builders" desk, egg chair | Check in → ⭐ Show Up (Greeter) |
| 5 | Lobby / Commons | silver ducts, sofas, art, red trash can | Meet a peer; signage guides you |
| 6 | The Classroom (hub) | long desks, projector, whiteboard, breakout room | Foundation task → ⭐ Do the Work + ⭐ Be a Teammate |

### 4.3 Core Systems

**Stars** ✅ — the 3 Foundation objectives.

**Energy Meter** ✅ — a **simple** meter (placeholder: 7 "power pellets") that **drops on failures**, **recharges on success / level-up**, with Mario-style floating pickups. *Decision from brainstorm: include a simple version from the start; a fuller "character meter" is 🟡 stretch.*

**Stoplight** ✅ — 🟢 on track · 🟡 attention · 🔴 stalled. Energy is the number; stoplight is the mood. In Level 1 it coaches, not punishes.

**Simple Character Creation** 🟢 — one opening screen: pick a **student type** (quiet / outgoing / curious / goal-driven) that sets a small **starting-energy bonus** reflecting real strengths. *Full RPG customization (outfits, superpowers, weapons) is 🟡 stretch.*

**Hidden Objective #1 — "Use AI"** ✅ — the flashing button / AI Helper lifeline that shortcuts the Platform's questions and grants a surprise reward.

### 4.4 Flow
Street → Ground floor (stairs/ramp) → Elevator (★1) → Reception (check in, ⭐) → Lobby (meet peer) → Classroom (Foundation task ⭐, help peer ⭐; discover "Use AI" 💥) → 3 stars → elevator ★ lights up → **Level 1 complete** (Level 2 teaser).

---

## 5. Art & Style ✅
- **Stylized / animated** (clean shapes, warm light) — not photoreal, not full cartoon.
- **Signature elements:** exposed silver ducts + red pipes, blue + white walls, Pursuit branding (logo, neon infinity sign, "All day, every day," "Lives transformed"), warm wood + colorful art.
- **Characters:** generic stylized avatars. **Do NOT model real individuals** from the photos (privacy) — people shots are pose/vibe reference only.

---

## 6. Technology & Tools ✅ / 🟢

| Need | Choice | Notes |
|------|--------|-------|
| Engine | **Godot** (free, safe) | Stylized 3D; Dennis builds environments |
| 3D source | Our photos as **reference** | Not photo-to-3D scanning |
| Most agents | Scripted state machines | Safe, demo-able |
| The Platform (+ AI Helper) | 🟢 **Wire to an LLM (Claude API)** | Best place to show *real* multi-agent behavior; scripted is the safe fallback |
| Stars / energy / stoplight | One Godot **autoload** (global state) | Scorekeeper reads/writes it |
| Character creation | One menu scene | Few choices → starting-energy modifier |
| Version control | **GitHub** | Keep docs + project together |

---

## 7. Scope Guardrails
**In scope:** 6 zones · 3 facilitator agents · 3 stars · energy meter · stoplight · simple character pick · Hidden Objective #1 ("Use AI") · stylized art pass.
**Stretch (if time):** 🟡 Phone-a-Friend lifeline · "test your superpower" beat · full character customization/meter.
**Later levels:** ⚪ Living Room puzzle agent · time-pressure clock · interviewer/recruiter/stakeholder · the Penthouse.

---

## 8. Roles & Next Steps
- **Dennis:** review this PRD in GitHub; start building the **3D environments** (Zones 1–6).
- **Lady D:** confirm agent personalities + the Foundation task design; shape the "Use AI" moment.
- **Together:** agree on the open decisions (Section 9) and sign off (Section 10).

---

## 9. Open Decisions (recommended defaults — approve or override)

Each has a **✦ Recommended** default so you can move fast: if you both agree, just check "Accept" in the table below; if not, write your preference. These are starting points, not final calls.

1. **Platform = alter-ego or a 4th agent?**
   **✦ Recommended:** make it the **Facilitator's alter-ego** — keep **3 agents**. *Why: keeps scope tight and the multi-agent story clean (Greeter, Facilitator/Platform, Scorekeeper), with the AI Helper as the Platform's foil.*
2. **Platform dialogue: LLM or scripted?**
   **✦ Recommended:** **Hybrid** — scripted Platform dialogue (safe, predictable for the demo) **plus one real LLM call for the AI Helper** moment. *Why: you still show genuine multi-agent, LLM-powered behavior at the key beat, without the risk of fully live dialogue in a 2-week build.*
3. **Energy meter visual.**
   **✦ Recommended:** **glowing dots / "power pellets" (7)**. *Why: readable at a glance, on-theme with the Mario-style pickups, easy to animate.*
4. **Character pick — how many types + bonuses?**
   **✦ Recommended:** **3 student types**, each granting a small **+1 starting pellet** in its strength — *Curious* (learning), *Connector* (teamwork), *Experienced* (resists energy loss). *Why: simple, meaningful, and reflects real different strengths.*
5. **Foundation "Do the Work" task.**
   **✦ Recommended:** a **~90-second onboarding mini-task** with the Facilitator — e.g., arrange your desk + answer 3 quick onboarding prompts; a wrong/skipped prompt is where the Platform "over-asks" and the **Use AI** button appears. *Why: short, teaches the core loop, and sets up the hidden objective naturally.*
6. **Reward currency name + what it unlocks.**
   **✦ Recommended:** call it **"Credits"**; the hidden "Use AI" discovery awards a **Builder Badge** cosmetic + a few Credits. *Why: clear and neutral; "stipend" can stay as flavor text if you prefer.*
7. **Camera.**
   **✦ Recommended:** **third-person avatar**. *Why: shows off the character the player picked and the stylized world; friendlier for non-gamers.*

### 9a. Decision Sign-Off (quick accept/override)

| # | Decision | Recommended default | Accept | Override (write choice) |
|---|----------|---------------------|--------|-------------------------|
| 1 | Platform agent | Facilitator's alter-ego (3 agents) | ✔ (Lady D) | |
| 2 | Platform dialogue | Hybrid (scripted + LLM AI Helper) | ✔ (Lady D) | |
| 3 | Energy visual | Glowing dots / 7 pellets | ✔ (Lady D) | |
| 4 | Character types | 3 types, +1 pellet each | ✔ (Lady D) | |
| 5 | Foundation task | ~90-sec onboarding mini-task | ✔ (Lady D) | |
| 6 | Currency | "Credits" + Builder Badge | ✔ (Lady D) | |
| 7 | Camera | Third-person avatar | ✔ (Lady D) | |

---

## 10. Sign-Off (both teammates)

Mark **Agree / Change** per section; add initials + date. Nothing is final until both agree.

| Section | Lady D | Dennis | Notes / changes requested |
|---------|--------|--------|---------------------------|
| 2. Vision | ✔ Agree | ☐ | |
| 3. Players & Agents (incl. Platform) | ✔ Agree | ☐ | |
| 4. Level 1 design | ✔ Agree | ☐ | |
| 4.3 Energy meter | ✔ Agree | ☐ | |
| 4.3 Character creation (simple) | ✔ Agree | ☐ | |
| 4.3 "Use AI" hidden objective | ✔ Agree | ☐ | |
| 5. Art & style | ✔ Agree | ☐ | |
| 6. Tools (incl. LLM for Platform) | ✔ Agree | ☐ | |
| 7. Scope guardrails | ✔ Agree | ☐ | |
| 9. Open decisions resolved | ✔ Agree | ☐ | |

> **Lady D has agreed to PRD v2 in full (carte blanche) on Oct 21, 2026 to let the build begin** — with the understanding that any point can be adjusted later if Dennis flags a change. Dennis: please skim the camera (Q7) and Platform LLM-vs-scripted (Q2) decisions before starting the 3D, since they affect your work.

**Final agreement:** Lady D ✔ (Oct 21, 2026)   ·   Dennis ______ (date ____)

---

## 11. 3D Environment Handoff and Godot Next Step — October 23

### Current review package

[Open the building review instructions](Building-Review.md).
The package contains one full GLB, an interactive HTML viewer, local Three.js
dependencies and a loopback-only Python launcher. It includes no source photos,
rendered-image gallery or editable Blender master. The team's existing shared
document remains the reference-photo source.

The static environment includes the street exterior, ground entrance, right ramp,
brown-door room and larger left area, aligned ground/second-floor elevator banks,
upper arrival, reception, longer side hallway, separate single-door room and the
classroom reached through reception's double doors. Classroom furniture is retained
inside the same building. The floor structure connects both storeys.

This asset was modeled in Blender from photo references and firsthand layout
corrections. It is not a photogrammetry scan. Dimensions, unseen rooms, the added
wing and the full hallway length remain estimates. The current native/export
checks cover seven sampled routes, but the asset has no authored game collision,
working elevator, player controller or facilitator interactions yet. This handoff
does not mark those gameplay features complete or change existing team sign-offs.

### Pipeline and playable acceptance criteria

Use **Blender → GLB → Godot** for the playable game. **Three.js** remains the
lightweight partner review tool. The next increment is complete when:

1. The current GLB imports into Godot with its materials, correct scale and floor
   alignment; a simple third-person character moves through the entry and ramp.
2. Authored simple collision prevents falling through floors or passing through
   walls while keeping the ramp, doorways and intended classroom route traversable.
3. An explicit elevator interaction transfers the player between aligned ground
   and second-floor landings; a simulated elevator ride is not required initially.
4. The player reaches reception, enters the classroom through the double-door
   connection and can distinguish the single door's separate room.
5. One reception Greeter interaction proves the first check-in/star action before
   broader facilitator and Platform features are integrated.

Physical **ground/second floor** labels describe the building; **game Level 1**
describes the Foundation gameplay chapter. Keep those concepts separate in UI and
implementation. Confirm dimensions and optimize draw calls/collision during Godot
integration before treating the environment as game-ready.

*PRD v2 with October 23 implementation addendum; team sign-off remains above.*
