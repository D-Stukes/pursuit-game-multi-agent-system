"""Base facilitator agent: the sense -> decide -> act loop, plus the handoff
protocol every agent uses to return control to the Orchestrator.
"""
from dataclasses import dataclass


@dataclass
class Handoff:
    """What an agent returns after acting.

    done=False  -> stay active, wait for the next player input (loop again)
    done=True   -> this agent finished its turn in the scene; Orchestrator advances
    """
    done: bool
    to: str = "orchestrator"
    reason: str = ""


class Agent:
    name = "agent"
    role = "facilitator"
    zone = None            # which zone activates this agent
    exit_reasons = ()      # the reasons this agent may legitimately hand back with

    # 1) SENSE — perceive player input + shared state
    def sense(self, state, player_input):
        return {
            "input": player_input or {},
            "zone": state.zone,
            "stars": dict(state.stars),
            "energy": state.energy,
        }

    # 2) DECIDE — choose an action from the perception (role logic; override)
    def decide(self, perception):
        raise NotImplementedError

    # 3) ACT — update shared state and return a Handoff (override)
    def act(self, action, state):
        raise NotImplementedError

    # POSTCONDITION — what must be true in the shared state for this agent's
    # work to count as done. The Orchestrator checks it before advancing.
    def postcondition(self, state):
        return True

    def step(self, state, player_input):
        """Run one full turn of the loop; returns (action, handoff)."""
        perception = self.sense(state, player_input)
        action = self.decide(perception)
        handoff = self.act(action, state)
        return action, handoff
