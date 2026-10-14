## Available

@TOOLCHAIN@, plus `nix` with flakes so a project's own `nix develop` works,
rootless `docker` confined to this user, `claude` with the `mx` plugin, and the
public internet. Anything else a project needs comes from its own setup target,
inside the worktree.

Python comes only through `uv`: there is no `python3` on PATH, so a one-off is
`uv run python`. This is NixOS: `/usr/bin` holds `env` alone and `/bin` holds
`sh` alone. System binaries are under `/run/current-system/sw/bin`, which a
systemd unit or a script written for another host's PATH has to be given here.

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
