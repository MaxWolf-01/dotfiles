"""The world bin/vpn reaches through its ports, faked, and the ways a test drives bin/vpn in it.

A World is tailscaled, the network, the clock and Vesktop as one simulation,
in tailscaled's own shapes. It serves full status and prefs, sends a Prefs bus
message for every change of preferences, and pushes an engine update every
2 s with each live peer's byte counters and last handshake. Its Mullvad nodes
are Hosts. Each answers handshakes or not, carries traffic or not, and is
blocked by Cloudflare or not. Time is the World's own. Waiting advances it,
and nothing sleeps.

The World records what happens in it as Entries, in order. There is one for
every step the watcher takes through a port that acts (a probe, a `tailscale
set`, a connect, a Discord check), for every change from outside, and for
each request's sending, disconnection and final line.

The World's port wiring and the drivers at the bottom are the only code here
that calls into bin/vpn. A test states what happens, and they call.

Loading this module points bin/vpn at a scratch directory for its runtime
files, at no tailscaled socket, and at a `tailscale` that fails, so code
that bypasses the ports fails instead of reaching the real VPN.
"""

import atexit
import hashlib
import heapq
import importlib.util
import itertools
import json
import os
import shutil
import tempfile
from collections.abc import Callable
from contextlib import contextmanager
from dataclasses import dataclass, field, replace
from datetime import datetime, timezone
from importlib.machinery import SourceFileLoader
from pathlib import Path
from typing import Any, Literal

SCRATCH = Path(tempfile.mkdtemp(prefix="vpn-fakes-"))
atexit.register(shutil.rmtree, SCRATCH, ignore_errors=True)
(SCRATCH / "run").mkdir()
(SCRATCH / "bin").mkdir()
(SCRATCH / "bin" / "tailscale").write_text(
    "#!/bin/sh\necho 'vpn_fakes: bin/vpn ran the real tailscale instead of its Tailscaled port' >&2\nexit 1\n")
(SCRATCH / "bin" / "tailscale").chmod(0o755)
os.environ["XDG_RUNTIME_DIR"] = str(SCRATCH / "run")
os.environ["VPN_TAILSCALED_SOCKET"] = str(SCRATCH / "no-tailscaled.sock")
os.environ["PATH"] = f"{SCRATCH / 'bin'}{os.pathsep}{os.environ.get('PATH', '')}"


def load(name: str, path: Path):
    loader = SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    assert spec
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


vpn = load("vpn", Path(__file__).resolve().parent.parent / "bin" / "vpn")

T0 = 1_800_000_000.0
ENGINE_SECS = 2.0
"""How often tailscaled pushes an engine update."""
RTT = 0.05
"""One round trip to any node that answers."""
DEMAND = 1500
"""Bytes this machine's applications send through the exit node between two engine updates. A node that
carries traffic answers with twice that."""
AFTER_SECS = 120.0
"""How long a run goes on after its last timed event."""
HANG_SECS = 1800.0
"""How far past a run's end the watcher may keep the World busy before it counts as hung."""

PC = "pc"
"""An exit node of this tailnet outside Mullvad."""


class Over(Exception):
    """The run reached its end with the watcher idle."""


class Hang(AssertionError):
    """The watcher kept the World busy long past the run's end."""


# --------------------------------------------------------------------------
# what the World is made of
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Host:
    """One Mullvad node, as it really is."""

    name: str
    country: str
    city: str
    online: bool = True
    """What the control server says."""
    answers: bool = True
    """Completes a WireGuard handshake."""
    carries: bool = True
    """Forwards traffic to the internet. Only a node that answers can."""
    blocked: bool = False
    """Cloudflare answers the Discord check through it with a 403."""
    handshook: bool = False
    """Completed a handshake before the World's first moment, whatever it does now."""
    leaks: bool = False
    """A connect through it answers although it carries nothing, as when the switch to it has not taken effect.
    Its own counters stay still."""
    discord_silent: bool = False
    """Discord does not answer through it, though it carries traffic and Cloudflare does not block it."""

    @property
    def fqdn(self) -> str:
        return f"{self.name}.mullvad.ts.net"


