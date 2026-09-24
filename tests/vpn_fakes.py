"""The world bin/vpn reaches through its ports, faked, and the ways a test drives bin/vpn in it.

A World is tailscaled, the network, the clock and Vesktop as one simulation,
in tailscaled's own shapes: full status and prefs, a Prefs bus message for
every change of preferences, and an engine update every 2 s carrying each live
peer's byte counters and last handshake. Its Mullvad nodes are Hosts, each
answering handshakes or not, carrying traffic or not, and blocked by Cloudflare
or not. Time is the World's own: waiting advances it, and nothing sleeps.

The World records what happens in it as Entries, in order: every step the
watcher takes through a port that acts (a probe, a `tailscale set`, a
connect, a Discord check), every change from outside, and every request's
sending, disconnection and final line.

The drivers at the bottom are the one place that knows how bin/vpn's functions
are called; a test states what happens, and they call.
"""

import hashlib
import heapq
import importlib.util
import itertools
import json
import os
import tempfile
from collections.abc import Callable
from dataclasses import dataclass, field, replace
from datetime import datetime, timezone
from importlib.machinery import SourceFileLoader
from pathlib import Path
from typing import Any

# bin/vpn fixes its state file and lock under XDG_RUNTIME_DIR when it loads.
os.environ["XDG_RUNTIME_DIR"] = tempfile.mkdtemp(prefix="vpn-fakes-")


def _load(path: Path):
    loader = SourceFileLoader("vpn", str(path))
    spec = importlib.util.spec_from_loader("vpn", loader)
    assert spec
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


vpn = _load(Path(__file__).resolve().parent.parent / "bin" / "vpn")

T0 = 1_800_000_000.0
ENGINE_SECS = 2.0
"""How often tailscaled pushes an engine update."""
RTT = 0.05
"""One round trip to any node that answers."""
DEMAND = 1500
"""Bytes this machine's applications send through the exit node between two engine updates; a node that carries answers twice that."""
SETTLE_SECS = 120.0
"""How long a run goes on after its last event."""
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
    """Forwards traffic to the internet; only a node that answers can."""
    blocked: bool = False
    """Cloudflare answers the Discord check through it with a 403."""

    @property
    def fqdn(self) -> str:
        return f"{self.name}.mullvad.ts.net"


State = tuple[str, str | None]
"""How the exit node is set: ("pinned", node), ("automatic", its pick) or ("off", None)."""


@dataclass(frozen=True)
class Entry:
    kind: str
    """send, disconnect, finish: a request's; outside, auto-move: a change from outside;
    set, probe, connect, discord: a step the watcher took."""
    t: float
    before: State
    state: State
    """The exit node after the entry."""
    req: int | None = None
    """The request a send, disconnect or finish is about."""
    logged: int | None = None
    """outside, auto-move: how many node-log lines there were when it happened."""
    what: Any = None
    """send: the request; set, outside: the target; probe: the node; connect: whether it answered;
    discord: the verdict; finish: (ok, message); auto-move: the new pick."""


# Things that happen in a World, at a time or after a step.


@dataclass(frozen=True)
class Ask:
    """A vpn command sends a request."""

    request: str
    place: str = ""


@dataclass(frozen=True)
class Outside:
    """A bare `tailscale set --exit-node=<target>`: an escape hatch, or max by hand."""

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
class Offline:
    """The control server changes a node's online flag."""

    name: str
    online: bool


@dataclass(frozen=True)
class Disconnect:
    """The command whose request is running goes away (Ctrl-C)."""


@dataclass(frozen=True)
class Vesktop:
    running: bool


@dataclass(frozen=True)
class Quiet:
    """tailscaled pushes no engine update for a while."""

    secs: float


@dataclass(frozen=True)
class BusGap:
    """The event bus carries nothing for a while, then reconnects; what changed meanwhile arrives as one change."""

    secs: float


Event = Ask | Outside | AutoMoves | Dies | Revives | Offline | Disconnect | Vesktop | Quiet | BusGap


