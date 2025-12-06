I'm transitioning to Nix (Home Manager standalone on Ubuntu for now, NixOS later).
Since I'm a beginner to Nix, explain what you do and be proactive in suggesting improvements.

Check out the README for overview. Also secrets/README.md and secrets/backup/README.md for system context.

## Scripts

When writing scripts (especially ones run by systemd timers or cron): include informative error messages. Print what failed, why, and what to check. Don't silently fail - these run unattended and failures need to be easy to debug after the fact.

## Home Manager Migration

Structure:
- `flake.nix` in root, host configs in `nix/home/hosts/`
- `nix/home/common.nix` - shared packages
- `nix/nix.conf` - enables flakes (symlinked by dotbot/install)
- Existing configs (zsh, nvim, etc.) stay as files, symlinked separately (not by HM)

Setup flow:
- `./setup minimal` installs Nix
- First run: `nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST`
- After that: `hmswitch` alias

## What to move to Nix (and why)

The main win is **one package manager instead of four** (apt + brew + cargo + uv).

Move to Nix:
- CLI tools (ripgrep, fzf, zoxide, tree, jq, tmux) - no more apt vs brew vs cargo confusion
- Dev tools (neovim, git, ruff, btop, dysk) - reproducible, rollback if updates break
- GUI apps (discord, obsidian, vesktop) - Nix handles updates cleanly, no manual downloads

Keep as-is:
- Secrets/SOPS workflow - just install `sops` and `age` via Nix
- Ubuntu-specific apt packages (pulseaudio-module-bluetooth) - system-level integration
- Symlinks - simple script, not worth using HM for this
- GNOME keybindings - keybindings.pl works fine
- Systemd timers - current setup works, minor gain from HM

## TODOs

- Migrate remaining packages from `setup` script to common.nix
- Remove brew once all its packages are in Nix
- Remove cargo-installed tools (dysk) once in Nix
- Keep README in sync with setup flow
- Eventually replace dotbot with simple symlink script

