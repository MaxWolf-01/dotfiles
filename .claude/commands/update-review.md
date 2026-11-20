---
description: Review a flake lock bump: rate it routine, promising, critical or held, and write max's report.
---

You review one bump of the dotfiles flake lock before it reaches any of max's machines. `bin/update-review run` made it and ran you in its directory; `update-review --help` says what happens around you. max reads your report when he chooses, skims it, and applies the bump with one command or holds it. Write for that skim.

## What the directory holds

- `flake-lock.diff`: which inputs moved, from which revision to which.
- `diff-<host>.txt`: `nvd diff` of one host's system (or of the laptop's Home Manager) before and after: the packages whose version changed, were added or removed, and the closure size.
- `build-<host>.log`: present only for a host whose new config failed to build; the build's error is at its end. `build-<host>-old.log` beside it means the old lock failed too.

The hosts: zephylux, the laptop max works on (GNOME, an NVIDIA dGPU, Home Manager); pc, the backup hub (ZFS, NVIDIA, Docker, SFTPGo with a public surface); xmg19, a worker host (NVIDIA, Docker); jarvis and yapit-prod, Hetzner servers running Docker, once they run NixOS.

## What to look at

Every package that moved is a candidate, but most are routine. Read the changelog, release notes or advisory of each one that matters:

- the kernel, the NVIDIA driver, systemd, glibc, OpenSSH, OpenSSL, sudo, Docker, Tailscale, GNOME Shell and mutter, ZFS, Nix itself
- any package whose new version is a security release, or whose nixpkgs commit names a CVE
- any major version bump of a tool max uses directly

Look things up on the web rather than from memory: release notes, the project's changelog, the nixpkgs PR or commit that made the bump, NVD for a CVE. A CVE matters by whether it reaches a host here: a kernel network bug reaches every host, a GUI library bug only the laptop, a server daemon only where it runs.

## The rating

Pick one level:

- **held**: a build failed, a change is likely or suspected to break something on one of these hosts (a removed option, a driver regression reported upstream, a major version with migration steps, a reported boot or GPU problem), or you cannot judge a change that matters. Holding is cheap; max reads why and decides.
- **critical**: a security fix that reaches one of these hosts, and nothing that holds it.
- **promising**: a feature, speed or stability gain max would want to know about, and nothing above.
- **routine**: none of the above.

## The report

Markdown, short, in plain words. max is technical but not a specialist in each package; say what a change means for his machines, not only its name.

1. One line: the level and its reason.
2. The changes that set the level, each with what it is, which hosts it reaches, and a link to its source.
3. For held: what would have to be true to apply it, and what to check after.
4. The rest, briefly: notable version bumps per host, and the closure size change.
5. Last line: `Apply with update-review apply, or drop it with update-review dismiss.`
