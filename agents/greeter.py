"""The Greeter — the first facilitator agent.

Role (from the architecture doc): reception. Welcomes the player at the star
floor, checks them in as a Builder, awards the 'Show Up' star, then hands
control back to the Orchestrator.
"""
from .base_agent import Agent, Handoff


class GreeterAgent(Agent):
    name = "Greeter"
    role = "reception"
    zone = "reception"

    # DECIDE: a checked-in or asking player -> welcome them; otherwise keep waiting.
    def decide(self, perception):
        intent = perception["input"].get("intent")
        if intent in ("check_in", "ask_directions"):
            return "welcome_and_check_in"
        return "await_check_in"

    # ACT: update the shared state and signal the handoff.
    def act(self, action, state):
        if action == "welcome_and_check_in":
            state.award_star("show_up")
            state.stoplight = "green"
            state.log.append("Greeter: \"Welcome in, Builder — you're checked in.\"")
            return Handoff(done=True, to="orchestrator", reason="checked_in")

        # still waiting on the player: prompt and stay active
        state.log.append("Greeter: \"Are you a guest, or a Builder here today?\"")
        return Handoff(done=False)
