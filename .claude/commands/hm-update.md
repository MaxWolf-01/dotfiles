---
description: Update Home Manager packages — flake update, build, review diff, switch, commit.
---

Update nixpkgs + home-manager flake inputs, preview changes, and switch; then offer to move any pinned page script that has a newer release.

## Steps

### 1. Update flake inputs

```bash
cd ~/.dotfiles && nix flake update
```

Note the nixpkgs date range from the output (old → new).

### 2. Build without switching

```bash
home-manager build --flake ~/.dotfiles#$NIX_HOST
```

### 3. Get current generation path

```bash
home-manager generations | head -1
```

Extract the `/nix/store/...` path from the output.

### 4. Preview version diff

```bash
nvd diff <current-generation-path> ~/.dotfiles/result
```

### 5. Review and present to user

Analyze the nvd diff. Flag:
- **Major version bumps** (e.g. node 22→24, gcc 14→15) — note potential breakage
- **Removed packages** — check if any were explicitly installed vs transitive deps
- **Downgrades** `[D.]` — usually beta→stable, but verify
- **New packages** `[A.]` — note if anything unexpected appeared

Present a concise summary: notable upgrades, anything concerning, and your recommendation.

### 6. Wait for user approval

Do NOT switch until the user confirms. If they want to inspect something further, help them.

### 7. Switch

Once approved:
```bash
hmswitch
```

If it fails (clobbered files, etc.), diagnose and fix.

### 8. Verify

Open a new shell or run a quick sanity check relevant to what changed.

### 9. Commit

Stage and commit `flake.lock` (and any other files changed during the process):

```bash
cd ~/.dotfiles && git add flake.lock && git commit -m "nix: update flake inputs (YYYY-MM-DD)"
```

Use the actual nixpkgs date in the commit message. Include other changed files if the update required fixes.

### 10. Pinned scripts

Some pages load scripts from jsDelivr at an exact version checked against its hash: the mx plugin's pages, `diffview`, `container-hub`. The flake does not move them; each pin moves only as a reviewed edit.

```bash
script-pins
```

lists every pin beside its newest release. Show the user the ones with a newer release and ask which to move. For each one they want moved, before editing anything, spawn a subagent to read what changed between the two versions: the upstream diff between the two release tags, and the files the page loads at both versions (`https://cdn.jsdelivr.net/<npm|gh>/<package>@<version>/<file>`). It reports anything that would read or send data: a network call (`fetch`, `XMLHttpRequest`, `WebSocket`, `sendBeacon`, an element whose `src` or `href` it sets), a read of cookies, storage or the page beyond what the library is handed, `eval` or `Function` over text it fetched, and a built file that does not match its source. Put the report in front of the user and move the pin only on their yes.

A pin moves as one edit of its version and every hash under it, in the file `script-pins` named: `HLJS_VERSION` with `HLJS` in `diffview`, `TRELLIS_VERSION` with `TRELLIS` in `container-hub`, a URL with its `integrity` in the agents repo. jsDelivr lists each file's sha256, base64, at `https://data.jsdelivr.com/v1/packages/<npm|gh>/<package>@<version>?structure=flat`; the scripts here pin it in hex (`base64 -d | od -An -tx1 | tr -d ' \n'`). Fetch one file and `sha256sum` it against the listing, run the script's tests, open a page it renders, and commit each move on its own, in its own repo.
