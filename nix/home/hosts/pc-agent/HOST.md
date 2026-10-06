---
host: pc
user: agent
isolated: true
---

# Worker host: agent@pc

OUT OF SERVICE since 2026-10-06: pc's RAM flips bits in what it writes. Spawn no worker here; workers already running finish. Remove this paragraph once memtest passes.

The almost-always-on machine: a headless NixOS box that also holds the personal
backups. It goes down on purpose now and again, but if it is off for extended
periods, something is usually wrong. Work belongs here when it is long, not
time-critical, or simply better off a laptop — dispatch waves, overnight jobs,
anything that has to outlive a lid closing.

@BODY@