@dataclass(frozen=True)
class AfterStep:
    """When the n-th step the watcher takes returns, counting from 1."""

    n: int


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
class Client:
    """The command at the other end of one request."""

    world: "World"
    id: int
    lines: list[str] = field(default_factory=list)
    result: tuple[bool, str] | None = None
    here: bool = True

    def say(self, line: str) -> None:
        if self.here:
            self.lines.append(line)

    def finish(self, ok: bool, message: str) -> None:
        self.result = (ok, message)
        self.world.note("finish", req=self.id, what=(ok, message))

    def connected(self) -> bool:
        return self.here


class World:
    def __init__(self, hosts: list[Host], state: State = ("off", None), *, auto_pick: str | None = None,
                 vesktop: bool = False):
        self.hosts = {h.name: h for h in hosts}
        self.mode, self.exit = state
        self.auto_pick = auto_pick or (state[1] if state[0] == "automatic" else None) or hosts[0].name
        self.vesktop = vesktop
        self.now = T0
        self.rx: dict[str, int] = {}
        self.tx: dict[str, int] = {}
        self.handshake: dict[str, float] = {}
        self.entries: list[Entry] = []
        self.clients: list[Client] = []
        self.steps = 0
        self.after_step: dict[int, list[Event]] = {}
        self.ready: list[object] = []
        self.schedule: list[tuple[float, int, Callable[[], None]]] = []
        self.seq = itertools.count()
        self.bus_down_until = 0.0
        self.quiet_until = 0.0
        self.last_at = 0.0
        self.end = float("inf")
        self.top = False
        self.runs = Path(tempfile.mkdtemp(prefix="vpn-fakes-runs-"))
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

    # --- what the World is

    def state(self) -> State:
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

    def resolve(self, target: str) -> State:
        """What `tailscale set --exit-node=<target>` sets."""
        if target == "":
            return ("off", None)
        if target == "auto:any":
            return ("automatic", self.auto_pick)
        want = target.removesuffix(".")
        for name, peer in self.peers().items():
            host = peer["HostName"]
            if want in (host, peer["DNSName"].removesuffix("."), peer["ID"], *peer["TailscaleIPs"]):
                return ("pinned", host)
        raise vpn.VpnError(f"tailscale set {target} failed: invalid value")

    # --- changes

    def note(self, kind: str, before: State | None = None, *, began: tuple[float, int] | None = None,
             **fields) -> Entry:
        """Record an entry; `began` places a step that took time where it started: its time and the entry index."""
        t, at = began or (self.now, len(self.entries))
        entry = Entry(kind, t, before or self.state(), before or self.state() if began else self.state(), **fields)
        self.entries.insert(at, entry)
        return entry

    def change(self, new: State) -> None:
        """Set the exit node as tailscaled does, and tell the bus."""
        old = self.exit
        self.mode, self.exit = new
        if self.exit is not None and self.exit != old and self.answers(self.exit):
            self.handshake[self.exit] = self.now + RTT
        self.arrive({"Prefs": self.prefs()})

    def watcher_sets(self, target: str) -> None:
        new = self.resolve(target)
        before = self.state()
        self.change(new)
        self.step("set", before, what=target)

    def happen(self, event: Event) -> None:
        before = self.state()
        match event:
            case Ask(request, place):
                client = Client(self, len(self.clients))
                self.clients.append(client)
                self.note("send", req=client.id, what=event)
                self.arrive(vpn.Request(request=request, place=place,
                                        client=vpn.Client(say=client.say, finish=client.finish,
                                                          connected=client.connected)))
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
            case Offline(name, online):
                self.hosts[name] = replace(self.hosts[name], online=online)
                self.arrive({"PeerChanges": [{"NodeID": int(stable_id(name)[1:7], 16), "Online": online}]})
            case Disconnect():
                running = next((c for c in self.clients if c.result is None and c.here), None)
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

    def when(self, trigger: AfterStep | At, event: Event) -> None:
        match trigger:
            case AfterStep(n):
                self.after_step.setdefault(n, []).append(event)
            case At(secs):
                self.at(T0 + secs, lambda: self.happen(event))
                self.last_at = max(self.last_at, secs)

    def step(self, kind: str, before: State | None = None, **fields) -> None:
        self.note(kind, before, **fields)
        self.steps += 1
        for event in self.after_step.pop(self.steps, []):
            self.happen(event)

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
        began, before = (self.now, len(self.entries)), self.state()
        through = self.exit
        ok = self.carries(through)
        if through is not None:
            self.tx[through] = self.tx.get(through, 0) + 120
            if ok:
                self.rx[through] = self.rx.get(through, 0) + 120
        self.advance(self.now + (3 * RTT if ok else timeout))
        self.step("connect", before, began=began, what=ok)
        return ok

    def discord(self) -> str:
        began, before = (self.now, len(self.entries)), self.state()
        if not self.carries(self.exit):
            verdict = "unreachable"
        elif self.exit in self.hosts and self.hosts[self.exit].blocked:
            verdict = "blocked"
        else:
            verdict = "clean"
        self.advance(self.now + 0.2)
        self.step("discord", before, began=began, what=verdict)
        return verdict

    def egress(self) -> dict:
        if not self.carries(self.exit):
            return {}
        mullvad = self.exit in self.hosts
        return {"ip": "185.0.0.1", "country": "", "city": "",
                "mullvad_exit_ip_hostname": self.exit if mullvad else None}

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
        if not self.top and self.now > self.end + HANG_SECS:
            raise Hang(f"the watcher was still busy {HANG_SECS:.0f} s after the run's last event")

    def wait(self, secs: float):
        """The Clock port's wait: the next arrival within `secs`, or None."""
        if self.top and self.now >= self.end and not self.ready:
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
    """Read a line in either vocabulary: `by`, `from` and `to`, or the older `command`, `node` and `rotated_to`."""
    event = stats.get("event", "")
    if "by" in stats:
        change = event in ("moved", "on", "off", "changed")
        return Line(event, change, stats["by"] == "outside", stats.get("from"), stats.get("to"))
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


