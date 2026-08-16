# SFTPGo file drop

A file drop on pc for max and friends. Config: `nix/nixos/pc/sftpgo.nix`.

| Surface | Address | Who can reach it |
| --- | --- | --- |
| Web client | `https://pc.tail710178.ts.net/` | anyone on the internet, via Tailscale Funnel |
| Web admin + REST API | `http://pc:8081/` | tailnet only |
| SFTP | `pc:2022` | tailnet only |

Files live under `/srv/sftpgo/<username>`, not under `/home`: the NixOS module runs
the daemon with `ProtectHome = true`, so `/home` is invisible to it.

## Why only the web client is public

Funnel has a weaker trust story than tailnet-internal traffic. Tailscale controls
the `*.ts.net` DNS records and the ACME certificate, so a compelled or compromised
Tailscale can machine-in-the-middle Funnel ingress. Tailnet WireGuard traffic it
cannot. So the public binding serves the hardened login and nothing else — the
admin UI, the REST API and the OpenAPI renderer are off there, which makes the
admin login, the first-run setup page, the token endpoints and password reset all
return 404 from the internet.

## First run

Accounts are credentials, not config, so they are not in any repo. Bootstrap once:

1. Open `http://pc:8081/` from a tailnet device. With no admin in the database,
   SFTPGo shows its setup page. Create the admin there.
2. Enable TOTP on that admin (`Profile` → `Two-factor auth`).
3. Tick `Allow API key authentication` on that admin. Without it every API-key
   request answers 401, whatever the key's scope.
4. Mint an API key with admin scope (`Profile` → `API keys`). `sftpgo-user` needs
   it, and an API key bypasses TOTP, which is what makes unattended scripting work.
5. Store it: `sops ~/.dotfiles/secrets/api_keys/sftpgo`, then commit in the secrets
   repo. pc needs that commit too — `bin/sftpgo-user dump` runs there for the
   weekly backup and fails without the key.

Sessions do not survive a restart. `httpd.signing_passphrase` is deliberately
empty, so SFTPGo derives a fresh JWT signing key at every start and you log in
again after each `nswitch`. The alternative — putting the passphrase in
`services.sftpgo.settings` — renders it into the world-readable `/nix/store`, and
anyone holding it can forge a full-admin token offline without logging in, TOTP
included. Public share links are unaffected: they are identified by URL, not by a
signed token.

## Day to day

`sftpgo-user` with no arguments prints its usage. Two things it cannot tell you:

**Deleting is the only complete revocation.** A disabled account (status 0) blocks
that person's own login, but every public share link they created keeps working,
for both read and write. Deleting the account revokes the links with it. Setting
the `shares-disabled` flag on the account has the same effect on their links
without removing the account.

**A write share allows anonymous overwrite.** Public shares expose download,
browse and upload; there is no delete or rename endpoint for them. But a share
connection runs as the share's *owner*, with the owner's per-directory
permissions, and a normal account holds `*` on `/` — which includes `overwrite`.
So anyone with a write-share link can replace a file already at that name, with no
warning. The missing warning is deliberate upstream: prompting "that name exists"
would leak the existence of files an anonymous uploader may not see. Tracked as
[drakkan/sftpgo#2232](https://github.com/drakkan/sftpgo/issues/2232). Two fixes,
neither applied here: drop `overwrite` from the owner's permissions on that
directory (uploads to an existing name then fail and the upload is lost), or add a
pre-upload event rule that renames the existing file aside on collision. Read-only
shares cannot write at all and need neither.

## Declared state

`services.sftpgo.loadDataFile` carries provider state that holds no secrets, and
SFTPGo re-applies it at every start:

- the nightly retention rule — files untouched for 9 months are deleted, on every
  account including max's
- `127.0.0.1` on the defender and rate-limiter safe lists

Retention measures a file's modification time. `common.setstat_mode = 1` therefore
ignores client-requested timestamp changes, so mtime records when a file arrived.
Without that, uploading with `sftp -p` or `rsync -t` would carry the original
timestamp across, and anything older than nine months would be deleted the same
night it was uploaded.

That safe list is a backstop, not a convenience. Every ban, rate limit and
per-host connection cap keys on the client IP that SFTPGo resolves from
`X-Forwarded-For`. If that resolution ever breaks, every Funnel request collapses
to `127.0.0.1` and one person's failed logins would ban everybody at once. Safe
listing that address trades brute-force protection for availability in exactly
that failure.

## When the public URL stops working

`tailscale funnel status` reporting "Funnel on", and the public DNS records
resolving, both say nothing about whether traffic reaches the daemon — they are
set by code that never consults the ingress path. A Funnel that is dead end to
end still looks healthy in both.

The signal is on pc:

```
journalctl -u tailscaled | grep -i ingress
```

`peerapi: ingress: denied; no ingress cap` means Tailscale's ingress relays are
reaching pc and being refused, so no certificate is presented and every external
client dies at the TLS handshake with `unexpected eof while reading`. `Drop: TCP
... no rules matched` alongside it means the tailnet policy is refusing the
relays' packets outright.

## Backup

`backup/pcstate_snapshot.sh` stages an SFTPGo provider dump (accounts, quotas,
shares, event rules) into the weekly `pcstate` restic repo. Dropped files are not
backed up — they expire after 9 months by design.
