"""What every Python test file shares. A file under tests/ puts that directory on sys.path and imports it.

Examples are checked with check() and settles(), properties registered with prop() and run by run_properties(),
and finish() ends the file. The runner reads only the exit code: 0 passed, 77 skipped (the line skip() printed is
the reason it names), anything else failed.
"""

import shutil
import sys
import time
import traceback
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn

SKIPPED = 77

OUT = sys.stdout
"""Captured at import, so a file that swallows what the code under test prints still reports here."""

failures = 0


def check(what: str, expected, actual) -> None:
    if expected == actual:
        print(f"ok   {what}", file=OUT)
    else:
        fail(what, f"expected: {expected!r}\nactual:   {actual!r}")


def settles(what: str, expected, read: Callable[[], object], within: float = 10) -> None:
    """check() on what read() returns once it equals expected, or at the deadline: for a page or a process that
    gets there a moment after the action that moves it."""
    deadline = time.monotonic() + within
    while (actual := read()) != expected and time.monotonic() < deadline:
        time.sleep(0.05)
    check(what, expected, actual)


def fail(what: str, why: str = "") -> None:
    global failures
    failures += 1
    print(f"FAIL {what}", file=OUT)
    if why:
        print("".join(f"       {line}\n" for line in why.splitlines()), end="", file=OUT)


def skip(why: str) -> NoReturn:
    """Before any check runs: a skip after a failure would hide it."""
    print(f"skip: {why}", file=OUT)
    sys.exit(SKIPPED)


def needs(*tools: str) -> None:
    """Skips the file unless every tool named is on PATH."""
    for tool in tools:
        if not shutil.which(tool):
            skip(f"{tool} is not on PATH")


def finish() -> NoReturn:
    print(file=OUT)
    if failures:
        print(f"{failures} check(s) failed", file=OUT)
        sys.exit(1)
    print("all checks passed", file=OUT)
    sys.exit(0)


# --- properties


class Counterexample(AssertionError):
    """A property that does not hold, its message saying why; reported without a traceback."""


def expect(holds: bool, what: str) -> None:
    if not holds:
        raise Counterexample(what)


class Skip(Exception):
    """A property this host cannot check; the others still run."""


@dataclass(frozen=True)
class Property:
    says: str
    check: Callable[..., None]


PROPERTIES: list[Property] = []


def prop(says: str):
    def register(check):
        PROPERTIES.append(Property(says, check))
        return check

    return register


def run_properties(run: Callable[[Callable[..., None]], None] = lambda check: check(), only: Iterable[str] = ()) -> None:
    """Every registered property whose statement holds one of the only words (all of them when there are none),
    each handed to run, which calls it with what it takes and raises what it adds."""
    only = list(only)
    for p in PROPERTIES:
        if only and not any(word in p.says for word in only):
            continue
        try:
            run(p.check)
        except Skip as e:
            print(f"skip {p.says}: {e}", file=OUT)
        except Counterexample as e:
            fail(p.says, str(e))
        except Exception:
            fail(p.says, traceback.format_exc())
        else:
            print(f"ok   {p.says}", file=OUT)


def checked(examples: int):
    """Hypothesis settings for a property: examples cases, no deadline, and the failing ones kept beside this file
    for the next run to try first."""
    from hypothesis import HealthCheck, Phase, settings
    from hypothesis.database import DirectoryBasedExampleDatabase

    return settings(
        max_examples=examples,
        deadline=None,
        phases=[Phase.explicit, Phase.reuse, Phase.generate, Phase.target, Phase.shrink],
        report_multiple_bugs=False,
        database=DirectoryBasedExampleDatabase(Path(__file__).resolve().parent / ".hypothesis"),
        suppress_health_check=[HealthCheck.too_slow, HealthCheck.data_too_large],
    )
