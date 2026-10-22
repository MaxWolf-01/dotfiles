## Available

@TOOLCHAIN@, plus `nix` with flakes so a project's own `nix develop` works,
rootless `docker` confined to this user, `claude` with the `mx` plugin, and the
public internet. Anything else a project needs comes from its own setup target,
inside the worktree.

The GPU, a GTX 1660 Ti with 6G, through CUDA from any process. It powers itself
off while nothing has it open and wakes when a program opens it. Two jobs on 6G
crash each other, so run one at a time: `nvidia-smi` shows whether another
process holds it.

Python comes only through `uv`: there is no `python3` on PATH, so a one-off is
`uv run python`. This is NixOS: `/usr/bin` holds `env` alone and `/bin` holds
`sh` alone. System binaries are under `/run/current-system/sw/bin`, which a
systemd unit or a script written for another host's PATH has to be given here.

## Belongs elsewhere

- **Work needing GitHub.** No credentials here: `gh` is unauthenticated and
  nothing can push or open a PR. History arrives by push from the orchestrator
  and leaves the same way.
- **Work needing a secret.** None is stored here. A job that needs an API key
  gets it passed in for that run.
- **Work needing another machine on the network.** xmg19 opens no tailnet
  connection at all; only the orchestrator's side can reach one.
- **Driving a real browser.** Headless renders work; a session you can click
  does not.

## After a reboot

xmg19's `/home`, this user's home with it, stays locked after every boot until
`host-unlock xmg19` on zephylux opens it, and no worker can run until then.
When `worker-hosts` cannot read this record, or shows xmg19 up for minutes, the
orchestrator runs `host-unlock xmg19` once.
