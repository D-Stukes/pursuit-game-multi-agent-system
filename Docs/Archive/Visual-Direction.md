# Visual Direction — "Pursuit: The Climb"

**Date:** October 21, 2026 · **Team:** Lady D & Dennis
**Purpose:** A shared north star for how the game should *look and feel*, with references and a realistic style target for a ~2-week build.

---

## Reference games (Lady D's picks)

1. **"These awesome 3D games are made in Godot"** — [youtu.be/V57nUF7kOjs](https://youtu.be/V57nUF7kOjs)
   *Takeaway:* confirms our engine (Godot) can deliver stylized 3D. Reassurance, not a single style to copy.
2. **"The Best 3D Platformer You've Never Heard Of"** — [youtu.be/RBem9q6bFKQ](https://youtu.be/RBem9q6bFKQ)
   *Takeaway:* we want **explorable 3D movement** — walk/run through spaces, third-person camera, colorful worlds.
3. **"The Room" (Fireproof Games)** — [youtu.be/Kth0qrrKb90](https://youtu.be/Kth0qrrKb90)
   *Takeaway:* **tactile, atmospheric puzzle interaction** — moody lighting, rich detail, picking up and manipulating objects. This is essentially our "Living Room / puzzle room" idea from the brainstorm.

## The throughline

**Stylized 3D with real atmosphere** = explorable spaces (platformer) **+** close-up, tactile puzzle moments (The Room). Third-person camera so the player sees the world and their avatar.

## Realistic style target (so we can actually ship)

- The *feeling* of these is very achievable in Godot. The *fidelity* of The Room is a professional studio's multi-year work — not a 2-week target.
- **Strategy: nail one thing beautifully.** Build **one atmospheric Pursuit room** with good lighting and **one tactile mini-game**, plus simple walkable movement between zones. That captures both references at a shippable scope.
- **Where art effort goes:** one "hero room" (lighting + a tactile puzzle) rather than every zone at high fidelity.

## Look & feel notes (carried from the design docs)

- **Palette:** Pursuit navy + white, neon-cyan accents (the infinity sign), warm wood + colorful art, red landmark props (the trash can).
- **Signature:** exposed silver ducts + red sprinkler pipes, the ★1 elevator, neon "Pursuit."
- **Characters:** generic stylized avatars (no real individuals).
- **Camera:** third-person.
- **Mood:** warm, encouraging, a little playful — not sterile.

## Build path

1. **Web prototype (done)** — the gameplay skeleton (stars, Platform, Use-AI, energy). Proves the *fun*.
2. **Godot blockout (next)** — a real walkable 3D room with one mini-game, using simple shapes + good lighting. Proves the *feel*.
3. **Art pass (later)** — replace blockout shapes with stylized models/textures toward the references above.

> Reality note: the Godot "first level" starts as a **blockout** (simple shapes standing in for final art). It's real, walkable 3D with a working mini-game — the right first step. The beauty comes in the art pass.

---

## Character & feature notes (added)

- **THE PLATFORM is purple** (the real Pursuit platform is purple). Character concept: a **purple character** — either a *guy with a hat, a mustache, and a sinister smile*, or a **purple Casper-style ghost**. Playful-menacing. (Blockout version in the Godot level is a floating purple ghost with a hat.)
- **Keypad door entry (planned mini-game):** the building's real door has a **silver number-pad panel** — enter the correct code to open the door. Game idea: the player must **play a mini-game to earn/reveal the code**, then punch it into a realistic keypad to proceed. A great "gate" mechanic between zones. *(Design in progress — see open question below.)*

