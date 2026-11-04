---
description: Download the saved posts of a new Instagram export into pc's archive. Use when max has a new Instagram "Download your information" export, or asks to fetch his saved Instagram posts.
---

`secrets/scripts/instagram-saves` does the work; `instagram-saves --help` and
`instagram-saves fetch --help` say what it records and what its exit codes mean.
The archive is `~/data/encrypted/instagram-saves` on pc: the media, one directory
per post owner, `saved.tsv` (the post list) and `ledger.tsv` (every attempt).

1. **Collect the export.** It has to be in JSON format, one zip per account.
   Exports live in `~/Documents/lifelog/raw/instagram/` on zephylux, beside the
   older ones.
2. **Rebuild the post list** from every export there, the old ones too:
   `instagram-saves list ~/Documents/lifelog/raw/instagram/*.zip`, copied over
   pc's `saved.tsv`. The ledger already settles every post an older export
   listed, so only the new ones get requested. Done when pc's `saved.tsv` has at
   least as many lines as before.
3. **Fetch on pc** as a job (`/mx:tmux`):
   `instagram-saves fetch ~/data/encrypted/instagram-saves/saved.tsv --dest ~/data/encrypted/instagram-saves --require-mount ~/data/encrypted`.
   Done when it exits 0 or 1 (every post requested). Exit 2 means Instagram
   refused pc's IP: go to step 4.
4. **On a refusal, ask max** before fetching from another IP. Once he says yes,
   fetch from zephylux through Mullvad into a copy:
   - Note how many lines pc's ledger has, then copy `saved.tsv` and `ledger.tsv`
     into an empty directory on zephylux and run `fetch` with `--dest` set to it.
   - Rsync the media to pc with `--ignore-existing`, excluding both TSVs, and
     check them with a `-c` (checksum) dry run.
   - Append the ledger lines past pc's old count to pc's ledger, then delete
     the copy.

   A run stops on the first refusal. Moving to another Mullvad node after a
   refusal is for max to decide.
5. **Report the residue.** An `unavailable` post is private or deleted, and a
   logged-out fetch never gets it. An `error` with a `rsrc.php/null.jpg` URL
   is a placeholder that fails on every retry. Count both from the ledger
   (`--help` has the queries).
