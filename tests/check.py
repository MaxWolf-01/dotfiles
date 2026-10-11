"""What every Python test file shares. A file under tests/ puts that directory on sys.path and imports it.

Examples are checked with check() and settles(), properties registered with prop() and run by run_properties(),
and finish() ends the file. What the runner makes of the exit code and the skip lines: the Makefile's header.
"""

import importlib.util
import os
import shutil
import socket
import sys
import time
import traceback
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from importlib.machinery import SourceFileLoader
from pathlib import Path
from typing import NoReturn

SKIPPED = 77

OUT = sys.stdout
"""Captured at import, so a file that swallows what the code under test prints still reports here."""

failures = 0


def check(what: str, expected, actual) -> None:
    if expected == actual:
        passed(what)
    else:
        fail(what, f"expected: {expected!r}\nactual:   {actual!r}")


def settles(what: str, expected, read: Callable[[], object], within: float = 10) -> None:
    """check() on what read() returns once it equals expected, or at the deadline: for a page or a process that
    gets there a moment after the action that moves it."""
    deadline = time.monotonic() + within
    while (actual := read()) != expected and time.monotonic() < deadline:
        time.sleep(0.05)
    check(what, expected, actual)


def passed(what: str) -> None:
    print(f"ok   {what}", file=OUT)


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


def skipped(what: str, why: str) -> None:
    """One case this host cannot check, while the rest of the file runs."""
    print(f"skip {what}: {why}", file=OUT)


def finish() -> NoReturn:
    print(file=OUT)
    if failures:
        print(f"{failures} check(s) failed", file=OUT)
        sys.exit(1)
    print("all checks passed", file=OUT)
    sys.exit(0)


# --- what the code under test is reached through

BIN = Path(__file__).resolve().parents[1] / "bin"


def bin_module(name: str, module: str = ""):
    """bin/<name> loaded as a module, registered as `module` (its name with _ for -) in sys.modules, where
    dataclasses resolve their annotations. bin/ is on $PATH, so the load leaves no __pycache__ there."""
    module = module or name.replace("-", "_")
    loader = SourceFileLoader(module, str(BIN / name))
    loaded = sys.modules[module] = importlib.util.module_from_spec(importlib.util.spec_from_loader(module, loader))
    writes, sys.dont_write_bytecode = sys.dont_write_bytecode, True
    try:
        loader.exec_module(loaded)
    finally:
        sys.dont_write_bytecode = writes
    return loaded


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def chromium(playwright, **launch):
    """A headless Chromium launched through Playwright: $CHROMIUM, else `chromium` on PATH, else Playwright's own,
    which `make install` fetches. Raises Skip when there is none of them."""
    from playwright.sync_api import Error

    exe = os.environ.get("CHROMIUM") or shutil.which("chromium")
    try:
        return playwright.chromium.launch(executable_path=exe, **launch)
    except Error as e:
        if exe or "Executable doesn't exist" not in str(e):
            raise
        raise Skip("no Chromium: `make install` fetches Playwright's, $CHROMIUM names one, or one is on PATH") from None


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
            skipped(p.says, str(e))
        except Counterexample as e:
            fail(p.says, str(e))
        except Exception:
            fail(p.says, traceback.format_exc())
        else:
            passed(p.says)


def checked(examples: int):
    """Hypothesis settings for a property: examples cases, no deadline, and the failing ones kept beside this file
    for the next run to try first."""
    from hypothesis import HealthCheck, settings
    from hypothesis.database import DirectoryBasedExampleDatabase

    return settings(
        max_examples=examples,
        deadline=None,
        report_multiple_bugs=False,
        database=DirectoryBasedExampleDatabase(Path(__file__).resolve().parent / ".hypothesis"),
        suppress_health_check=[HealthCheck.too_slow, HealthCheck.data_too_large],
    )