Setting = tuple[str, str | None]
"""How the exit node is set, as ("pinned", node), ("automatic", its pick) or ("off", None)."""

StepKind = Literal["set", "probe", "connect", "discord"]
Kind = Literal["send", "disconnect", "finish", "outside", "auto-move", "set", "probe", "connect", "discord"]
STEPS = ("set", "probe", "connect", "discord")


@dataclass(frozen=True)
class Entry:
    kind: Kind
    """send, disconnect and finish are a request's. outside and auto-move are changes from outside. set, probe,
    connect and discord are steps the watcher took."""
    t: float
    before: Setting
    state: Setting
    """The exit node after the entry. For a connect or a Discord check, which take time, the exit node as the
    step began."""
    req: int | None = None
    """The request a send, disconnect or finish is about."""
    what: Any = None
    """For a send, the Ask. For a set or outside, the target. For a probe, the node. For a connect, whether it
    answered. For a discord, the verdict. For a finish, (ok, message). For an auto-move, the new pick."""
    logged: int | None = None
    """For outside and auto-move, how many node-log lines there were when it happened."""


# What happens in a World, at a time or after a step.


@dataclass(frozen=True)
class Ask:
    """A vpn command sends a request."""

    request: str
    place: str = ""


@dataclass(frozen=True)
class Outside:
    """A bare `tailscale set --exit-node=<target>`, run by an escape hatch or by max by hand."""

    target: str


@dataclass(frozen=True)
class AutoMoves:
    """Automatic mode, when on, picks another node by itself."""

    to: str


@dataclass(frozen=True)
class Dies:
    """A node stops answering and carrying."""

    name: str


@dataclass(frozen=True)
class Revives:
    name: str


@dataclass(frozen=True)
class Online:
    """The control server changes a node's online flag."""

    name: str
    online: bool


@dataclass(frozen=True)
class Disconnect:
    """The command whose request is running goes away, as on Ctrl-C."""


@dataclass(frozen=True)
class Vesktop:
    running: bool


@dataclass(frozen=True)
class Quiet:
    """tailscaled pushes no engine update for a while."""

    secs: float


@dataclass(frozen=True)
class BusGap:
    """The event bus carries nothing for a while, then reconnects. What changed meanwhile arrives as one change."""

    secs: float


Happening = Ask | Outside | AutoMoves | Dies | Revives | Online | Disconnect | Vesktop | Quiet | BusGap


@dataclass(frozen=True)
class AfterStep:
    """When the n-th step the watcher takes returns, counting from 1. With `kind`, the n-th step of that kind."""

    n: int
    kind: StepKind | None = None


@dataclass(frozen=True)
class At:
    """At this many seconds after the run starts."""

    secs: float


def key(name: str) -> str:
    return "nodekey:" + hashlib.sha256(name.encode()).hexdigest()


def stable_id(name: str) -> str:
    return "n" + hashlib.sha256(b"id" + name.encode()).hexdigest()[:12].upper() + "CNTRL"


def iso(t: float | None) -> str:
    if t is None:
        return "0001-01-01T00:00:00Z"
    return datetime.fromtimestamp(t, timezone.utc).isoformat().replace("+00:00", "Z")


# --------------------------------------------------------------------------
# the World
# --------------------------------------------------------------------------


@dataclass
class Caller:
    """The command at the other end of one request."""

    world: "World"
    id: int
    lines: list[str] = field(default_factory=list)
    finishes: list[tuple[bool, str]] = field(default_factory=list)
    here: bool = True

    def say(self, line: str) -> None:
        if self.here:
            self.lines.append(line)

    def finish(self, ok: bool, message: str) -> None:
        self.finishes.append((ok, message))
        self.world.note("finish", req=self.id, what=(ok, message))

    def connected(self) -> bool:
        return self.here


