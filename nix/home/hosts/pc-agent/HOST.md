---
host: pc
user: agent
isolated: true
---

# Worker host: agent@pc

The almost-always-on machine: a headless NixOS box that also holds the personal
backups. It goes down on purpose now and again, but a machine that is off
usually means something is wrong. Work belongs here when it is long, not
time-critical, or simply better off a laptop — dispatch waves, overnight jobs,
anything that has to outlive a lid closing or wants more compute than a laptop
has. Its cores and memory are shared with whatever else the machine is doing at
the time.

## Available

@TOOLCHAIN@, plus `nix` with flakes so a project's own `nix develop` works,
rootless `docker` confined to this user, `claude` with the `mx` plugin, and the
public internet. Anything else a project needs comes from its own setup target,
inside the worktree.

## Belongs elsewhere

- **Work needing GitHub.** No credentials here: `gh` is unauthenticated and
  nothing can push or open a PR. History arrives by push from the orchestrator
  and leaves the same way.
- **Work needing the GPU.** Never a default pick. The card is here and nothing
  stops you, but a ticket runs on it only where it says to use pc's GPU in so
  many words; otherwise the work goes back.
- **Work needing another machine on the network.** Only the orchestrator's side
  can reach one.
- **Driving a real browser.** Headless renders work; a session you can click
  does not.