def nodes(world: World) -> dict[str, object]:
    return {n.name: n for n in vpn.mullvad_nodes(world.status())}


def walk(hosts: list[Host], current: str | None) -> list[str]:
    """Where `vpn next` goes from `current`, in walk order."""
    world = World(hosts)
    by_name = nodes(world)
    return [n.name for n in vpn.candidates(by_name.get(current), list(by_name.values()))]


def walk_to(hosts: list[Host], place: str, current: str | None) -> list[str]:
    """Where `vpn to <place>` goes from `current`, in walk order."""
    world = World(hosts)
    by_name = nodes(world)
    everything = list(by_name.values())
    return [n.name for n in vpn.destinations(place, vpn.resolve(place, everything), by_name.get(current))]


def liveness(world: World):
    live = vpn.Liveness(clock=world.ports.clock)
    live.learn(world.status())
    return live


def probe(world: World, names: list[str]) -> list[str]:
    """Handshake-probe the nodes named: the ones that answered."""
    by_name = nodes(world)
    return [n.name for n in vpn.probe([by_name[n] for n in names], liveness(world), world.ports)]


def start(world: World):
    by_name = nodes(world)
    return vpn.Start(mode=world.mode, node=by_name.get(world.exit) if world.exit else None)


def move(world: World, names: list[str], why: str, discord: bool) -> tuple[str, str | None, list[str]]:
    """One move from where the exit node is now, through the nodes named: the
    Outcome's kind, the node it pinned, and the lines it said."""
    by_name = nodes(world)
    said: list[str] = []
    os.environ["RUN_LOG_DIR"] = str(world.runs)
    outcome = vpn.move(start(world), [by_name[n] for n in names], why, discord, said.append, lambda: None,
                       liveness(world), world.ports)
    return outcome.kind, outcome.node.name if outcome.node else None, said


def run(world: World, script: list[tuple[AfterStep | At, Event]]) -> World:
    """The watcher, started at the World's first moment, through everything
    the script makes happen and SETTLE_SECS after, stopping only while idle."""
    for trigger, event in script:
        world.when(trigger, event)
    world.end = T0 + world.last_at + SETTLE_SECS
    os.environ["RUN_LOG_DIR"] = str(world.runs)
    world.arrive({"Prefs": world.prefs()})
    w = vpn.Watch()
    due = 0.0
    try:
        while True:
            world.top = True
            arrival = world.wait(due)
            world.top = False
            due = vpn.handle(w, arrival, world.ports)
    except Over:
        pass
    return world
