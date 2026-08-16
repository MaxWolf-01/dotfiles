# SFTPGo file drop

Operating notes for the file drop on pc. What it is and how it is configured:
`nix/nixos/pc/sftpgo.nix`, which carries the rationale for each setting.

## Why only the web client is public

Funnel has a weaker trust story than tailnet-internal traffic. Tailscale controls
the `*.ts.net` DNS records and the ACME certificate, so a compelled or compromised
Tailscale can machine-in-the-middle Funnel ingress. Tailnet WireGuard traffic it
cannot. So the public binding serves the hardened login and nothing else, and
everything else stays on a binding the firewall keeps tailnet-only.

## First run

Accounts are credentials, not config, so they are in no repo. Bootstrap once:

1. Open `http://pc.tail710178.ts.net:8081/web/admin/login` from a tailnet device.
   With no admin in the database, SFTPGo shows its setup page. Create the admin
   there. Use that full path: the bare host redirects to the *client* login,
   which rejects admin credentials as invalid rather than saying you are in the
   wrong place. Use the MagicDNS name, not `pc`: a router that answers for `pc`
   hands back its LAN address, and the admin port is firewalled off every
   interface but tailscale0, so the short name hangs.
2. Enable TOTP on that admin (`Profile` → `Two-factor auth`).
3. Tick `Allow API key authentication` on that admin. Without it every API-key
   request answers 401, whatever the key's scope.
4. Mint an API key with admin scope (`Profile` → `API keys`). `sftpgo-user` needs
   it, and an API key bypasses TOTP, which is what makes unattended scripting work.
5. Store it: `sops ~/.dotfiles/secrets/api_keys/sftpgo`, then commit in the secrets
   repo. pc needs that commit too — `bin/sftpgo-user dump` runs there for the
   weekly backup and fails without the key.

Admins and users are separate namespaces, so the same name can exist as both with
different passwords. The admin login rejects a user's password and vice versa.

You are logged out by every restart: the JWT signing key is derived fresh at each
start, so a `nswitch` ends open sessions. Public share links are unaffected —
they are identified by URL, not by a signed token.

## Day to day

`sftpgo-user` prints its own usage. One thing it does not cover:

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

`backup/pcstate_snapshot.sh` stages a provider dump (accounts, quotas, shares,
event rules) into the weekly `pcstate` restic repo. Dropped files are not backed
up — they expire on their own.

Deleting an account leaves its files on disk, and retention only visits accounts
that exist, so nothing ever expires them. `sftpgo-user delete` prints the path to
remove.
