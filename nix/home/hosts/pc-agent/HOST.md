---
host: pc
user: agent
isolated: true
---

# Worker host: agent@pc

The always-on machine: a headless NixOS box that also holds the backups, so it
stays up unless something is wrong. Long unattended work belongs here — dispatch
waves, overnight jobs, anything that has to outlive a laptop lid. Twelve cores
and 31 GB of RAM, shared with whatever else the machine is doing; its GTX 1650
is small and usually spoken for.

## Available

@TOOLCHAIN@, plus `nix` with flakes so a project's own `nix develop` works,
rootless `docker` confined to this user, `claude` with the `mx` plugin, and the
public internet. Anything else a project needs comes from its own setup target,
inside the worktree.

## Belongs elsewhere

- **Work needing GitHub.** No credentials here: `gh` is unauthenticated and
  nothing can push or open a PR. History arrives by push from the orchestrator
  and leaves the same way.
- **Work needing the GPU.** Nothing stops you using it, and that is the point:
  it is spoken for by this machine's own workers, so a ticket that wants it goes
  back rather than running here.
- **Work needing another machine on the network.** Only the orchestrator's side
  can reach one.
- **Driving a real browser.** Headless renders work; a session you can click
  does not.