class World:
    def __init__(self, hosts: list[Host], setting: Setting = ("off", None), *, auto_pick: str | None = None,
                 vesktop: bool = False):
        self.hosts = {h.name: h for h in hosts}
        self.mode, self.exit = setting
        self.auto_pick = auto_pick or (setting[1] if setting[0] == "automatic" else None) or hosts[0].name
        self.vesktop = vesktop
        self.now = T0
        self.rx: dict[str, int] = {}
        self.tx: dict[str, int] = {}
        self.handshake = {h.name: T0 - 90 for h in hosts if h.handshook}
        self.entries: list[Entry] = []
        self.callers: list[Caller] = []
        self.steps: dict[str | None, int] = {}
        self.after_step: dict[tuple[int, str | None], list[Happening]] = {}
        self.ready: list[object] = []
        self.schedule: list[tuple[float, int, Callable[[], None]]] = []
        self.seq = itertools.count()
        self.bus_down_until = 0.0
        self.quiet_until = 0.0
        self.last_at = 0.0
        self.end = float("inf")
        self.idle = False
        """Whether the watcher is waiting at its top level, between two things it handles."""
        self._runs: Path | None = None
        self.at(self.now, self.engine_update)
        if self.exit is not None and self.answers(self.exit):
            self.handshake[self.exit] = self.now - 30
        self.ports = vpn.Ports(
            tailscaled=vpn.Tailscaled(status=self.status, prefs=self.prefs, set_exit_node=self.watcher_sets,
                                      bus=lambda mask: iter(())),
            network=vpn.Network(probe=self.probe, connect=self.connect, discord=self.discord, egress=self.egress),
            clock=vpn.Clock(now=lambda: self.now, wait=self.wait),
            vesktop=lambda: self.vesktop,
        )

    @property
    def runs(self) -> Path:
        """The run-log directory the watcher writes this World's node log to."""
        if self._runs is None:
            self._runs = Path(tempfile.mkdtemp(prefix="runs-", dir=SCRATCH))
        return self._runs

    # --- what the World is

    def setting(self) -> Setting:
        return (self.mode, self.exit)

    def answers(self, name: str) -> bool:
        return name == PC or (name in self.hosts and self.hosts[name].answers)

    def carries(self, name: str | None) -> bool:
        return name == PC or (name in self.hosts and self.hosts[name].answers and self.hosts[name].carries)

    def peers(self) -> dict[str, dict]:
        peers = {}
        for i, h in enumerate(self.hosts.values()):
            peers[key(h.name)] = {
                "ID": stable_id(h.name), "PublicKey": key(h.name), "HostName": h.name,
                "DNSName": f"{h.fqdn}.", "TailscaleIPs": [f"100.64.{i // 250}.{i % 250 + 1}", f"fd7a:115c:a1e0::{i + 1:x}"],
                "Online": h.online, "ExitNode": h.name == self.exit, "ExitNodeOption": True,
                "Location": {"Country": h.country, "CountryCode": h.name[:2].upper(), "City": h.city,
                             "CityCode": h.name.split("-")[1]},
                "RxBytes": self.rx.get(h.name, 0), "TxBytes": self.tx.get(h.name, 0),
                "LastHandshake": iso(self.handshake.get(h.name)),
            }
        peers[key(PC)] = {
            "ID": stable_id(PC), "PublicKey": key(PC), "HostName": PC, "DNSName": "pc.tail0000.ts.net.",
            "TailscaleIPs": ["100.100.0.1", "fd7a:115c:a1e0::ffff"], "Online": True, "ExitNode": self.exit == PC,
            "ExitNodeOption": True, "RxBytes": self.rx.get(PC, 0), "TxBytes": self.tx.get(PC, 0),
            "LastHandshake": iso(self.handshake.get(PC)),
        }
        return peers

    def status(self) -> dict:
        peers = self.peers()
        exit_peer = peers.get(key(self.exit)) if self.exit else None
        return {
            "BackendState": "Running",
            "Self": {"ID": "nSELFCNTRL", "HostName": "laptop", "DNSName": "laptop.tail0000.ts.net.",
                     "TailscaleIPs": ["100.100.0.2"], "Online": True},
            "Peer": peers,
            "ExitNodeStatus": {"ID": exit_peer["ID"], "Online": exit_peer["Online"],
                               "TailscaleIPs": exit_peer["TailscaleIPs"]} if exit_peer else None,
        }

    def prefs(self) -> dict:
        prefs = {"WantRunning": True, "ExitNodeID": stable_id(self.exit) if self.exit else "", "ExitNodeIP": "",
                 "ExitNodeAllowLANAccess": self.exit is not None}
        if self.mode == "automatic":
            prefs["AutoExitNode"] = "any"
        return prefs

    def resolve(self, target: str) -> Setting:
        """What `tailscale set --exit-node=<target>` sets."""
        if target == "":
            return ("off", None)
        if target == "auto:any":
            return ("automatic", self.auto_pick)
        want = target.removesuffix(".")
        for peer in self.peers().values():
            if want in (peer["HostName"], peer["DNSName"].removesuffix("."), peer["ID"], *peer["TailscaleIPs"]):
                return ("pinned", peer["HostName"])
        raise vpn.VpnError(f"tailscale set {target} failed: invalid value")

    # --- changes

    def note(self, kind: Kind, before: Setting | None = None, *, began: tuple[float, int] | None = None,
             **fields) -> Entry:
        """Record an entry. `began`, the time and entry index a step started at, files a step that took time
        where it started."""
        if before is None:
            before = self.setting()
        t, at = began or (self.now, len(self.entries))
        after = before if began else self.setting()
        entry = Entry(kind, t, before, after, **fields)
        self.entries.insert(at, entry)
        return entry

    def change(self, new: Setting) -> None:
        """Set the exit node as tailscaled does, and tell the bus."""
        old = self.exit
        self.mode, self.exit = new
        if self.exit is not None and self.exit != old and self.answers(self.exit):
            self.handshake[self.exit] = self.now + RTT
        self.arrive({"Prefs": self.prefs()})

    def watcher_sets(self, target: str) -> None:
        new = self.resolve(target)
        before = self.setting()
        self.change(new)
        self.step("set", before, what=target)

    def happen(self, happening: Happening) -> None:
        before = self.setting()
        match happening:
            case Ask(request, place):
                caller = Caller(self, len(self.callers))
                self.callers.append(caller)
                self.note("send", req=caller.id, what=happening)
                self.arrive(vpn.Request(request=request, place=place,
                                        client=vpn.Client(say=caller.say, finish=caller.finish,
                                                          connected=caller.connected)))
            case Outside(target):
                new = self.resolve(target)
                if new != before:
                    self.change(new)
                    self.note("outside", before, what=target, logged=len(self.node_log()))
            case AutoMoves(to):
                self.auto_pick = to
                if self.mode == "automatic" and self.exit != to:
                    self.change(("automatic", to))
                    self.note("auto-move", before, what=to, logged=len(self.node_log()))
            case Dies(name):
                self.hosts[name] = replace(self.hosts[name], answers=False, carries=False)
            case Revives(name):
                self.hosts[name] = replace(self.hosts[name], answers=True, carries=True)
            case Online(name, online):
                self.hosts[name] = replace(self.hosts[name], online=online)
                self.arrive({"PeerChanges": [{"NodeID": int(stable_id(name)[1:7], 16), "Online": online}]})
            case Disconnect():
                running = next((c for c in self.callers if not c.finishes and c.here), None)
                if running is not None:
                    running.here = False
                    self.note("disconnect", req=running.id)
            case Vesktop(running):
                self.vesktop = running
            case Quiet(secs):
                self.quiet_until = self.now + secs
            case BusGap(secs):
                self.bus_down_until = self.now + secs
                self.at(self.bus_down_until, lambda: self.arrive({"Prefs": self.prefs()}))

    def when(self, trigger: AfterStep | At, happening: Happening) -> None:
        match trigger:
            case AfterStep(n, kind):
                self.after_step.setdefault((n, kind), []).append(happening)
            case At(secs):
                self.at(T0 + secs, lambda: self.happen(happening))
                self.last_at = max(self.last_at, secs)

    def step(self, kind: StepKind, before: Setting | None = None, **fields) -> None:
        self.note(kind, before, **fields)
        for counted in (None, kind):
            self.steps[counted] = self.steps.get(counted, 0) + 1
            for happening in self.after_step.pop((self.steps[counted], counted), []):
                self.happen(happening)

    # --- the network

    def probe(self, ip: str) -> None:
        name = next((p["HostName"] for p in self.peers().values() if ip in p["TailscaleIPs"]), None)
        if name is not None:
            self.tx[name] = self.tx.get(name, 0) + 180
            if self.answers(name):
                self.handshake[name] = self.now + RTT
                self.rx[name] = self.rx.get(name, 0) + 92
        self.step("probe", what=name or ip)

    def connect(self, timeout: float) -> bool:
        began, before = (self.now, len(self.entries)), self.setting()
        through = self.exit
        carries = self.carries(through)
        ok = carries or (through in self.hosts and self.hosts[through].leaks)
        if through is not None:
            self.tx[through] = self.tx.get(through, 0) + 120
            if carries:
                self.rx[through] = self.rx.get(through, 0) + 120
        self.advance(self.now + (3 * RTT if ok else timeout))
        self.step("connect", before, began=began, what=ok)
        return ok

    def discord(self) -> str:
        began, before = (self.now, len(self.entries)), self.setting()
        host = self.hosts.get(self.exit or "")
        if not self.carries(self.exit) or (host and host.discord_silent):
            verdict = "unreachable"
        elif host and host.blocked:
            verdict = "blocked"
        else:
            verdict = "clean"
        self.advance(self.now + 0.2)
        self.step("discord", before, began=began, what=verdict)
        return verdict

    def egress(self) -> dict:
        if not self.carries(self.exit):
            return {}
        return {"ip": "185.0.0.1", "country": "", "city": "",
                "mullvad_exit_ip_hostname": self.exit if self.exit in self.hosts else None}

    # --- time

    def at(self, t: float, fn: Callable[[], None]) -> None:
        heapq.heappush(self.schedule, (t, next(self.seq), fn))

    def arrive(self, arrival: object) -> None:
        if self.now >= self.bus_down_until or not isinstance(arrival, dict):
            self.ready.append(arrival)

    def engine_update(self) -> None:
        if self.exit is not None:
            self.tx[self.exit] = self.tx.get(self.exit, 0) + DEMAND
            if self.carries(self.exit):
                self.rx[self.exit] = self.rx.get(self.exit, 0) + 2 * DEMAND
        self.at(self.now + ENGINE_SECS, self.engine_update)
        if self.now < self.quiet_until:
            return
        live = {key(n): {"NodeKey": key(n), "TxBytes": self.tx.get(n, 0), "RxBytes": self.rx.get(n, 0),
                         "LastHandshake": iso(t)}
                for n, t in self.handshake.items() if t <= self.now}
        self.arrive({"Engine": {"RBytes": sum(self.rx.values()), "WBytes": sum(self.tx.values()),
                                "NumLive": len(live), "LiveDERPs": 1, "LivePeers": live}})

    def advance(self, until: float) -> None:
        while self.schedule and self.schedule[0][0] <= until:
            t, _, fn = heapq.heappop(self.schedule)
            self.now = max(self.now, t)
            fn()
        self.now = max(self.now, until)
        if not self.idle and self.now > self.end + HANG_SECS:
            raise Hang(f"the watcher was still busy {HANG_SECS:.0f} s after the run's last event")

    def wait(self, secs: float):
        """The Clock port's wait: the next arrival within `secs`, or None."""
        if self.idle and self.now >= self.end and not self.ready:
            raise Over
        deadline = self.now + max(secs, 0.0)
        while not self.ready:
            if not self.schedule or self.schedule[0][0] > deadline:
                self.advance(deadline)
                return None
            self.advance(self.schedule[0][0])
        return self.ready.pop(0)

    # --- the node log

    def node_log(self) -> list["Line"]:
        path = self.runs / f"{vpn.NODE_UNIT}.jsonl"
        if not path.exists():
            return []
        return [line(json.loads(text)["stats"]) for text in path.read_text().splitlines()]


