# Level 1 Design Doc
## "Pursuit: The Climb" — Level 1: The Foundation

**Authors:** Lady D & Dennis
**Date:** October 21, 2026
**Course:** Pursuit L2 — Week 5, Multi-Agent Systems
**Status:** Draft v1 (Level 1 scope)
**Engine:** Godot (free, open-source) · stylized / animated look
**Reference art:** `/Images/` and `/Images/walkthrough_upload/` (photos of the real Pursuit space)

---

## 1. Locked Direction (recap)

- **Players are real people** — students or Pursuit staff.
- **Agents are facilitators** — they run the game's actions and features; they are NOT opponents to beat.
- **Scope: Level 1 only**, done really well.
- **Stylized look**, built in **Godot**, using our photos as *reference* (not photo-to-3D scanning).
- **Setting:** the real Pursuit building journey — exterior → ground floor → elevator → the Pursuit "star" floor → classroom.

### The motif we discovered
The building's own elevator panel has a literal **"★1"** button (a star next to floor 1). We make that the heart of Level 1: **reaching the star floor and earning your stars = clearing Level 1.** The elevator star lighting up is the "you passed" beat.

---

## 2. Level 1 Goal (Win Condition)

Level 1 mirrors Cycle 1 at Pursuit: **show up, do the work, be a good teammate.** In game terms, the player must **earn 3 stars** by completing the Foundation objectives, then ride the elevator's ★ floor to graduate to Level 2 (future scope).

**The 3 Stars of the Foundation:**
1. ⭐ **Show Up** — arrive and check in (attendance).
2. ⭐ **Do the Work** — complete the Foundation build task.
3. ⭐ **Be a Teammate** — help/collaborate with a peer.

Plus an optional **hidden bonus** (courage reward) for brave/proactive actions.

---

## 3. The Journey — Zones (walk-through order)

Each zone is a stylized Godot scene the player walks through. Landmark props (pulled from the photos) make each instantly recognizable as Pursuit.

