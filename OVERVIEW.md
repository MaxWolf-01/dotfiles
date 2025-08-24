# OVERVIEW

## TLDR

Personal dotfiles repository for Linux (Ubuntu), Android (Termux), and container environments. Provides comprehensive shell environment configuration with ZSH, development tools setup, and automated installation scripts. Built on Dotbot for idempotent symlink management with platform-specific configurations.

Primary technologies: ZSH, Dotbot, Git, Neovim, Python (uv), Node.js
Architecture: Modular configuration structure with separate modules for shell, git, vim, and development tools. Uses symlinks managed by Dotbot to maintain clean home directory.

## Core Features & Quick Start

**Core Features:**
- Platform-specific automated setup (Ubuntu desktop, Android/Termux, LXC containers)
- ZSH shell with plugins (syntax highlighting, autosuggestions, fuzzy search)
- Development environment configuration (Git, Neovim, Python with uv)
- Obsidian knowledge base integration with sync scripts
- Encrypted secrets management using age encryption
- Custom utilities and shell functions

**Installation:**
```bash
# Prerequisites
sudo apt-get update && sudo apt-get install -y git gh
gh auth login

# Clone repository
cd ~ && git clone --depth 1 git@github.com:MaxWolf-01/dotfiles.git
mv dotfiles .dotfiles && cd ~/.dotfiles

# Basic setup
./install && ./setup minimal

# Additional setups (in new shell)
./setup cli      # CLI tools
./setup ubuntu   # Ubuntu desktop
./setup android  # Android/Termux
```

**Configuration:**
- Dotbot manages symlinks via `install.conf.yaml`
- Platform-specific setup functions in `setup` script
- All installations are idempotent (safe to run multiple times)

## File Structure

```
.dotfiles/
├── install              # Main installation script - runs Dotbot with install.conf.yaml
├── install.conf.yaml    # Dotbot config - defines symlinks, directory creation, and shell commands
├── setup               # Platform-specific setup functions (minimal, cli, ubuntu, android, docker, etc.)
├── zsh/                # ZSH configuration
│   ├── zshrc          # Main ZSH config - sources all other configs
│   ├── aliases        # Git aliases (ga, gp, gc), ls variants, utility shortcuts
│   ├── exports        # Environment variables, PATH configs, tool settings
│   ├── functions      # Helper functions [mcd(), extract(), fs(), lsfs(), tre(), archive_md()]
│   ├── plugins        # Plugin loading (Zap manager)
│   ├── zsh_config     # ZSH-specific settings and options
│   ├── plugin-files/  # Plugin scripts (Zap installer, theme configs, zoxide integration)
│   └── android        # Android-specific aliases and functions
├── bin/               # Custom scripts
│   ├── obsidian_sync          # Sync Obsidian vault with git
│   ├── obsidian-todos-notify.sh # Send daily todos via ntfy
│   ├── paper2md.py            # Convert papers to markdown using Mistral AI
│   ├── keybindings.pl         # Backup/restore GNOME keyboard shortcuts
│   ├── theme_cycler.py        # Cycle through terminal themes
│   └── limit_battery_asus     # Battery charge limiter for ASUS laptops
├── git/               # Git configuration
│   ├── gitconfig      # Global git config with aliases and settings
│   ├── gitignore_global # Global gitignore patterns
│   └── hooks/         # Git hooks for encryption, Quartz sync, filename checks
├── vim/               # Vim/Neovim configuration
│   ├── vimrc          # Standard Vim config
│   ├── ideavimrc      # JetBrains IDEs vim config
│   └── obsidian       # Obsidian vim mode config
├── nvim/              # Neovim configuration
│   ├── init.lua       # Main Neovim entry point - loads Lazy.nvim package manager
│   └── lua/           # Lua configuration modules
├── claude/            # Claude AI assistant configuration
│   ├── CLAUDE.md      # User instructions for Claude
│   ├── settings.json  # Claude settings
│   ├── commands/      # Custom Claude commands
│   └── output-styles/ # Output formatting styles
├── secrets/           # Private encrypted repository (separate git repo)
│   ├── encrypted/     # Age-encrypted sensitive files
│   ├── decrypted/     # Decrypted files (gitignored)
│   └── backup/        # Backup configurations for restic
├── kitty/             # Kitty terminal configuration
├── tmux/              # Tmux configuration
├── python/            # Python configuration
│   └── pythonrc       # Python REPL startup file
├── desktop/           # Ubuntu desktop files
│   ├── icons/         # Custom application icons
│   └── *.desktop      # Desktop application entries
└── dotbot/            # Dotbot submodule for symlink management
```

