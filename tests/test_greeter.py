"""Tests for the Greeter agent's loop and the no-early-handoff guarantee.

Run from the repo root:  python3 tests/test_greeter.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.game_state import GameState
from agents.orchestrator import Orchestrator
from agents.greeter import GreeterAgent


def _fresh():
    state = GameState(zone="reception")
    orch = Orchestrator(state, zone_order=["reception", "classroom"])
    orch.register(GreeterAgent())
    orch.enter("reception")
    return state, orch


def test_waits_when_player_never_checks_in():
    """Idle turns must NOT hand off early."""
    state, orch = _fresh()

    # The player hovers for several turns without checking in.
    for _ in range(3):
        action, handoff = orch.handle({"intent": None})
        assert action == "await_check_in", action
        assert handoff.done is False, "must not hand off while waiting"

    # A random/unknown intent must also not trigger a handoff.
    action, handoff = orch.handle({"intent": "order_pizza"})
    assert handoff.done is False, "unknown intent must not hand off"

    # Nothing advanced, no star, Greeter still on duty.
    assert state.stars["show_up"] is False, "no star without check-in"
    assert state.zone == "reception", "must not advance without check-in"
    assert orch.active is not None and orch.active.name == "Greeter"
    print("PASS test_waits_when_player_never_checks_in")


def test_advances_only_after_check_in():
    state, orch = _fresh()
    # idle first...
    orch.handle({"intent": None})
    assert state.zone == "reception"
    # ...then check in -> star awarded, verified handoff, advance.
    action, handoff = orch.handle({"intent": "check_in"})
    assert action == "welcome_and_check_in"
    assert handoff.done is True and handoff.reason == "checked_in"
    assert state.stars["show_up"] is True
    assert state.zone == "classroom", "should advance after a verified check-in"
    print("PASS test_advances_only_after_check_in")


if __name__ == "__main__":
    test_waits_when_player_never_checks_in()
    test_advances_only_after_check_in()
    print("\nAll Greeter tests passed.")