# --------------------------------------------------------------------------
# reading the node log
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Line:
    """One node-log line, as far as a test needs it."""

    event: str
    change: bool
    """Whether the line records a change of exit node."""
    outside: bool
    """Whether it records one the watcher did not make."""
    frm: str | None
    to: str | None


def line(stats: dict) -> Line:
    """Read a line in either vocabulary: `by`, `from` and `to`, or today's `command`, `node` and `rotated_to`."""
    event = stats.get("event", "")
    if "by" in stats:
        frm, to = stats.get("from"), stats.get("to")
        return Line(event, event != "silent" and frm != to, stats["by"] == "outside", frm, to)
    node, to = stats.get("node"), stats.get("rotated_to")
    if event in ("pinned", "rotated", "offline", "changed"):
        return Line(event, True, event == "changed", node, to)
    if event == "clean" and to:
        return Line(event, True, False, node, to)
    if event == "off":
        return Line(event, True, False, node, None)
    return Line(event, False, False, node, to)


# --------------------------------------------------------------------------
# drivers: how bin/vpn is called in a World
# --------------------------------------------------------------------------


def nodes(world: World) -> dict[str, Any]:
    return {n.name: n for n in vpn.mullvad_nodes(world.status())}


def next_order(hosts: list[Host], current: str | None) -> list[str]:
    """Where `vpn next` goes from `current`, in walk order."""
    by_name = nodes(World(hosts))
    return [n.name for n in vpn.candidates(by_name.get(current), list(by_name.values()))]


