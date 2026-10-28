"""A synthetic hub of the size of a busy host's: N units, M of whose sessions run, each with a transcript, a session
page with its turn records, a statusline file, and pages opened in an agent repo. What `bench-watch` measures the hub
on, polling against events."""

import json
import os
import subprocess
from pathlib import Path

TICKET = "---\nstatus: open\npriority: 2\nsize: S\n---\n\n# {slug}\n\n## Brief\n\n{slug}.\n\n## Acceptance criteria\n\n## Comments\n"


def sid(i: int) -> str:
    return f"{i:08x}-0000-4000-8000-{i:012x}"


def git(cwd: Path, *args: str) -> None:
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args], cwd=cwd, check=True,
                   capture_output=True, env={**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"})


def build(home: Path, state: Path, units: int, running: int, repos: int = 8, tickets: int = 40,
          transcript_kb: int = 200, turns: int = 15) -> list[str]:
    """Write the world under `home` and the hub's units under `state`; the ids of the sessions meant to run, whose
    registry files `run` writes once their processes start."""
    filler = json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "x" * 900}]}}) + "\n"
    agents = []
    for r in range(repos):
        code = home / "repos" / f"repo{r}"
        agent = code / "agent"
        (agent / "tickets").mkdir(parents=True)
        git(code, "init", "-q")
        (code / ".git" / "info" / "exclude").write_text("agent/\n")
        git(agent, "init", "-q")
        for t in range(tickets):
            (agent / "tickets" / f"t{t}.md").write_text(TICKET.format(slug=f"t{t}"))
        agents.append(agent)
    (state / "units").mkdir(parents=True)
    for i in range(units):
        s, agent = sid(i), agents[i % repos]
        slug = f"t{i % tickets}"
        git(agent, "add", "-A")
        pages = []
        for p in range(3):
            page = agent / "show" / slug / f"p{i}-{p}.html"
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_text("<!doctype html><p>a page</p>\n")
            pages.append(page)
        records = home / ".claude" / "session-pages" / s
        (records / "turns").mkdir(parents=True)
        (records / "session.md").write_text(f"---\nsession: {s}\n---\n\n# Session {i}\n")
        column = "".join(f'<a data-artefact="{p}">{p.name}</a>' for p in pages)
        (records / "index.html").write_text(f'<!doctype html><p>session {i}</p><aside id="artefacts">{column}</aside>\n')
        for n in range(1, turns + 1):
            (records / "turns" / f"{n:02d}.md").write_text(f"---\ndate: 2026-10-07\n---\n\n# Turn {n} of session {i}\n")
        transcript = home / ".claude" / "projects" / f"-repo{i % repos}" / f"{s}.jsonl"
        transcript.parent.mkdir(parents=True, exist_ok=True)
        transcript.write_text(json.dumps({"type": "user", "sessionId": s, "cwd": str(agent.parent),
                                          "message": {"role": "user", "content": "go"}}) + "\n" + filler * (transcript_kb * 1024 // len(filler)))
        members = [{"id": f"m{p}", "url": f"/f{page}", "path": str(page), "tracker": str(agent / "tickets"), "ticket": slug,
                    "kind": "page", "title": page.name, "first": 1_790_000_000 + i, "closed": False, "at": 1_790_000_000 + i,
                    "by": "agent", "agent": True} for p, page in enumerate(pages)]
        (state / "units" / f"{s}.json").write_text(json.dumps({"key": s, "session": s, "roots": {}, "members": members,
                                                                "visited": 0, "dismissed": 0}))
    for a in agents:
        git(a, "add", "-A")
        git(a, "commit", "-q", "-m", "tickets")
    return [sid(i) for i in range(running)]


def proc_start(pid: int) -> str:
    return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]


def run(home: Path, sessions: list[str]) -> list[subprocess.Popen]:
    """A process for each session, registered as Claude Code registers the one it runs, idle, and its statusline file."""
    procs = []
    for s in sessions:
        p = subprocess.Popen(["sleep", "infinity"], env={k: v for k, v in os.environ.items() if not k.startswith("DISPATCH_")})
        procs.append(p)
        entry = home / ".claude" / "sessions" / f"{p.pid}.json"
        entry.parent.mkdir(parents=True, exist_ok=True)
        entry.write_text(json.dumps({"pid": p.pid, "procStart": proc_start(p.pid), "sessionId": s, "status": "idle",
                                     "statusUpdatedAt": 1_790_000_000_000, "kind": "interactive"}))
        statusline(home, s, 0)
    return procs


def statusline(home: Path, session: str, n: int) -> None:
    path = home / ".cache" / "claude-statusline" / f"{session}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"session_id": session, "config_dir": str(home / ".claude"), "written_at": 1_790_000_000 + n,
                                "context_window": {"used_percentage": n % 100, "total_input_tokens": n * 100}}))
