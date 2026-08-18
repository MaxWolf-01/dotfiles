# Monitoring

Every scheduled job here — backups, syncs, the DNS audit, yapit's nightly
report — writes down what it did. A notification is reserved for something that
needs a person and will not resolve itself.

Three layers carry the rest:

| Layer | What it holds | Where |
| --- | --- | --- |
| Run log | one JSON line per run: outcome, why, the run's own numbers | `~/logs/runs/<unit>.jsonl`, appended by `bin/run-log` |
| Overdue watchdog | the only scheduled alerter: one ntfy naming every unit that stopped succeeding | `bin/overdue-check`, daily on both hosts |
| Dashboards | one static HTML page per topic, rebuilt hourly, read when there is time | `~/Documents/dashboards/` |

The split answers two ways this setup failed before. A message on every green
run teaches you to swipe the channel away, and the red one goes with it. A job
that skips — locked dataset, phone away, unreachable backup target — exits 0
having done nothing, which from the outside is indistinguishable from a run
that worked; phone backups were dead for months that way, and the incident is
in `secrets/backup/README.md`. Only the job itself knows which of the two it
did, so it writes that down, and the watchdog reads the record instead of the
exit code.

## A notification arrived

Everything that can send one, and where it points:

| Title | Sender | What it means | Where to look next |
| --- | --- | --- | --- |
| `❌ <unit> - Backup Failed` | `backup/restic_backup.sh` | that run left no snapshot; the message carries restic's own error | the same run is a `fail` line in `~/logs/runs/<unit>.jsonl`, with the path to the error log |
| `⚠️ <unit> - Integrity Check Failed` | `backup/restic_backup.sh` | `restic check` found damage in the repository | `/backup-audit <unit>` — it opens the repo and reports what is broken |
| `🕸️ Overdue units` | `bin/overdue-check` | every unit and repo listed has had no successful run inside its bound | the unit's run log, then its bound (below) |
| `⚠️ Yapit health` / `⚠️ Yapit deps` | `scripts/report.sh` / `scripts/dep-scout.sh` in `~/repos/code/yapit-tts/yapit`, on yapit's own topic | last night's agent found issues, or a dependency needs acting on | the report itself, on the yapit dashboard |

Nothing else on these two machines sends on its own. A green backup, a skipped
one, a newly blocked domain, an exit node rotation, a routine dependency
report: run log and dashboard only. `🔍` in a yapit title means the report had no readable
status line, so the setup could not tell whether the agent found anything and
says so rather than staying quiet. (yapit's deploy script and its Cloudflare
firewall sync notify too, from the yapit VPS, and are no part of this.)

## Run logs

The envelope and the vocabulary are in `run-log --help`: `ok`, `skip`, `fail`,
the reason a skip or a fail must carry, and the per-job `stats` object. Each
host writes its own logs and nothing collects them into one place, so pc's are
read over ssh by whatever needs them.

```bash
jq . ~/logs/runs/working-rsyncnet.jsonl             # every run, oldest first
jq 'select(.outcome != "ok")' ~/logs/runs/*.jsonl  # everything that did not work
ssh pc jq . logs/runs/phone-sync.jsonl
```

A `skip` says a precondition the job does not control was absent, so it
deliberately did nothing: expected, and never an alert on its own. A skip
streak that never ends becomes visible through the watchdog bound below.

## "unit X hasn't run in N days — is that a problem?"

`secrets/monitoring/overdue.conf` is the written answer, one line per unit:
which host holds its evidence, how many days it may go without a successful
run, and which witness to read (its run log, or systemd's record of the last
clean finish). The file's own header explains the columns; `bin/overdue-conf`
is the parser that defines the syntax, and both the watchdog and the three
dashboard collectors read the file through it. Restic repos are not in there —
each carries its own bound as `max_age_days` in
`secrets/backup/restic/<repo>/_common` (default 14).

Adding a job to the watch is that one line and nothing else. Silent jobs belong
there most of all: nothing else would ever notice them stopping.

```bash
overdue-check --dry-run          # the full check, printed, sends nothing
overdue-check --help             # bounds, hosts, what counts as a success
systemctl --user start overdue-check.service
```

Both hosts run the check daily and each judges the other's units over ssh
(`nix/home/timers.nix`, `nix/home/pc-timers.nix`). pc runs the bounds as
written; the laptop adds `--extra-days 7`, so pc alerts first and the laptop
only speaks up about what pc stopped saying — one message out of a healthy
setup, and a dead pc still surfaces a week later.

A host or backup target that cannot be reached is skipped rather than alerted,
and printed on stdout only. That silence is bounded: a repository the probe
cannot open is dated from the run log of whichever host makes that backup, and
an outage outlasting the repo's `max_age_days` alerts with the unreachability
named. A repository nothing can date — no run log on the host that backs it up
— is reported, not skipped. The mechanics are in the comments at the top of
`bin/overdue-check`.

## Dashboards

Three pages, all in `~/Documents/dashboards/`: `backups.html`, `dns-vpn.html`,
`yapit.html`. They are bookmarked in Firefox under `Dashboards` in the
bookmarks menu (`nix/home/firefox.nix`; the bookmarks toolbar is off). That
folder is the index — the pages do not link each other.

Each page is one self-contained file written by its own collector,
`secrets/scripts/dashboard-<topic>`, on an hourly timer in
`nix/home/timers.nix`. `dashboard-<topic> --help` says what that page reads and
from where; `--json` prints the same data unrendered. They live in `~/Documents`
because Firefox runs firejailed and can see that directory, and a symlink into
`~/.dotfiles` dangles inside the jail.

What the pages will not do: open a restic repository, or run anything. Every
figure on them, repository sizes included, was measured by the job that wrote
it down, and the buttons copy prompts and commands to the clipboard rather than
launching them. A source that cannot be read keeps its last reading and the
header says how old it is, so pc being asleep is a label rather than an error.

```bash
systemctl --user start dashboard-backups.service   # rebuild now
dashboard-backups --json | jq '.repos[] | select(.state != "ok")'
```

Each collector logs its own runs and carries a bound in `overdue.conf`, so a
page that silently stopped refreshing is itself an overdue unit.

## A row is red

The row's note names the cause; it comes from the run log line the job wrote.
From there:

1. `jq . ~/logs/runs/<unit>.jsonl` — the failing run in full, including the
   path to whatever log it left behind.
2. `journalctl --user -u <unit>.service` — what the process printed, when the
   run log line is missing or says nothing useful.
3. `/backup-audit [unit|host]` — the deep pass for backups, and the only thing
   here that opens the repositories: are the snapshots the run logs claim
   really there, is anything damaged, what changed. It costs minutes, so it
   runs on demand; the dashboard's buttons copy the prompt that starts it. A
   Claude Code command in this repo, `.claude/commands/backup-audit.md`.

## Adding a job to all this

1. Have the job call `bin/run-log` on every path it can end on, including the
   ones where it deliberately does nothing. Reach it by a path relative to the
   script — systemd units pin their own PATH and none of them carries `~/bin`.
2. Add its line to `secrets/monitoring/overdue.conf`.
3. Run it once. A unit with no successful run on record is overdue from the
   moment its line exists, which is intended, and seeding it stops the first
   alert being about the line you just added.
4. If it belongs on a page, add its row to that topic's collector. Bounds,
   cadence and which host runs what are read from the config, the run log and
   the timer files — a collector states none of them itself.
