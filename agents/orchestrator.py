"""The Orchestrator — the coordinator from the architecture diagram.

It activates one agent per zone and handles handoffs: when the active agent
reports done, it advances to the next zone in the journey.
"""


class Orchestrator:
    def __init__(self, state, zone_order):
        self.state = state
        self.zone_order = zone_order      # e.g. ["reception", "classroom"]
        self.agents = {}                  # zone -> Agent
        self.active = None

    def register(self, agent):
        self.agents[agent.zone] = agent
        return self

    def enter(self, zone):
        self.state.zone = zone
        self.active = self.agents.get(zone)
        who = self.active.name if self.active else "None"
        self.state.log.append(f"Orchestrator: activated {who} in zone '{zone}'")
        return self.active

    def handle(self, player_input):
        """Route one player input to the active agent; advance on handoff."""
        if not self.active:
            return None
        action, handoff = self.active.step(self.state, player_input)
        if handoff.done:
            if self._verify(handoff):
                self.state.log.append(
                    f"Orchestrator: accepted handoff from {self.active.name} ({handoff.reason})"
                )
                self._advance()
            else:
                self.state.log.append(
                    f"Orchestrator: REJECTED handoff from {self.active.name} "
                    f"(to={handoff.to!r}, reason={handoff.reason!r}) — staying put"
                )
        return action, handoff

    def _verify(self, handoff):
        """Verify a handoff before advancing. Three checks:
        1. it's addressed to the orchestrator,
        2. the reason is one the agent is allowed to exit with,
        3. the agent's postcondition actually holds in the shared state.
        """
        agent = self.active
        return (
            handoff.to == "orchestrator"
            and handoff.reason in agent.exit_reasons
            and agent.postcondition(self.state)
        )

    def _advance(self):
        try:
            i = self.zone_order.index(self.state.zone)
        except ValueError:
            return
        if i + 1 < len(self.zone_order):
            self.enter(self.zone_order[i + 1])
        else:
            self.state.log.append("Orchestrator: level complete")
            self.active = None
