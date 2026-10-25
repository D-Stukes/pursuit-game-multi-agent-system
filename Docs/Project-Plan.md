# Pursuit The Climb project plan

**Working plan · Updated October 24, 2026 · Team: Lady D and Dennis**

This is the active plan for Level 1, The Foundation. It combines the earlier
project sources with Dennis's October 23 decisions. Use this file for current
scope; the [archive](Archive/README.md) retains earlier ideas, decision records
and original sign-offs. This consolidation does not add a new Lady D sign-off.

## Goal and player journey

Build a stylized Godot game in which real players experience the start of the
Pursuit journey: show up, do the work and help a teammate. Facilitator agents
run the experience. Getting hired is the wider story; this build covers Level 1.

The route is street → ground entrance → stairs/right ramp → elevator forecourt
→ second-floor reception → commons/hallway → classroom. The brown doors enter
a small room, with a larger area to its left and the elevators behind it facing
toward the ramp. Reception's single door leads to a separate room; its double
doors lead to the classroom. Physical floor numbers and game Level 1 are distinct.

## Current assets and next milestones

The combined building GLB and interactive reviewer are available in
`trials/building-review/`. The building was manually modeled in Blender from
photo references and firsthand layout corrections. Unseen areas and dimensions
remain estimates. The unchanged model now has a Godot movement/camera playtest
with generated collision and a CC0 animated test avatar. Agent interactions and
Foundation objectives still need integration.
The Godot scene also has a decorative exterior streetscape and bounded entrance
sidewalk; neighboring buildings are scenery rather than another playable area.
The [building review guide](Building-Review.md) covers launch, asset identity
and verification limits.

The repository retains the web prototype and original Godot blockout. The
synchronized development baseline includes Python Greeter/Orchestrator code from
`develop@9c38b3f`; its two existing Greeter tests pass. It is not yet wired into
the Godot playtest.

1. **Prove the playable route.** Import the GLB into Godot with its materials and
   scale; add third-person movement and simple collision. Traverse the entrance
   and ramp, use an explicit elevator floor transition, reach reception and the
   correct classroom doorway, and complete one Greeter check-in interaction.
   Check-in awards its star once. A simulated elevator ride is optional.
   The camera/avatar movement proof is implemented; the Greeter check-in remains
   a separate integration step.
2. **Prove the Foundation loop.** Add the scripted Platform task, the AI Helper
   moment, a peer-help action, stars, energy and stoplight feedback. Demonstrate
   both a successful live Helper response and the scripted fallback.
3. **Polish the same slice.** Validate doorway clearance, collision, camera,
   readability, performance and restart behavior before expanding scope.

## Five roles and hybrid dialogue

| Role | Responsibility and boundary |
| --- | --- |
| Orchestrator | Select the active role and verify handoffs before progression. A `done` flag alone is not proof. |
| Greeter | Handle reception check-in and its completion condition. |
| Platform | Present the scripted Foundation task and verify task/peer-help actions. Live Platform dialogue is deferred. |
| AI Helper | Provide useful guidance through one live call at the demo's help moment, with scripted fallback. Its text cannot authorize rewards or progression. |
| Scorekeeper | Present stars, energy, stoplight and approved progress from shared game state. |

Five roles do not require five LLM calls. Greeter, Platform, coordination and
scoring stay scripted for this demo. The live provider, bounded timeout and
Godot/Python integration boundary must be selected during implementation.

### Next player interaction: reception check-in

After entering, taking the ramp and using the elevator transition, the player
approaches the reception desk. The next implementation slice is an explicit
interaction prompt, scripted Greeter welcome, and a **Check in as a Builder**
choice. Confirming check-in records its completion, awards Show Up once, and
updates the objective to reach the classroom. Asking for directions or closing
the conversation must leave that star unearned. Revisiting the desk must not
award it again. The existing Python Greeter currently treats `ask_directions`
as check-in; reconcile that behavior before connecting it to the game.

The rest of the planned loop is classroom Platform task → optional AI Helper
guidance → verified task completion → peer-help action → three-star completion.
Dennis selected the existing checklist activity for the first Platform task:
identify **Show up / check in**, **Submit your project**, and **Help a teammate**
among the distracting busywork options. Submitting the correct set completes
this short Foundation task and earns Do the Work once. An incorrect set keeps
the task active and lets the player retry; AI Helper guidance is optional.
Selecting the peer-help checklist item does not complete the separate Be a
Teammate objective. That objective still needs an observable peer-help action.
This exterior update does not implement dialogue, change rewards, or select a
live AI provider.

## Gameplay rules

- **Show Up:** earn one star by completing check-in.
- **Do the Work:** earn one star by completing the short Foundation task, with
  or without Helper guidance. Clicking Use AI alone does not earn this star.
- **Be a Teammate:** earn one star by completing a peer-help action.
- Complete all three objectives to finish Level 1. The elevator star indicator
  can mark completion; another playable level is outside this build.
- Keep the simple energy meter and coaching stoplight. Exact energy values,
  recovery rules and strength bonuses still need balancing.
- Retain five strength choices: Great Communication, Tech Savvy, Coding
  Experience, AI Experience and Newbie + Curiosity. Defer outfits and a separate
  character-stat system.
- Discovering Use AI can reveal the hidden objective. Any bonus is separate
  from the three required stars and must not bypass their completion conditions.

## Handoffs and failure behavior to implement

Use one shared game state. Recommended implementation: one reward API enforces
one award per objective; Greeter validates check-in, Platform validates task and
peer-help completion, Orchestrator verifies transitions, and Scorekeeper displays
the result. Reconcile this contract with the existing develop code before reuse.

Retain the existing `{ done, to, reason }` handoff concept and specify the session,
event/objective identifier, expected state and completion evidence around it.
Validate the recipient, allowed exit reason and actual postcondition. Repeated
events must not award duplicate stars. Game code verifies actions; LLM output
is guidance rather than authoritative state.

If input or a handoff is missing, ambiguous or invalid, keep the current objective
and show the specific next action. Bound the Helper request and use scripted
guidance on timeout, provider error or unusable output. Avoid unbounded retries;
a provider failure should not penalize the player or prevent completion through
the fallback. Keep API credentials outside the client and versioned files.

## Art and scope boundaries

Use Blender → GLB → Godot for the playable environment, and Three.js for review.
Retain the connected classroom and accepted building layout. Use original
stylized avatars, warm lighting, navy/white/cyan, wood, exposed ducts and red pipes
as the visual direction. Reference photographs stay outside the shared package;
the model's generated embedded materials stay with the GLB.

The first Godot gameplay demo focuses on the Foundation/Platform/Helper loop.
The existing web Bug Blaster remains an optional prototype activity. Porting it,
adding the keypad gate, extra levels, full avatar customization, additional agent
roles and fully live Platform dialogue are deferred. Photogrammetry experiments
and the discarded photo-textured room are not the current build path.

## Remaining implementation choices

Implement the selected Foundation checklist task; specify the observable peer-help action, the handoff
schema and reward API, Helper provider/timeout, energy/bonus balance and the
Godot-to-agent connection. Verify these through the milestones above. The earlier
two-week estimates and Monday-pitch wording are historical planning assumptions,
not a newly confirmed deadline or proof of completion.

Update this plan when decisions change. Use the
[October 23 decision review](Archive/Document-Review-2026-10-23.md) and
[archive index](Archive/README.md) for provenance, rather than reviving an older
PRD as a competing active specification. Refresh the pitch after the implementation
claims are verified.
