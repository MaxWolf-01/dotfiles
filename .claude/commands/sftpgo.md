---
description: The file drop on pc (SFTPGo). Use when asked to send or share a file with someone, hand out or revoke access to the drop, collect files from someone, or put files onto pc's drop — and before touching accounts or shares in its web admin.
---

Reach the file drop on pc. Both tools print their own usage; run them with `--help`
for flags. This covers only which tool to reach for, and the model they assume.

## The model

An **account** is a login with a quota and a directory of its own. A **share** is a
link to one path inside an account. A share holds no storage — the quota is the
account's.

Admins and users are separate namespaces, so `max` exists as both, with different
passwords. `sftpgo-user` acts as the admin; `sftpgo-share` acts as the account.

Sharing a directory hands out two links at once, and `create` prints both: the
`/browse` one opens a file browser, the same link without it streams the whole
tree as one zip.

## Which tool

| Goal | Command |
| --- | --- |
| Send a file to someone without an account | `sftpgo-share create <path>` |
| See or revoke live links | `sftpgo-share list`, `sftpgo-share revoke <id>` |
| Give someone ongoing access | `sftpgo-user add <name> --quota 10` |
| Collect files from someone without an account | `sftpgo-user add`, then `delete` when done |
| Take access away | `sftpgo-user delete <name>` |
| Put files in max's own area | `sftp drop` (SSH-key auth, tailnet only) |

`sftpgo-share create` is read-only by design: a visitor downloads, never writes.
Write shares let anyone holding the link overwrite files silently
(drakkan/sftpgo#2232), which a throwaway account avoids while also recording who
uploaded what.

Deleting an account is what revokes it. Disabling leaves every link it created
serving, and deletion leaves the files on disk — `delete` prints the path.

A generated share password is printed once, at creation, and cannot be recovered
— pass it back to whoever asked, along with the link and expiry. `--password`
takes one of your choosing, for when it has to be said out loud.

## Web admin and these tools disagree

Saving a user form in the web admin writes every field on that page, so a form
opened before a CLI change reverts it on save. Quota bumps and key additions have
been lost this way. Change an account through one of them per sitting, and reload
the page after any CLI change.

## Reference

Bootstrap, the trust model, and how to debug a dead public URL: `docs/sftpgo.md`.
Why each setting is what it is: `nix/nixos/pc/sftpgo.nix`.