def to_order(hosts: list[Host], place: str, current: str | None) -> list[str]:
    """Where `vpn to <place>` goes from `current`, in walk order."""
    by_name = nodes(World(hosts))
    everything = list(by_name.values())
    return [n.name for n in vpn.destinations(place, vpn.resolve(place, everything), by_name.get(current))]


def liveness(world: World) -> Any:
    live = vpn.Liveness(clock=world.ports.clock)
    live.learn(world.status())
    return live


def probe(world: World, names: list[str]) -> list[str]:
    """Handshake-probe the nodes named. Returns the ones that answered."""
    by_name = nodes(world)
    return [n.name for n in vpn.probe([by_name[n] for n in names], liveness(world), world.ports)]


def start(world: World) -> Any:
    by_name = nodes(world)
    return vpn.Start(mode=world.mode, node=by_name.get(world.exit) if world.exit else None)


@contextmanager
def logging_to(world: World):
    before = os.environ.get("RUN_LOG_DIR")
    os.environ["RUN_LOG_DIR"] = str(world.runs)
    try:
        yield
    finally:
        if before is None:
            del os.environ["RUN_LOG_DIR"]
        else:
            os.environ["RUN_LOG_DIR"] = before


def move(world: World, names: list[str], why: str, discord: bool) -> tuple[str, str | None]:
    """One move from where the exit node is now, through the nodes named. Returns the Outcome's kind and the
    node it pinned."""
    by_name = nodes(world)
    with logging_to(world):
        outcome = vpn.move(start(world), [by_name[n] for n in names], why, discord, lambda line: None,
                           lambda: None, liveness(world), world.ports)
    return outcome.kind, outcome.node.name if outcome.node else None


def run(world: World, script: list[tuple[AfterStep | At, Happening]]) -> World:
    """The watcher, started at the World's first moment, through everything the script makes happen and
    AFTER_SECS past its last timed event, stopping only while idle. Every request must have finished, once."""
    for trigger, happening in script:
        world.when(trigger, happening)
    world.end = T0 + world.last_at + AFTER_SECS
    world.arrive({"Prefs": world.prefs()})
    w = vpn.Watch()
    due = 0.0
    with logging_to(world):
        try:
            while True:
                world.idle = True
                arrival = world.wait(due)
                world.idle = False
                due = vpn.handle(w, arrival, world.ports)
        except Over:
            pass
    unfinished = {c.id: len(c.finishes) for c in world.callers if len(c.finishes) != 1}
    assert not unfinished, f"requests that did not finish exactly once, with their final lines counted: {unfinished}"
    return world
