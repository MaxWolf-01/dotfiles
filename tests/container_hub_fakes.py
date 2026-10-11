"""The container hub's module, loaded in a test's process, and the clock it reads there.

bin/container-hub reads the wall clock through its `time` module, and a test hands it a Clock instead. HOME the
module reads once, as it loads, so a test moves HOME before it loads one. The rest that main() sets from its flags
before it serves, the test sets as it needs: `load` sets the state directory, and a test that types into tmux sets
TMUX_SOCKET and CLEAR_WAIT. A module loaded anew on the same state is the hub restarted, as far as what it keeps on
disk goes: main()'s own start-up (the old containers moved in, each unit repaired) runs only in a hub process.
"""

import itertools
import time
from pathlib import Path

from check import bin_module  # tests/ is on sys.path in every test that imports this

LOADS = itertools.count()


class Clock:
    """The hub's `time`: the wall-clock time is the test's to set, and the rest is `time` as it is, so the hub's
    waits still wait."""

    def __init__(self, now: float):
        self.now = now

    def time(self) -> float:
        return self.now

    def tick(self, seconds: float = 1) -> float:
        self.now += seconds
        return self.now

    def __getattr__(self, name: str):
        return getattr(time, name)


def load(clock: Clock, state: Path):
    """bin/container-hub as a module of its own, on its clock, keeping its units under `state`."""
    module = bin_module("container-hub", f"container_hub_{next(LOADS)}")
    module.time, module.STATE = clock, state
    return module
