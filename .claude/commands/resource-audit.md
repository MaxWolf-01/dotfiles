---
description: Measure what this setup costs to run — unattended units against battery, RAM, writes and watts; the interactive side against bytes written
argument-hint: "[host | unit | interactive]  e.g. pc, thermal-log, or nothing for the full pass"
---

The deliverable is measurements with options attached; max picks everything
that changes behavior (step 4 draws the line). Worked example with full
reasoning, including the rejected options and the numbers that killed them:
`secrets/dns-archive.md`, its "What it costs" section.

Scope: `$ARGUMENTS` — a host, one unit, `interactive`, or empty for everything.

## The two branches, two metrics

- **Unattended units** (timers, always-on services, containers): watts and
  wakeups. A timer costs a wakeup plus its run; an always-on service costs
  whatever it does between wakeups — they do not rank on one scale.
- **Interactive / on-demand work**: bytes written. Memory pressure converts
  directly into SSD writes through swap, so the write audit and the RAM audit
  are one audit. Attribute the device-level total to its top writers before
  proposing anything.

## Process

1. Map the surface on every host in scope: system + user timers and services,
   docker/podman, cron — OS-shipped included, since nobody chose it.
2. Rank by expected yield before measuring anything. Most units cost nothing;
   a handful are everything.
3. Per candidate: define the metric as a property of the implementation
   (bytes per row, ms per sample — not MB/day), compute its theoretical
   floor, then measure. Never reason where you can run it.
4. Report each finding as: measured value, floor, options with numbers, and
   whether each option is behavior-preserving. Cadence, retention, freshness,
   and anything that deletes data are max's judgments — implement only what
   he picks. A pure efficiency change (same behavior, cheaper) proceeds
   without asking.
5. Land picks in their IaC home (nix module, `setup`, `bin/`), re-measure,
   and record the result and the rejected options in the commit.

Done when every unit in scope is accounted for and every proposal carries its
measured value, its floor, and its behavior-preserving flag.

## Standing data sources — read before measuring anew

- Per-run outcomes, stats, dashboards: `docs/monitoring.md`.
- Battery, temperature, power caps: the thermal-log CSVs — path, cadence and
  retention in `bin/thermal-log`'s header.
- HDD spin behaviour on pc: `journalctl -u hd-idle` logs every spindown and
  spinup — match each wake against the known timers.

## Measurement reference (the non-obvious parts)

- Percent of a core: `CPUUsageNSec / (seconds since ActiveEnterTimestamp
  × 1e7)` (`systemctl show`). Counters reset when the unit restarts.
- Write attribution: cgroup `io.stat` per system service. The io controller
  is not delegated inside `user@1000`, so user units need `/proc/PID/io` —
  which misses dead children. There, `write_bytes` is storage-layer and
  trustworthy; `wchar` also counts tty and pipe output.
- Device truth is `/proc/diskstats` (sectors written × 512). Churn vs growth:
  a file rewritten in place shows in the counters and never in `df`.
- Swap (`/proc/vmstat`, × 4 KB each): `zswpout` is what zswap absorbed in
  RAM; `pswpout` is what actually reached the swap device.
- Root-only probes (RAPL watts, `hdparm -C`, HDD spin state) get a one-shot
  read-only script for max to run — RAPL zones sampled in one shared window,
  counter wrap handled via `max_energy_range_uj`.
- Suspect long stretches of the machine failing to suspend: count `Freezing
  user space processes failed` in the journal; FUSE mounts (AppImages, SSHFS)
  are the usual D-state culprit.

## Settled by max — re-raise only with new evidence

- Claude Code sessions are off limits: many processes is the workflow itself,
  and there is no lever on session cost from this side.
- vibe-typer stays resident; the hotkey needs it warm.
- `~/.cache` growth is disk space, not efficiency — not a finding.
- Shell startup is fast enough; `bin/` script latency matters only when max
  complains about a specific one.
- Browser and Electron RAM is a separate task; never fold it into this audit.
- Scripts that run rarely or are network-bound are skipped outright:
  frequency × per-run cost rounds to zero, and auditing them costs more than
  it saves.
- History outranks disk: retention windows and save cadences (tmux-resurrect
  and kin) are deliberate choices — current values live in the nix modules.
  Cheaper never justifies staler.
- tailscaled's CPU is exit-node WireGuard crypto, by design; the
  vpn-watchdog poll interval is a chosen detection latency.