## Key Components

**Dotbot Integration:** Central configuration manager that creates symlinks from dotfiles to home directory, ensures directories exist, and runs initialization commands. Configuration in `install.conf.yaml`.

**Setup Script:** Modular installation functions for different environments and tools. Functions include `minimal` (basic tools), `cli` (development tools), `ubuntu` (desktop environment), `android` (Termux setup), plus installers for specific tools like `get_nvim`, `get_claude`, `obsidian_vault`.

**ZSH Environment:** Comprehensive shell configuration with Zap plugin manager, fuzzy finder (fzf), syntax highlighting, autosuggestions, and Zoxide for intelligent directory jumping. Custom theme and extensive aliases/functions.

**Development Tools:** Integrated setup for modern development workflow including uv (Python package manager), Cargo (Rust), Homebrew, Node.js/npm, Neovim with Lazy.nvim, and Git with GitHub CLI integration.

**Obsidian Integration:** Knowledge base management with platform-specific configurations, automatic git sync scripts, Android support via Termux, and daily todo notifications.

**Secrets Management:** Separate encrypted git repository using age encryption, with automatic encryption/decryption hooks on commit/checkout for secure storage of API keys and passwords.

## Code Examples

**Available Setup Functions (./setup <function>):**

(subset, snapshot)

```bash
# Core installations
minimal        # Basic CLI tools (zsh, git, vim, tmux, ripgrep, uv, brew, cargo)
cli           # Extended CLI tools, depends on minimum for uv, brew, ... (fzf, zoxide, fastfetch, btop, ipdb)
ubuntu        # Ubuntu desktop environment (GNOME extensions, Obsidian, keybindings)
android       # Termux environment for Android

# Development tools
get_nvim      # Neovim AppImage with nerd fonts
get_nodejs    # Node.js with pnpm
get_cargo     # Rust toolchain
get_claude    # Claude AI CLI tool
docker        # Docker installation
toolbox       # JetBrains Toolbox

# Applications
obsidian      # Obsidian note-taking app
obsidian_vault # Clone and setup Obsidian knowledge base
discord       # Discord with BetterDiscord
signal        # Signal messenger
syncthing     # File synchronization

# Utilities
secrets       # Setup encrypted secrets repository
get_restic    # Backup tool
get_veracrypt # Encrypted volumes
wireguard_client # VPN client setup
sshkeys       # Generate SSH keys
fuzzy_finder  # Install fzf
```

**ZSH Functions (available in shell):**
```bash
# File operations
mcd <dir>     # Create directory and cd into it
extract <file> # Extract any archive format (.tar.gz, .zip, .rar, etc.)
targz <files>  # Create optimized .tar.gz archive
fs <path>      # Show file/directory size
lsfs [n]       # List n largest files/folders (negative n for smallest)

# Utilities
o [file]       # Open file explorer or specific file
tre            # Enhanced tree command (ignores .git, shows hidden)
gz <file>      # Compare original vs gzipped file size
numel <dir>    # Count elements in folder
newsshpwd <key> # Change SSH key passphrase

# Development
dfu            # Update dotfiles (pull & install)
archive_md <url> # Archive website as markdown
paper2md       # Convert papers to markdown (via AI)

# Git aliases (as shell aliases)
g/gst          # git status
ga/gaa         # git add / add all
gd/gds         # git diff / diff staged
gc/gcm         # git commit / commit with message
gp/gpl         # git push / pull
gs/gsc         # git switch / switch create
uncommit       # Undo last commit (keep changes)
```

**Using the secrets repository:**
```bash
./setup secrets  # Initial setup with age encryption
# Files in secrets/encrypted/ are automatically:
# - Decrypted on git checkout
# - Encrypted on git commit
# Age key location: ~/.local/secrets/age-key.txt
```

## Additional Resources

- Main documentation: `README.md` - Installation guide and feature overview
- Secrets setup: `secrets/README.md` - Encrypted repository configuration  
- Neovim config: `nvim/README.md` - Editor setup details
- Claude instructions: `claude/CLAUDE.md` - AI assistant customizations
- Custom commands: `claude/commands/` - Additional Claude AI commands
- Backup configs: `secrets/backup/restic/` - Restic backup configurations
- Git hooks: `git/hooks/` - Automated git workflows
- Android aliases: `zsh/android` - Termux-specific configurations

Key scripts worth exploring:
- `bin/paper2md.py` - AI-powered paper to markdown converter
- `bin/obsidian_sync` - Knowledge base synchronization
- `bin/keybindings.pl` - GNOME shortcut management
- `setup` - All installation and configuration functions
