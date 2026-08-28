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

Dropped files expire on their own: a nightly job deletes anything whose
modification time is older than the retention window, in every account, max's
included. The window is `retentionMonths` in `nix/nixos/pc/sftpgo.nix`. A share
outlives its file and starts answering 404 once the file is swept.

## Which link to hand out

`create` prints the one to send as `link:`. It is already the right shape — the
choice below is only about which *path* you share, and about the second link a
directory also gets.

| Shared path | `link:` | What the recipient gets |
| --- | --- | --- |
| One file | `?compress=false` | the file itself, streamed |
| A directory | `/browse` | a file browser |
| A directory | `zip:`, printed second | the whole tree as one archive |

`?compress=false` is not decoration: the plain URL answers with
`share-<name>.zip` whatever the path is, so without it a lone video reaches its
recipient as an archive to unpack. Range requests work on it, so the file
streams and seeks, and Discord embeds it inline.

The browse page plays media in the page — `mp4 mov webm ogv ogg mp3 wav` in a
player, `jpg png gif webp bmp svg` in a lightbox, `pdf` in a viewer. So share the
*directory* when the ask is "look at this, take what you want", and reach for the
`zip:` link only when it is "here, keep all of this". A directory of one video is
a fine thing to make on purpose: a file share can never play in the browser,
because SFTPGo sends every share download as an attachment.

## Which tool

| Goal | Command |
| --- | --- |
| Send a file to someone without an account | `sftpgo-share create <path>` |
| See or revoke live links | `sftpgo-share list`, `sftpgo-share revoke <id>` |
| Give a link more downloads or more time | `sftpgo-share update <id>` |
| Give someone ongoing access | `sftpgo-user add <name> --quota 10` |
| Collect files from someone without an account | `sftpgo-user add`, then `delete` when done |
| Take access away | `sftpgo-user delete <name>` |
| Replace a lost or leaked password | `sftpgo-user passwd <name>` |
| Put files in max's own area | `sftp drop` (SSH-key auth, tailnet only) |

`sftpgo-share create` is read-only by design: a visitor downloads, never writes.
Write shares let anyone holding the link overwrite files silently
(drakkan/sftpgo#2232), which a throwaway account avoids while also recording who
uploaded what.

Deleting an account is what revokes it. Disabling leaves every link it created
serving, and deletion leaves the files on disk — `delete` prints the path.

A link's cap and expiry stay editable for its whole life, so neither is a
decision to agonise over at creation. Raising the cap on a used-up link revives
it, keeping the count: 3/3 raised to 5 leaves two downloads, not five. Expiry is
recounted from now, and `--expires never` drops it.

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
