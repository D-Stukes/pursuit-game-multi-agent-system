"""The shared game state — the single 'blackboard' every agent reads and writes.

Matches the architecture doc: stars, energy, stoplight, zone. One source of
truth; agents coordinate through it rather than talking to each other directly.
"""
from dataclasses import dataclass, field

STARS = ("show_up", "do_the_work", "be_a_teammate")


@dataclass
class GameState:
    zone: str = "street"
    energy: int = 8
    max_energy: int = 8
    stoplight: str = "green"                       # green | yellow | red
    credits: int = 0
    stars: dict = field(default_factory=lambda: {s: False for s in STARS})
    log: list = field(default_factory=list)        # human-readable trace

    def award_star(self, name: str) -> None:
        if name not in self.stars:
            raise ValueError(f"unknown star: {name!r}")
        if not self.stars[name]:
            self.stars[name] = True
            self.log.append(f"★ star awarded: {name}")

    def star_count(self) -> int:
        return sum(1 for earned in self.stars.values() if earned)
