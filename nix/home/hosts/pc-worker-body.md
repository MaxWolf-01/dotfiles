## Available

@TOOLCHAIN@, plus `nix` with flakes so a project's own `nix develop` works,
rootless `docker` confined to this user, `claude` with the `mx` plugin, and the
public internet. Anything else a project needs comes from its own setup target,
inside the worktree.

## Capacity

Six workers at once, agent@pc and agent-hl@pc counted together: they share one
memory budget, with no swap. Past it the kernel kills the largest worker
process, a `claude` or what it runs, and that worker ends while pc stays up. A
process that crashes larger than 2 GiB leaves a journal entry and no core dump.

## Belongs elsewhere

- **Work needing GitHub.** No credentials here: `gh` is unauthenticated and
  nothing can push or open a PR. History arrives by push from the orchestrator
  and leaves the same way.
- **Work needing the GPU.** Never a default pick. The card is here and nothing
  stops you, but a ticket runs on it only where it says to use pc's GPU; otherwise the work goes back.
- **Work needing another machine on the network.** Only the orchestrator's side
  can reach one.
- **Driving a real browser.** Headless renders work; a session you can click
  does not.
