I'm transitioning to Nix (Home Manager standalone on Ubuntu for now, NixOS later).
Since I'm a beginner to Nix, explain what you do and be proactive in suggesting improvements.

Check out the README for overview. Also secrets/README.md and secrets/backup/README.md for system context.

## Scripts

When writing scripts (especially ones run by systemd timers or cron): include informative error messages. Print what failed, why, and what to check. Don't silently fail - these run unattended and failures need to be easy to debug after the fact.

## Home Manager

Structure:
- `flake.nix` in root defines hosts (zephyrus, xmg19, minimal)
- `nix/home/common.nix` - CLI tools for all hosts (auto-included via mkHome)
- `nix/home/desktop.nix` - GUI apps (vesktop, nemo, fonts)
- `nix/home/gnome.nix` - GNOME-specific (tiling-shell, dconf)
- `nix/home/x11.nix` / `wayland.nix` - display server specific
- `nix/home/hosts/` - per-machine configs (stateVersion + imports)
- `nix/nix.conf` - enables flakes (symlinked by setup script)

Setup flow:
- `./setup minimal` installs Nix
- First run: `nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST`
- After that: `hmswitch` alias (or `s home-manager` then `hmswitch`)

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

## What stays outside Nix

- Ubuntu-specific apt packages (pulseaudio-module-bluetooth) - system-level
- btop - compiled from source for GPU support
- GNOME keybindings - keybindings.pl works fine

## TODOs

- Move config symlinks to HM for Nix-managed tools (nvim, kitty, ruff → home.file in respective modules)
- Move ~/.icons to gnome.nix
- nixGL for GPU acceleration in Electron apps (vesktop currently uses --disable-gpu)
- Consider programs.vesktop module for declarative Discord config

# Memex MCP

You have access to markdown vaults via memex. Use them to find past work, discover connections, and document knowledge that helps future sessions.

Vaults:
- /home/max/repos/github/MaxWolf-01/claude-global-knowledge — Your global knowledge: cross-project learnings, user preferences, workflow insights
- /home/max/repos/obsidian/knowledge-base — My personal knowledge base (Obsidian). Everything about me, my work, interests, projects, life. Usually you don't need to search here unless specifically instructed. Narrow down searches to the other ones.
- ./agent/knowledge — Project-specific: architecture decisions, conventions, debugging patterns

Search tips:
- Use 1-3 sentence questions, not keywords: "How does the auth flow handle token refresh?" beats "auth token refresh"
- Mention key terms explicitly in your query
- For exact term lookup, use keywords parameter with a focused query
- For precise "find this exact file/string" needs, use grep/rg instead — memex is for exploration

Workflow: Search to find entry points → Explore to follow connections (outlinks, backlinks, similar notes) → Build context before implementation.
