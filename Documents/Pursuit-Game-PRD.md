# Product Requirements Document (PRD)
## "Pursuit: The Climb" — A Multi-Agent Career Journey Game

**Authors:** Lady D & Dennis
**Date:** October 19, 2026
**Course:** Pursuit L2 — Week 5, Multi-Agent Systems
**Status:** Draft v1 (for review & scoping)

---

## 1. One-Line Pitch

A playable journey through the Pursuit Fellowship, where you climb from brand-new student (L1) all the way to **the Penthouse** — the final interview level where you get hired. Each level is guarded by AI **character agents** (mentors, interviewers, recruiters, stakeholders) that you have to win over to earn your stars and move up.

---

## 2. Vision & Why It Matters

Pursuit is serious and life-changing — but the journey can feel long and intimidating. This game turns that same journey into something **fun, fast, and encouraging**, while still mirroring the real thing closely enough that a Fellow who plays it is actually *rehearsing* for the real experience.

The magic trick we're going for: **make it a real game (surprises, rewards, levels, stars) AND an honest reflection of the Pursuit path.** If it doesn't feel like Pursuit, there's no reason to call it the Pursuit game. If it isn't fun, nobody rehearses.

**Design tension (stated on purpose):** We are taking something very serious and important and making it playful without making it trivial. Every fun mechanic should map to a real Pursuit value: courage, preparation, teamwork, adaptability, communication.

---

## 3. Core Goal (The Win Condition)

**Graduate the program and get hired.** The player completes each cycle (level), earns enough stars, and reaches the Penthouse — the final hiring level that only skilled players can pass.

---

## 4. The Climb — Level Structure

Think of it like a building. You start on the ground floor as a new student and climb to the Penthouse. (Not a literal board game — the "building" is just the mental model.)

