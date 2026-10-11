"""The container hub's module, loaded in a test's process, the clock it reads there, and the world it reads: a scratch
HOME of repos, tickets, sessions and pages.

bin/container-hub reads the wall clock through its `time` module, and a test hands it a Clock instead. HOME the
module reads once, as it loads, so a test moves HOME before it loads one. The rest that main() sets from its flags
before it serves, the test sets as it needs: `load` sets the state directory, and a test that types into tmux sets
TMUX_SOCKET and CLEAR_WAIT. A module loaded anew on the same state is the hub restarted, as far as what it keeps on
disk goes: main()'s own start-up (the old containers moved in, each unit repaired) runs only in a hub process.
"""

import atexit
import itertools
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import time
import urllib.parse
from functools import cache
from pathlib import Path

from check import BIN, bin_module  # tests/ is on sys.path in every test that imports this

LOADS = itertools.count()

TICKET = "---\nstatus: {status}\n{parent}priority: 2\nsize: S\n---\n\n# {title}\n\n## Brief\n\n{brief}\n\n## Acceptance criteria\n\n## Comments\n"

READER = max(Path.home().glob(".claude*/plugins/cache/*/mx/*/skills/session-page/session_page.py"),
             key=lambda p: tuple(int(x) if x.isdigit() else 0 for x in p.parents[2].name.split(".")), default=None)
"""The session page's reader, which the hub loads from the newest mx plugin: the one this machine has, if any."""


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


def ticket_text(slug: str, status: str = "open", parent: str | None = None, title: str | None = None,
                brief: str | None = None) -> str:
    """A ticket file in the shape the tracker reads, titled by its slug unless given a title."""
    return TICKET.format(status=status, parent=f"parent: {parent}\n" if parent else "", title=title or slug,
                         brief=brief or f"{slug}.")


def ticket(agent: Path, slug: str, status: str = "open", parent: str | None = None) -> None:
    (agent / "tickets" / f"{slug}.md").write_text(ticket_text(slug, status, parent))


@cache
def uv_dirs() -> dict[str, str]:
    """uv's own directories, which would otherwise move into a scratch HOME and fetch everything again."""
    return {k: subprocess.run(["uv", *args], capture_output=True, text=True, check=True).stdout.strip()
            for k, args in (("UV_CACHE_DIR", ("cache", "dir")), ("UV_PYTHON_INSTALL_DIR", ("python", "dir")))}


def scrubbed(home: Path, **extra: str) -> dict[str, str]:
    """This environment with HOME moved, no session of its own, no tmux server, and no git or XDG configuration of
    the user's: a global commit hook would stamp the fixture's commits with this run's session."""
    env = {k: v for k, v in os.environ.items() if not k.startswith(("CLAUDE", "MX_", "GIT_", "XDG_", "CONTAINER_HUB", "TMUX"))}
    return {**env, **{k: v for k, v in uv_dirs().items() if v}, "HOME": str(home), "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1", **extra}


def tools_env(home: Path, **extra: str) -> dict[str, str]:
    """scrubbed(), with this repo's bin/ on PATH ahead of the rest where `extra` names no PATH of its own."""
    env = scrubbed(home, **extra)
    return {**env, "PATH": extra.get("PATH", f"{BIN}:{env['PATH']}")}


def started(pid: int | str = "self") -> str:
    """When the process started, as Claude Code's registry records it: /proc/<pid>/stat's starttime field."""
    return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]


def with_reader(home: Path) -> None:
    """The mx plugin's session page reader under `home`, where the hub looks for it, when this machine has one."""
    if READER:
        (home / ".claude/plugins/cache/market/mx").mkdir(parents=True, exist_ok=True)
        (home / ".claude/plugins/cache/market/mx" / READER.parents[2].name).symlink_to(READER.parents[2])


def page(path: Path, body: str = "<!doctype html><p>a page</p>") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)
    return path


served = lambda path: "/f" + urllib.parse.quote(str(path))
"""The address the hub serves a file at."""

SELF_STARTED = started()
RUN = Path(tempfile.mkdtemp(prefix="container-hub-test."))
"""Every world's scratch directory, gone when the test ends."""
atexit.register(shutil.rmtree, RUN, ignore_errors=True)
WORLDS: list["World"] = []


