"""A synthetic host for the hub of a busy one's size: units, some of whose sessions run, idle in tmux panes, each with a
transcript, a session page with its turn records, a statusline file, and pages opened in an agent repo. What
`watch-load` measures the hub on, hearing the disk against reading it on a clock."""

import json
import os
import subprocess
from pathlib import Path

import fakes

REPOS, TICKETS, TRANSCRIPT_KB, TURNS = 8, 40, 200, 15
"""The agent repos the units' pages are in, the tickets each holds, a transcript's size, and a session page's turns."""
TICKET = "---\nstatus: open\npriority: 2\nsize: S\n---\n\n# {slug}\n\n## Brief\n\n{slug}.\n\n## Acceptance criteria\n\n## Comments\n"


def sid(i: int) -> str:
    return f"{i:08x}-0000-4000-8000-{i:012x}"


def git(cwd: Path, *args: str) -> None:
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args], cwd=cwd, check=True,
                   capture_output=True, env={**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"})


def build(home: Path, state: Path, units: int) -> list[str]:
    """Write the world under `home` and the hub's units under `state`; the ids of their sessions, in order."""
    filler = json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "x" * 900}]}}) + "\n"
    agents = []
    for r in range(REPOS):
        code = home / "repos" / f"repo{r}"
        agent = code / "agent"
        (agent / "tickets").mkdir(parents=True)
        git(code, "init", "-q")
        (code / ".git" / "info" / "exclude").write_text("agent/\n")
        git(agent, "init", "-q")
        for t in range(TICKETS):
            (agent / "tickets" / f"t{t}.md").write_text(TICKET.format(slug=f"t{t}"))
        agents.append(agent)
    (state / "units").mkdir(parents=True)
    for i in range(units):
        s, agent = sid(i), agents[i % REPOS]
        slug = f"t{i % TICKETS}"
        pages = [fakes.page(agent / "show" / slug / f"p{i}-{p}.html", "<!doctype html><p>a page</p>\n") for p in range(3)]
        records = home / ".claude" / "session-pages" / s
        fakes.page(records / "session.md", f"---\nsession: {s}\n---\n\n# Session {i}\n")
        column = "".join(f'<a data-artefact="{p}">{p.name}</a>' for p in pages)
        fakes.page(records / "index.html", f'<!doctype html><p>session {i}</p><aside id="artefacts">{column}</aside>\n')
        for n in range(1, TURNS + 1):
            fakes.page(records / "turns" / f"{n:02d}.md", f"---\ndate: 2026-10-07\n---\n\n# Turn {n} of session {i}\n")
        fakes.page(home / ".claude" / "projects" / f"-repo{i % REPOS}" / f"{s}.jsonl",
                   json.dumps({"type": "user", "sessionId": s, "cwd": str(agent.parent), "message": {"role": "user", "content": "go"}})
                   + "\n" + filler * (TRANSCRIPT_KB * 1024 // len(filler)))
        members = [{"id": f"m{p}", "url": f"/f{page}", "path": str(page), "tracker": str(agent / "tickets"), "ticket": slug,
                    "kind": "page", "title": page.name, "first": 1_790_000_000 + i, "closed": False, "at": 1_790_000_000 + i,
                    "by": "agent", "agent": True} for p, page in enumerate(pages)]
        (state / "units" / f"{s}.json").write_text(json.dumps({"key": s, "session": s, "roots": {}, "members": members,
                                                                "visited": 0, "dismissed": 0}))
    for a in agents:
        git(a, "add", "-A")
        git(a, "commit", "-q", "-m", "tickets")
    return [sid(i) for i in range(units)]


def run(home: Path, sessions: list[str], tmux: Path) -> None:
    """A process for each session, in a pane of its own of the tmux server at `tmux`, which `stop` ends, registered as
    Claude Code registers the one it runs, idle, in its repo; and its statusline file."""
    env = {k: v for k, v in os.environ.items() if not k.startswith(("DISPATCH_", "TMUX"))}
    subprocess.run(["tmux", "-S", str(tmux), "new-session", "-d", "-s", "load", "sleep infinity"], env=env, check=True)
    for n, s in enumerate(sessions):
        shown = subprocess.run(["tmux", "-S", str(tmux), "new-window", "-d", "-t", "load", "-P", "-F", "#{window_id} #{pane_id} #{pane_pid}",
                                "exec sleep infinity"], env=env, check=True, capture_output=True, text=True).stdout.split()
        window, pane, pid = shown[0], shown[1], int(shown[2])
        cwd = next(home.glob(f".claude/projects/*/{s}.jsonl")).parent.name.removeprefix("-")
        fakes.page(home / ".claude" / "sessions" / f"{pid}.json",
                   json.dumps({"pid": pid, "procStart": fakes.started(pid), "sessionId": s, "status": "idle",
                               "statusUpdatedAt": 1_790_000_000_000, "kind": "interactive", "cwd": str(home / "repos" / cwd),
                               "tmux": f"load:{window}.{pane}"}))
        statusline(home, s, 0)


def stop(tmux: Path) -> None:
    subprocess.run(["tmux", "-S", str(tmux), "kill-server"], capture_output=True)


def statusline(home: Path, session: str, n: int) -> None:
    fakes.page(home / ".cache" / "claude-statusline" / f"{session}.json",
               json.dumps({"session_id": session, "config_dir": str(home / ".claude"), "written_at": 1_790_000_000 + n,
                           "context_window": {"used_percentage": n % 100, "total_input_tokens": n * 100}}))
