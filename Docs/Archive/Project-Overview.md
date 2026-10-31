# Pursuit: The Climb — Multi-Agent Career Journey Game

> Snapshot of the former root README. See [the document review](Document-Review-2026-10-23.md) for current decisions and consolidation status. Paths and commands below are relative to the repository root.

A playable, stylized journey through the Pursuit Fellowship, built as a multi-agent systems project (Pursuit L2, Week 5). Real players (students/staff) move through the real Pursuit building while **facilitator agents** run the game's features. Current focus: **Level 1 — "The Foundation."**

**Team:** Lady D & Dennis

## Repo structure

- **`Docs/`** — design docs
  - `Pursuit-Game-PRD-v2.md` — **current PRD**, including the 3D handoff and Godot next step *(start here)*
  - `Pursuit-Game-PRD-v2.docx` — October 21 snapshot; the Markdown version includes later updates
  - `Level-1-Design-Doc.md` / `.docx` — Level 1 zones, agents, win condition
  - Ideation synthesis and brainstorm transcript — removed from the current files on 2026-10-31
  - `Pursuit-Game-PRD.md` / `.docx` — original PRD (v1, superseded by v2)
- Reference photographs remain in the team's existing shared document, outside this repository's current tracked files.
- **`Media/`** — the brainstorm voice recording (removed from the current files on 2026-10-26)
- **[building review guide](../Building-Review.md)** — current combined GLB and portable interactive HTML review; no source photos or Blender master

## Review the building

With Python 3.10+, double-click `trials/building-review/Open Review.cmd` on Windows,
or run `python trials/building-review/serve.py --open` from this repository.
The local viewer opens at <http://127.0.0.1:8767/>. Keep the terminal running.
Copy the entire `trials/building-review` folder to share just the review package.

The combined model includes the exterior, ground entry/ramp, aligned elevator
banks, second-floor reception, separate single-door room and connected double-door
classroom. Its own generated materials are embedded. No reference-photo gallery
or rendered-image gallery is included. Dimensions and unseen areas are estimates.
This static review is separate from playable Godot integration.

## Direction (locked)

- Real players; agents are **facilitators**, not opponents.
- **Level 1 only**, done well (~2 weeks).
- **Godot** engine, **stylized/animated** look (photos are reference, not photo-to-3D scans).
- Headline concept: the **Personified Platform** you overcome by learning to **use AI** — a clean multi-agent story.

## Next steps

1. Both teammates review **PRD v2** and complete the sign-off (Section 10) + accept/override the open decisions (Section 9).
2. Dennis: import the reviewed GLB into Godot, add collision and character movement, connect the elevator floor transition, and prove one reception interaction.
3. Wire the facilitator agents + the "Use AI" hidden objective.

> **Private repo.** Contains a brainstorm voice recording. Older Git commits also contain reference photographs, including people. Removing current files does not erase Git history; keep the repository private and do not redistribute those records.