| # | Zone | Real reference | Key stylized props | Purpose / gameplay |
|---|------|----------------|--------------------|--------------------|
| 1 | **The Street** (Exterior) | `building1-3`, LIC skyline (`11`) | Zipper Building facade, big windows, autumn trees, NYC towers | Spawn point. Establishing shot. Walk to the entrance. |
| 2 | **Ground Floor Entry** | `1/2` (vending, stairs, ramp, yellow door) | Pepsi/snack machines, stairs + accessibility ramp, **yellow glass door** | Movement tutorial. Choose stairs or ramp. Reach the elevator. |
| 3 | **Elevator Bank + Cab** | `15-21` | Grey doors, waste/recycle bins, **★1 button panel**, mirrored cab | Press **★1**. Short transition ride (loading / anticipation beat). |
| 4 | **The Star Floor — Reception** | reception shots (neon Pursuit sign, "Guests/Builders" desk) | Blue walls, **neon infinity "Pursuit" sign**, reception desk, egg chair, "Workflow Wednesday" welcome TV | **Check in as a Builder** → earns ⭐ #1. Meet the Greeter agent. |
| 5 | **The Lobby / Commons** | `lobby_area1-5` | Exposed silver ducts, sofas, abstract art, **iconic red trash can**, egg chair | Transition + social beat. Meet a peer NPC. Signage guides you. |
| 6 | **The Classroom** (gameplay hub) | `classroom1-4`, `8/9/11` | Long desks, black rolling chairs, grey carpet, **projector screen**, whiteboard, breakout room | Core of Level 1: the Foundation build task (⭐ #2) + teamwork beat (⭐ #3). |

---

## 4. The Facilitator Agents

Level 1 uses **3 facilitator agents** (matching our "start small, 3 agents" scope), each running a feature of the game. They guide and react — they never block the player as enemies.

### Agent 1 — The Greeter (Reception)
- **Where:** Zone 4, the "Guests / Builders" reception desk.
- **Role:** Welcomes the player, explains Level 1's goal, checks them in as a Builder.
- **Awards:** ⭐ #1 (Show Up).
- **Personality:** warm, upbeat, "All day, every day" energy.

### Agent 2 — The Facilitator (Classroom)
- **Where:** Zone 6, at the front desk by the projector.
- **Role:** Runs the Foundation build task, gives instructions, reacts to the player's work, prompts the teamwork moment.
- **Awards:** ⭐ #2 (Do the Work) and sets up ⭐ #3.
- **Personality:** encouraging teacher/coach — coaching, not grading.

### Agent 3 — The Scorekeeper / Guide (ambient)
- **Where:** everywhere — the HUD and signage.
- **Role:** Tracks stars and progress, runs the **stoplight meter** (🟢/🟡/🔴 feedback), drops wayfinding hints, and triggers the **hidden courage bonus**.
- **Awards:** manages star totals; grants the hidden bonus.
- **Personality:** friendly narrator / "building system" voice.

> **Why this is a multi-agent system:** three independent facilitator agents with distinct jobs (welcome/check-in, teach/evaluate, track/guide) coordinate to move one real player through the level. Later levels add more agents (mentor, interviewer, recruiter, stakeholder).

---

## 5. Level 1 Gameplay Flow

1. **Spawn on the street** → walk to the Zipper Building entrance.
2. **Ground floor** → learn to move; take stairs or ramp; reach the elevator.
3. **Elevator** → press **★1**; short ride (anticipation).
4. **Reception** → the **Greeter** checks you in as a Builder → **⭐ Show Up**.
5. **Lobby** → meet a peer NPC; the **Scorekeeper** points you to the classroom.
6. **Classroom** → the **Facilitator** gives the **Foundation build task**:
   - A short, friendly mini-activity (e.g., assemble/arrange something at your desk, answer a couple of onboarding prompts) → **⭐ Do the Work**.
   - A **teamwork beat**: help a peer NPC who's stuck → **⭐ Be a Teammate**.
7. **Hidden courage bonus** (optional): if the player does something brave/proactive — e.g., **volunteers to present first** or raises their hand — a Mario-style **invisible block** pops a surprise reward (credits / a "Builder badge").
8. **3 stars earned** → the **Scorekeeper** celebrates; the elevator's **★ floor** indicator lights up → **Level 1 complete** (Level 2 teaser).

### Stoplight feedback (always visible)
- 🟢 on track · 🟡 needs attention (missed a step) · 🔴 stalled (nudge from Scorekeeper).
- In Level 1 the stoplight is gentle/encouraging — it coaches rather than punishes.

---

## 6. Art & Style Direction

- **Overall:** stylized / animated (clean shapes, warm lighting) — not photoreal, not full cartoon.
- **Signature elements to carry everywhere:** exposed **silver ducts + red sprinkler pipes**, **blue + white** walls, Pursuit branding (logo, neon infinity sign, "All day, every day," "Lives transformed"), warm wood + colorful abstract art accents.
- **Landmark props** (make each zone recognizable): yellow glass door, red cylinder trash can, egg chair, vending machines, ★1 elevator panel, neon Pursuit sign, projector screen.
- **Characters:** generic stylized avatars. **Do NOT model real individuals** from the photos (privacy) — the people shots are vibe/pose reference only.

---

## 7. Build Notes (Godot)

- **Scenes:** one Godot scene per zone (6 total); a simple player controller (first- or third-person) walking between them; elevator = scene transition with a short timed ride.
- **Agents:** start as **dialogue + trigger systems** (facilitator logic) — a state machine per agent (Greeter / Facilitator / Scorekeeper). They can later be wired to an LLM for dynamic dialogue; for the MVP, scripted branching is fine and safer to demo.
- **Stars & stoplight:** a small global game-state script (autoload) tracks the 3 stars and the stoplight; the Scorekeeper reads/writes it.
- **Hidden block:** an invisible Area node in the classroom that triggers on the "volunteer/present" action.

---

## 8. Scope Guardrails (so Level 1 actually ships)

**In scope:** 6 walkable zones, 3 facilitator agents (scripted), 3 stars, stoplight HUD, 1 hidden bonus, elevator transition, stylized art pass.
**Out of scope for now:** multiple levels, LLM-driven agents, interviewer/recruiter/stakeholder, full Penthouse, multiplayer, photoreal rendering.

---

## 9. Open Questions

1. **Camera/controls:** first-person walk, or third-person character? (Third-person shows off the stylized avatar.)
2. **Foundation build task:** what exactly is the "Do the Work" mini-activity? (Keep it ~1–2 minutes.)
3. **Agents:** scripted dialogue for the MVP, or wire one agent to an LLM to show "real" multi-agent behavior for the class?
4. **Hidden bonus trigger:** which brave action fires it — volunteering to present, raising a hand, or both?
5. **Reward currency:** what do we call it (credits? "stipend"?) and what does it do in Level 1?

---

*End of Level 1 Design Doc v1 — ready for team review.*
