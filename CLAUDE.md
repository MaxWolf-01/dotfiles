I'm transitioning to Nix (Home Manager standalone on Ubuntu for now, NixOS later).
Since I'm a beginner to Nix, explain what you do and be proactive in suggesting improvements.

Check out the README for overview. Also secrets/README.md and secrets/backup/README.md for system context.

## Scripts

When writing scripts (especially ones run by systemd timers or cron): include informative error messages. Print what failed, why, and what to check. Don't silently fail - these run unattended and failures need to be easy to debug after the fact.

## Home Manager

Structure:
- `flake.nix` in root defines hosts (zephyrus, xmg19, minimal)
- `nix/home/common.nix` - CLI tools for all hosts
- `nix/home/desktop.nix` - GUI apps (vesktop, nemo, fonts)
- `nix/home/gnome.nix` - GNOME-specific (tiling-shell, dconf)
- `nix/home/x11.nix` / `wayland.nix` - display server specific
- `nix/home/hosts/` - per-machine configs that import modules
- `nix/nix.conf` - enables flakes (symlinked by setup script)
- Existing configs (zsh, nvim, etc.) stay as files, symlinked by setup script

Setup flow:
- `./setup minimal` installs Nix
- First run: `nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST`
- After that: `hmswitch` alias

## What stays outside Nix

- Ubuntu-specific apt packages (pulseaudio-module-bluetooth) - system-level
- btop - compiled from source for GPU support
- GNOME keybindings - keybindings.pl works fine

## TODOs

- Move config symlinks to HM for Nix-managed tools (nvim, kitty, ruff → home.file in respective modules)
- Move ~/.icons to gnome.nix
- nixGL for GPU acceleration in Electron apps (vesktop currently uses --disable-gpu)

