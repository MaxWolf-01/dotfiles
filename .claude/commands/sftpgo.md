---
description: Share a file publicly, or mint/revoke a file-drop account, on the SFTPGo server on pc.
---

Reach the file drop on pc. Both tools print their own usage; run them with `--help`
for flags. This covers only which tool to reach for, and the model they assume.

## The model

An **account** is a login with a quota and a directory of its own. A **share** is a
link to one path inside an account. A share holds no storage — the quota is the
account's.

Admins and users are separate namespaces, so `max` exists as both, with different
passwords. `sftpgo-user` acts as the admin; `sftpgo-share` acts as the account.

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

## Reference

Bootstrap, the trust model, and how to debug a dead public URL: `docs/sftpgo.md`.
Why each setting is what it is: `nix/nixos/pc/sftpgo.nix`.