| Level | Real Pursuit Stage | What the Player Does | Agents You Meet |
|-------|--------------------|----------------------|-----------------|
| **L1 — The Foundation** | Cycle 1: You're a new student | Show up, complete your work, keep good attendance, be a good teammate | Peer / Teammate agent (checks collaboration) |
| **L2 — The Builder** | Learning to build (agents!) | Complete a **mini-game: build a mini-agent** inside the game; check in with your Mentor | **Mentor agent** |
| **L3 — The Real World** | Internship-style project | Do a real project: talk to your **Interviewer**, your **Recruiter**, and your **Stakeholder** (the person you're building the business for) | Interviewer, Recruiter, Stakeholder agents |
| **🏆 The Penthouse** | Getting hired | Final boss interview(s). Only players with skill, style, and conversational wisdom pass. | Hiring Manager (+ possibly CIO for senior roles) — *stretch goal* |

### Level pass criteria (draft)

- **L1 — The Foundation:** Complete most/all assigned work, maintain attendance, demonstrate you can work with others. *(We noted there may be more criteria — placeholder to expand.)*
- **L2 — The Builder:** Successfully build a mini-agent in the mini-game, and have a productive mentor check-in.
- **L3 — The Real World:** Deliver a project while satisfying three agents: convince the Interviewer, impress the Recruiter, and keep the Stakeholder happy.
- **Penthouse:** Win the final interview under pressure, adapting to whoever is across the table.

### Stars
Each agent you satisfy awards **stars**. Collect enough stars on a level to unlock the next level. (Star thresholds TBD per level.)

---

## 5. The Agents (Multi-Agent System — the heart of the project)

Two families of agents:

### A) Character / "Guardian" Agents — the people you talk to
Each is a distinct persona with its own goals, questions, and standards.

1. **Teammate / Peer Agent (L1)** — evaluates collaboration, attendance, reliability.
2. **Mentor Agent (L2)** — guides, asks reflective questions, encourages growth.
3. **Interviewer Agent (L3 + Penthouse)** — asks role-specific questions, probes depth.
4. **Recruiter Agent (L3)** — screens for fit, communication, enthusiasm, logistics.
5. **Stakeholder Agent (L3)** — the "client" you're building for; cares about outcomes and whether you understood their needs.

> **Scope note:** We *think big* here (many possible agents) but **start with 3 agents** for the first build, and let the AI help us narrow scope before expanding. Recommended starting three: **Mentor, Interviewer, Recruiter** (or Interviewer, Recruiter, Stakeholder for L3). See Section 9.

### B) Judge / Scoring Agent — the "referee" behind the scenes
A separate agent (or scoring layer) that watches the conversation and rates the player using the **stoplight system** and the **factors** below. This keeps character agents in-character while a neutral judge handles scoring.

### Each character agent should adapt to WHO is being played
A key insight from ideation: a smart player adjusts how they talk depending on **who** they're talking to — a Recruiter vs. a Manager vs. a CIO. The game should reward that awareness.

---

## 6. Scoring System — The Stoplight

Real-time feedback as a traffic light:

- 🟢 **Green** — You're doing well.
- 🟡 **Yellow** — On the fence / warning.
- 🔴 **Red** — About to be bumped out as a candidate.

### Factors we score (the "what good looks like")

1. **Role Knowledge** — Do they understand the role they're applying for?
2. **Skill Level** — Do they demonstrate the actual ability?
3. **Audience Intuition (Adaptability)** — Do they read the room and adjust to the *kind* of interviewer (recruiter vs. manager vs. CIO)?
4. **Communication Style** — graded on a spectrum, not just right/wrong:
   - Rambling ↔ Direct
   - Wooden/plain ↔ Engaged & interesting
   - Under-engaged ↔ **Overly** engaged (too much is also a penalty)
   - *Ideal: direct AND comfortable AND genuinely engaging — not just correct.*

> The scoring should feel like coaching, not just a grade — the goal is to help Fellows rehearse real conversations.

---

## 7. The Fun Layer — Surprises & Hidden Games

What makes it a *game*, not a quiz:

- **Mario-style invisible blocks:** Hidden rewards that pop out of nowhere when the player does something brave or proactive. Examples:
  - Raising your hand to **present first** in front of the class → 💥 bonus appears.
  - Volunteering for a **hackathon** → surprise reward.
  - Taking initiative / showing courage → hidden bonus.
- **Rewards:** credits, a "stipend" (a game-invented currency — doesn't exist in real Pursuit, we'd make it up), stars, or power-ups.
- **A game-within-a-game:** a small, fun, *unrelated* mini-challenge tucked inside a level — short but challenging enough to be satisfying. (L2's "build a mini-agent" is one mini-game; the hidden mini-game is a separate, lighter surprise.)

**Design principle:** every surprise reward should quietly reinforce a real Pursuit behavior (courage, initiative, participation).

---

## 8. Look & Feel (Aspirational)

- **3D characters with 3D bodies** — each agent is embodied as a 3D character you walk up to and talk with.
- Building-climb visual metaphor (floors → Penthouse).
- Stoplight indicator always visible during conversations.

> **Reality check for scope:** full 3D is a significant lift. Recommended path: prove the **agent conversations + scoring** first (text or simple 2D), then layer in 3D characters as a stretch goal. See Section 9.

---

## 9. Scope & Phasing (Recommended)

We want to *think big but start small.* Proposed phases:

**Phase 1 — Playable Core (MVP)**
- 3 character agents + 1 judge/scoring agent.
- One fully playable level (suggest **L3** or a simplified **Penthouse interview**) to prove the multi-agent + stoplight loop.
- Text-based conversation, stoplight feedback, stars awarded.

**Phase 2 — The Climb**
- Add L1 and L2, including the L2 "build a mini-agent" mini-game.
- Add level progression and star gates.
- Add 1–2 hidden "invisible block" surprise rewards.

**Phase 3 — Polish & Delight**
- 3D characters/bodies, richer environments.
- More agents (Stakeholder, CIO, etc.), the full Penthouse boss.
- More hidden games and rewards.

---

## 10. Open Questions (for the team + Claude to resolve)

1. **Tech stack:** Python + Claude API? A web app? A game engine (Unity/Godot) for the 3D later? What are we building the MVP in?
2. **First 3 agents:** Confirm which three we start with — Mentor + Interviewer + Recruiter, or the L3 trio (Interviewer + Recruiter + Stakeholder)?
3. **Scoring:** Does the Judge agent score live after every answer, or at the end of each conversation?
4. **Which level is the MVP?** Build L3 first (most agent-rich) or a slimmed Penthouse?
5. **Win thresholds:** How many stars per level? How many strikes (reds) before you're bumped?
6. **Currency:** What do we call the game stipend/credits, and what do they unlock?
7. **Replayability:** Can players retry a failed conversation, or is it one shot per run?

---

## 11. Why This Is a Strong Multi-Agent Project

- **Genuine multi-agent coordination:** multiple persona agents + a judge/referee agent + a game-flow controller.
- **Agents with distinct goals** that the player must satisfy differently — the core multi-agent systems concept, made vivid.
- **Meaningful, real-world domain** the whole class understands firsthand.
- **Clear scope ladder** from a 3-agent MVP to an ambitious 3D vision.

---

*End of Draft v1. Ready for team review — mark it up and we'll iterate.*
