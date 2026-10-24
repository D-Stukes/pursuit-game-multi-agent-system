"""Runnable demo: wire the Greeter's core loop through the Orchestrator.

Run from the repo root:  python3 demo/run_greeter.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.game_state import GameState
from agents.orchestrator import Orchestrator
from agents.greeter import GreeterAgent


def turn(orch, player_input, label):
    print(f"\n--- {label}  (input={player_input}) ---")
    result = orch.handle(player_input)
    if result:
        action, handoff = result
        print(f"  sense  -> player intent: {player_input.get('intent')!r}")
        print(f"  decide -> action: {action!r}")
        print(f"  act    -> handoff: done={handoff.done} reason={handoff.reason!r}")
    s = orch.state
    print(f"  state  -> zone={s.zone!r} stars={s.star_count()}/3 stoplight={s.stoplight!r}")


def main():
    state = GameState(zone="reception")
    orch = Orchestrator(state, zone_order=["reception", "classroom"])
    orch.register(GreeterAgent())
    orch.enter("reception")

    # The player first just stands there, then checks in.
    turn(orch, {"intent": None}, "Player hovers, hasn't checked in")
    turn(orch, {"intent": "check_in"}, "Player checks in as a Builder")

    print("\n=== FULL TRACE (sense -> decide -> act -> handoff) ===")
    for line in state.log:
        print("  ", line)

    print("\nFinal stars:", state.stars)
    assert state.stars["show_up"] is True, "Greeter should have awarded the Show Up star"
    assert state.zone == "classroom", "Orchestrator should have advanced after handoff"
    print("OK — Greeter loop + handoff verified.")


if __name__ == "__main__":
    main()
