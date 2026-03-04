---
description: Update Home Manager packages — flake update, build, review diff, switch, commit.
---

Update nixpkgs + home-manager flake inputs, preview changes, and switch.

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
