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
            self.state.log.append(
                f"Orchestrator: {self.active.name} handed back ({handoff.reason})"
            )
            self._advance()
        return action, handoff

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
