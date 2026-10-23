# Monday Design Pitch — "Pursuit: The Climb"

**Team:** Lady D & Dennys
**Format:** design pitch (not a product demo) · **hard cap 3–4 min** · budgeted **~3 min 30 sec**

---

## 1. Timed outline (who says what, in what order)

| # | Section | Speaker | Time | Key points |
|---|---------|---------|------|------------|
| 1 | Hook + industry / functional area (why) | **Lady D** | 35s | Edtech / workforce development; functional area = career-readiness & onboarding. Why: we live it, roles map to agents, progress is measurable. |
| 2 | The PRD in one breath | **Lady D** | 30s | Real players climb the Pursuit journey to "getting hired." Agents are facilitators, not opponents. Scope: Level 1 only. |
| 3 | The agents & their roles | **Dennys** | 45s | Orchestrator, Greeter, The Platform, AI Helper, Scorekeeper — one line each. |
| 4 | Architecture + handoff protocol | **Dennys** | 45s | Orchestrator + shared-state blackboard; sense→decide→act loop; handoff `{done, to, reason}`, verified by postcondition before advancing. |
| 5 | Workflow choice & reasoning | **Lady D** | 25s | feature → develop → main with PRs; protects main, forces review, keeps secrets out. |
| 6 | Why this will work + close | **Both** | 30s | Real domain, scalable architecture, working first agent + playable prototype. End on the link. |

**Covers all required elements:** industry/area + why ✓ · PRD ✓ · each agent's role ✓ · handoff protocol ✓ · architecture diagram ✓ · workflow + reasoning ✓ · why it will work ✓ · under 4 min ✓

---

## 2. Word-for-word script (~3.5 min)

**[1 · Lady D — Hook & industry]**
"Hi, we're Lady D and Dennys. We built a game of the thing we're actually living. Our industry is **education and workforce development** — edtech — and our functional area is **career-readiness and onboarding**. We chose it because we know this world firsthand, the people in it map cleanly to software agents, and 'did the learner progress?' is something you can actually measure."

**[2 · Lady D — PRD]**
"The product is **Pursuit: The Climb**. Real people — students or staff — play. They climb the real Pursuit journey toward the goal every Fellow shares: **getting hired**. The AI pieces are **facilitators**, not enemies — they run the experience. For now we scoped it to **Level 1**, done well."

**[3 · Dennys — Agents]**
"We have five agents. The **Orchestrator** decides which agent is active for your current zone. The **Greeter** checks you in. **The Platform** runs the classroom — it's our antagonist-helper that floods you with questions. The **AI Helper** is the lifeline you unlock by learning to use AI. And the **Scorekeeper** turns the game state into what you see — stars, energy, the stoplight."

**[4 · Dennys — Architecture & handoff]**
"Here's the architecture. It's an **orchestrator plus a shared-state blackboard** — every agent reads and writes one game state. Each agent runs the same loop: **sense, decide, act**. When an agent finishes, it sends a **handoff** — a small message with `done`, `to`, and a `reason`. The Orchestrator doesn't just trust that flag: it **verifies the agent's postcondition** — did the work actually happen — before it advances. Our Greeter, for example, only hands off once the 'Show Up' star is really awarded."

**[5 · Lady D — Workflow]**
"On process, we work the real-world way: each feature on its own branch, a **pull request into `develop`**, and only tested code reaches **`main`**. It protects main, forces review, and keeps secrets safe — we ignored `.env` before we ever had a key. And here's the nice part: **our agents hand off and verify each other's work before moving on — the same way our PRs get reviewed before they merge.**"

**[6 · Both — Why it works & close]**
"We believe this works because it's grounded in a domain we understand, the architecture **scales** — we can add the mentor, interviewer, and recruiter agents without changing the loop — and we're not theorizing: we already have a **working first agent** and a **playable prototype**. We'd love to show you. Thanks!"

---

## 3. Delivery notes
- **Swap speakers freely** — just keep each handoff to the other person clean (a one-line cue: "Dennys will take the architecture").
- **Show, don't read:** put the **architecture diagram** on screen for sections 3–4, and have the **game link** ready for the close.
- **Pace:** ~140 words/min. If you're running long, cut the agent one-liners to just names + the Platform.
- **The wow line** (section 5) is your strongest moment — say it slowly.
