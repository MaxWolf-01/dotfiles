## Philosophy

Everything rebuildable from version control. Dotfiles (public) for all config. `secrets/` is a separate private git repo living as a subdir — committed and pushed independently. It holds anything private or security-relevant; passwords/keys are additionally sops-encrypted on top. If it can't be rebuilt from VC, it's debt.

I'm learning Nix — explain what you do and suggest improvements proactively.

For device inventory, infrastructure, and backup architecture: always read `secrets/README.md` and `secrets/backup/README.md` before working on infra-related tasks.

## Git: Two Repos

`secrets/` is a **separate git repo** nested inside dotfiles. They share no history. When committing or running git commands, always use absolute paths or verify `git rev-parse --show-toplevel` to avoid operating on the wrong repo. Never `cd` into `secrets/` and forget — shell state persists between commands.

- Dotfiles: `git -C ~/.dotfiles ...`
- Secrets: `git -C ~/.dotfiles/secrets ...`

## Getting Started

ALWAYS read README.md to get a quick high-level overview of the project structure / setup / usage flow.

Flake check only sees igt tracked files.

## Claude Code Config

Two `claude`-related directories exist in this repo — don't confuse them:
- `.claude/` — repo-local project settings (e.g. `settings.local.json`). Scoped to this project only.
- `claude/` — source of truth for **global** `~/.claude/` config. Symlinked: `~/.claude/settings.json` → `~/.dotfiles/claude/settings.json`. Edits here apply globally across all projects.
- `~/repos/github/MaxWolf-01/agents` — agent config: plugins, skills, commands, prompts. The `mx` plugin lives there.

## Scripts

- When writing scripts (especially ones run by systemd timers or cron): include informative error messages. Print what failed, why, and what to check. Don't silently fail - these run unattended and failures need to be easy to debug after the fact.
- When writing cli script in python, use tyro for argument parsing, use tyro's features to document the script, so everything is documented with --help, without reading source code (e.g you can do description=__doc__ in tyro.cli()).

## Tmux

Config managed by Home Manager (`nix/home/tmux.nix`). After changes:
```bash
hmswitch && tmux source ~/.config/tmux/tmux.conf
```
Or: `hmswitch` then `Ctrl+a r` inside tmux.

**Scripted layouts:** When creating detached sessions (`new-session -d`), tmux uses a tiny default size (~80x24). Pass terminal dimensions to get correct proportions:
```bash
tmux new-session -d -s "$SESSION" -x "$(tput cols)" -y "$(tput lines)"
```

**When changing keybindings:** Update `docs/tmux-cheatsheet.md` to match!

## Home Manager

Structure:
- `flake.nix` — defines all hosts. PC is a NixOS system (with HM as module); laptops are HM standalone.
- `nix/home/common.nix` - CLI tools for all hosts (auto-included via mkHome)
- `nix/home/desktop.nix` - GUI apps (vesktop, nemo, fonts) — workstation machines only
- `nix/home/gnome.nix` - GNOME-specific (tiling-shell, dconf)
- `nix/home/kitty.nix` - terminal emulator
- `nix/home/newsboat.nix` - RSS reader with desktop notifications
- `nix/home/tmux.nix` - tmux config
- `nix/home/timers.nix` - systemd user timers, zephyrus only. Secrets via `EnvironmentFile` from `secrets/env/`
- `nix/home/pc-timers.nix` - PC timers (youtube, phone sync + backup, encrypted)
- `nix/home/x11.nix` / `wayland.nix` - display server specific
- `nix/home/hosts/` - per-machine configs (stateVersion + imports)
- `nix/nixos/pc/` - NixOS system config for PC (configuration.nix, hardware-configuration.nix, youtube-download.nix)

Host tiers:
- **CLI** (common.nix): every machine — shell, dev tools, restic, etc.
- **Workstation** (+ desktop.nix, gnome.nix, display server): zephyrus, xmg19
- **Server / NixOS** (nix/nixos/pc/ + pc-timers.nix): PC — headless, backup hub, GPU workers

Setup flow:
- `./setup minimal` installs Nix
- Laptops (HM standalone): `nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST`, then `hmswitch`
- PC (NixOS): `nswitch` (alias for `sudo nixos-rebuild switch --flake ...`) — rebuilds system + HM together

### Key Nix Concepts

**Pure vs Impure:**
- Pure: references files within the flake (e.g., `../../zsh/zshrc`) — Nix controls them, builds are reproducible
- Impure: references runtime paths (e.g., `${config.home.homeDirectory}/.dotfiles/...`) — Nix can't verify they exist
- Prefer pure paths. Impure is okay for live editing (symlinks that should update without hmswitch)

**stateVersion:**
- Per-machine, set to HM version first installed on that host
- NEVER change it — Nix uses it for data migrations
- On fresh OS install, set to current HM version

**builtins.readFile vs source:**
- `builtins.readFile ../../file` — bakes content in, changes require hmswitch, but rollback restores old content
- `source ~/.dotfiles/file` in initContent — runtime, changes apply immediately, rollback doesn't restore
- If your baked file sources other files, those sourced files are still runtime (hot reload works)

**Credentials:**
- Never put secrets in Nix-managed files (they go to /nix/store, could leak via binary caches)
- Use sops-nix/agenix for secrets, or keep them outside Nix entirely

**zshrc is pure now:**
- Changes to `zsh/zshrc` require `hmswitch` to take effect
- But files it sources (like `zsh/aliases`) are runtime — changes apply on new shell, no hmswitch needed

## NixOS on a New Machine

See `agent/knowledge/nixos-new-machine.md` (disko + nixos-facter + nixos-anywhere).

## What stays outside Nix

- Ubuntu-specific apt packages (pulseaudio-module-bluetooth) - system-level
- GNOME keybindings - keybindings.pl works fine

# Rime MCP

You have access to Nix tooling via the rime MCP server. Use it for Nix-related tasks in this project.

**Package/Flake Operations:**
- `nix_packages_search` — Search packages in nixpkgs or a flake
- `nix_packages_why_depends` — Show dependency chains between packages
- `nix_flakes_show` — Show flake outputs
- `nix_flakes_metadata` — Show flake metadata (inputs, locks)
- `nix_evaluate` — Evaluate Nix expressions
- `nix_log` — Get build logs for debugging

**Documentation (use these before web searches for Nix questions):**
- `manix_search` — Fast doc search across Nix/NixOS/HM options
- `home_manager_options_search` — Search Home Manager options specifically
- `nixpkgs_options_search` — Search NixOS module options for a specific nixpkgs ref
- `nvf_options_search` / `nvf_manual_*` — Search nvf (Neovim Flake) options
- `nix_manual_list` / `nix_manual_read` — Browse Nix manual source
- `nixos_wiki_search` / `nixos_wiki_read` — NixOS wiki access

**System Info:**
- `nix_config_show` — Current Nix configuration
- `nixos_channels` — Available channels and status
- `nixhub_package_versions` — Version history for a package (useful for pinning)

When to use rime vs web search:
- **rime first**: HM options, Nix builtins, package search, flake introspection
- **web search**: Tutorials, complex debugging, community patterns not in docs