class World:
    """A HOME of its own, under which the hub's module is loaded, on a clock that reads an hour ahead of the wall
    clock, so a file the test writes without pinning its time was written before anything the hub stamps with its
    clock. The module runs in this process, so what it runs (git, tracker, tmux, diffview) gets the world's
    environment: making a world moves this process into it.

    Every tmux call, the hub's and the test's, goes through a tmux that passes on, where the world has a server, only
    those naming its socket, and records the rest: nothing may reach a server the test did not start. It logs the
    command of each it passes on, so a check can say which the hub ran.

    The helpers write what Claude Code, the tracker and the statusline leave on disk, as the hub reads it."""

    def __init__(self, port: int = 18377, tmux: bool = False):
        self.scratch = Path(tempfile.mkdtemp(prefix="world.", dir=RUN))
        self.home, self.temp = self.scratch / "home", self.scratch / "tmp"
        self.home.mkdir()
        self.temp.mkdir()  # beside HOME and not around it, so each guard is checked on its own
        self.port = port
        """The port the hub takes for its own, so that one of its addresses names a page it serves."""
        self.tmux_socket = self.scratch / "tmux.sock"
        self.tmux_refused, self.tmux_calls = self.scratch / "tmux-refused", self.scratch / "tmux-calls"
        shim = self.scratch / "shim" / "tmux"
        shim.parent.mkdir()
        passes = (f'[ "$1" = -S ] && [ "$2" = {shlex.quote(str(self.tmux_socket))} ] && exec {shlex.quote(shutil.which("tmux"))} "$@"\n'
                  if tmux else "")
        shim.write_text(f"""#!/usr/bin/env bash
[ "$1" = -S ] && printf '%s\\n' "$3" >> {shlex.quote(str(self.tmux_calls))}
{passes}printf '%s\\n' "$*" >> {shlex.quote(str(self.tmux_refused))}
exit 1
""")
        shim.chmod(0o755)
        self.tmux = shim
        self.env = scrubbed(self.home, TMPDIR=str(self.temp))
        self.env["PATH"] = f"{shim.parent}:{self.env['PATH']}"
        os.environ.clear()
        os.environ.update(self.env)
        tempfile.tempdir = None
        hljs = self.home / ".cache/diffview" / ("hljs-" + re.search(r'HLJS_VERSION = "(.+)"', (BIN / "diffview").read_text())[1])
        hljs.mkdir(parents=True)
        (hljs / "highlight.min.js").write_text("")  # fails its pin, so diffview neither fetches nor highlights
        with_reader(self.home)
        self.t0 = float(int(time.time()) + 3600)
        self.clock = Clock(self.t0)
        self.commits = itertools.count(int(self.t0) - 100_000, 10)
        """When each fixture commit is made: ten seconds after the one before, so their order never rests on the wall clock."""
        self.hub = load(self.clock, (self.scratch / "state").resolve())
        self.hub.STATE.mkdir()
        self.hub.TMUX_SOCKET = self.tmux_socket
        WORLDS.append(self)

    def refused(self) -> str:
        """Every tmux call that named no server of the world's."""
        return self.tmux_refused.read_text() if self.tmux_refused.exists() else ""

    # --- what is on disk

    def git(self, cwd: Path, *args: str, at: int | None = None) -> None:
        when = f"@{at or next(self.commits)} +0000"
        subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args], cwd=cwd,
                       env={**self.env, "GIT_AUTHOR_DATE": when, "GIT_COMMITTER_DATE": when}, check=True, capture_output=True)

    def repo(self, name: str, tickets: list[tuple[str, str | None, str]]) -> Path:
        """A code repo holding an agent repo; each ticket (slug, parent, session) committed by its session."""
        code = self.home / "repos" / name
        agent = code / "agent"
        (agent / "tickets").mkdir(parents=True)
        self.git(code, "init", "-q")
        (code / ".git" / "info" / "exclude").write_text("agent/\n")
        (code / "README.md").write_text(name)
        self.git(code, "add", "README.md")
        self.git(code, "commit", "-q", "-m", "init")
        self.git(agent, "init", "-q")
        for slug, parent, session in tickets:
            self.committed(agent, slug, session, "claimed" if parent else "open", parent)
        return code

    def committed(self, agent: Path, slug: str, session: str, status: str = "open", parent: str | None = None) -> None:
        """A ticket filed, or changed, and committed by a session."""
        ticket(agent, slug, status, parent)
        self.git(agent, "add", f"tickets/{slug}.md")
        self.git(agent, "commit", "-q", "-m", f"file {slug}", "-m", f"Session: {session}")

    def registered(self, session: str, status: str = "idle", at: float | None = None, pid: int | None = None,
                   started: str | None = SELF_STARTED, name: str | None = None, tmux: str | None = None,
                   waiting_for: str | None = None, cwd: Path | None = None, file: str | None = None) -> None:
        """The session's file in the registry, as Claude Code writes it while the session's process runs: by default
        this test's own process, which runs for as long as the hub reads it, marked at the hub's clock. A second
        process of the session has a file of its own."""
        entry = {"pid": pid or os.getpid(), "sessionId": session, "status": status,
                 "statusUpdatedAt": int((at or self.clock.now) * 1000), **({"procStart": started} if started else {}),
                 **({"name": name} if name else {}), **({"tmux": tmux} if tmux else {}),
                 **({"waitingFor": waiting_for} if waiting_for else {}), **({"cwd": str(cwd)} if cwd else {})}
        path = self.home / ".claude" / "sessions" / f"{file or session[:8]}.json"  # named by the pid there; any name reads alike
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(entry))

    def ended(self, session: str, **extra) -> None:
        """The session's registry file names a process that has exited."""
        gone = subprocess.Popen(["true"])
        gone.wait()
        self.registered(session, pid=gone.pid, started=None, **extra)

    def statusline(self, session: str, at: float, config_dir: Path | str | None = None, context: tuple | None = None,
                   five_hour: tuple | None = None, seven_day: tuple | None = None) -> None:
        """What the statusline keeps of a render: Claude Code's statusline input as received, with the account it ran
        under and when it ran added. A window is (used percentage, resets at); a pro account's input carries none."""
        data = {"session_id": session, "model": {"id": "claude-opus-5-5", "display_name": "Opus"},
                "workspace": {"current_dir": str(self.home)}, "config_dir": str(config_dir or self.home / ".claude"), "written_at": at,
                **({"context_window": {"used_percentage": context[0], "total_input_tokens": context[1],
                                       "context_window_size": 200000}} if context else {}),
                "rate_limits": {name: {"used_percentage": w[0], "resets_at": w[1]}
                                for name, w in (("five_hour", five_hour), ("seven_day", seven_day)) if w}}
        page(self.home / ".cache/claude-statusline" / f"{session}.json", json.dumps(data))

    def turn_record(self, session_dir: Path, number: int, headline: str, questions: tuple[str, ...] = (),
                    at: float | None = None, **front: dict[str, str]) -> None:
        """A turn record in the shape the mx plugin's RULES.md gives it, written at `at`, else at the hub's clock: its
        frontmatter's `answered` and `superseded` each a mapping of question tags."""
        path = session_dir / "turns" / f"{number:02d}.md"
        tables = "".join(f"{name}:\n" + "".join(f"  {tag}: {value}\n" for tag, value in table.items()) for name, table in front.items())
        asked = "\n## Questions\n\n" + "".join(f"- [{q}] **Which way, {q}?** A call only the user can make.\n  - (a) this way *my pick*\n  - (b) that way\n"
                                                    for q in questions) if questions else ""
        page(path, f"---\ndate: 2026-10-07\n{tables}---\n\n# {headline}\n{asked}")
        os.utime(path, (at or self.clock.now,) * 2)

    @staticmethod
    def chat_turn(session_dir: Path, reply: str, at: float) -> None:
        """A chat turn, as the Stop hook records one at `at`."""
        when = time.gmtime(at)
        page(session_dir / "turns" / time.strftime("chat-%Y%m%dT%H%M%SZ.md", when),
             f"---\ndate: 2026-10-07\nchat: {time.strftime('%Y-%m-%dT%H:%M:%S+00:00', when)}\n---\n\n{reply}\n")

    # --- what the hub decides

    def opened(self, target, session: str | None = None, **body) -> dict:
        """What the hub answers an agent that opens a page, as claude-browser asks it."""
        return self.hub.open_page({"target": str(target), **({"session": session} if session else {}), **body}, self.port, from_page=False)[1]

    def clicked(self, target, unit: str, **body) -> dict:
        """What the hub answers the hub tab for a link clicked in a page of the unit."""
        return self.hub.open_page({"target": str(target), "unit": unit, "by": "user", **body}, self.port, from_page=True)[1]

    def rail(self) -> list[dict]:
        return self.hub.hub_view()["units"]

    def view(self, key: str) -> dict | None:
        """A unit as the hub tab reads it (/api/u/<key>), None once it is gone."""
        return next((u for u in self.rail() if u["unit"] == key), None)

    def number(self, key: str):
        return (self.view(key) or {}).get("number", "gone")

    def member_of(self, opened: dict) -> dict:
        return next(m for m in self.view(opened["unit"])["members"] if m["id"] == opened["id"])
