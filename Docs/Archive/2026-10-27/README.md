# October 27 PRD and chart sources

These files came from Lady D's
[Add Multi-Agent PRD v1, architecture charts & platform character](https://github.com/D-Stukes/pursuit-game-multi-agent-system/pull/11),
original head `1930249`. They preserve her source material. The
[active project plan](../../Project-Plan.md) is the only current PRD and
[Agent-Flow.md](../../Agent-Flow.md) defines the working interaction contract.

| Source | Disposition |
| --- | --- |
| [Original Word PRD](Pursuit-The-Journey-Multi-Agent-PRD-NetNewBuild-v1.docx) | Preserved unchanged. Audience, verified-state boundaries, capability descriptions and eval cases were reconciled into the active documents. This is not a second active PRD. |
| [Architecture image](agent-architecture.png) | Preserved unchanged as a historical presentation snapshot. It uses the former title/Greeter name and shows Helper/Scorekeeper reward behavior that is superseded by the active rules. |
| [Flow image](agent-flow.png) | Preserved unchanged as a presentation snapshot. Read the active flow contract for retry, write permissions and Helper return semantics. |

## Reconciled rules

- Keep starting energy 10 and cost 1 per incorrect submission. Restate after
  the first error, offer stronger help after the second, and advance immediately
  on a verified correct answer. The draft's approximate five-attempt language
  is superseded, including its eval-card example.
- All handoffs go to the Orchestrator. The draft's Check-In-to-Platform example
  is not an allowed bypass. Exact payload and transport remain engineering work.
- Helper supplies guidance and returns to the unfinished task; Scorekeeper is
  read-only. Neither can award a task star or independently advance an objective.
- The first activity remains the selected checklist. Daily question banks,
  multiple providers, instructor review and a fully AI-driven Platform remain
  future design proposals, not newly adopted demo scope.
- The source's numeric engagement metrics are proposals. Its false-award rate
  is not an exception to verified, earned stars. A participation/review path is
  distinct from satisfying the three required objectives.
- Endpoint names and the source's Orchestrator prompt illustrate a possible
  interface. They do not establish working services or replace the scripted
  core selected for this demo.

## File consolidation

The unique [Mr. P character study](../../platform-character.html) lives in the
main Docs folder, with the approved Journey title. Its SVG/CSS character design
is retained; it is not a Godot character implementation or a final art approval.

The duplicate cheat sheet, October 26 additions and flow HTML were removed
from the incoming `presentation/` folder because their Git blobs match the
canonical copies already under Docs. The unrelated clinical-trial research
document was removed from this game repository's current tree. `Documents/`
and `presentation/` are therefore not additional documentation roots.

The separate older browser walkthrough contained no activity/agent logic and
used the preceding static model layout. It is superseded by the current Godot
movement playtest and was approved for retirement; its files were not imported.
