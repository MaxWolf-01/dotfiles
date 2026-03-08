# Dotfiles

Dotfiles for Ubuntu desktop (GNOME), NixOS, servers/containers, and Android (Termux).

Managed via [Nix Home Manager](https://github.com/nix-community/home-manager) — standalone on Ubuntu, as a NixOS module on NixOS.

**Setup:** [Ubuntu](#setup-ubuntu) | [NixOS](#setup-nixos) | [Server/Container](#setup-servercontainer) | [Android/Termux](#setup-android--termux)

`./setup host` to list available host configs.

```
dotfiles
├── backup        # restic/rsync backup scripts (ntfy notifications)
├── bin           # custom scripts
├── desktop       # icons, discord theme
├── nix
│   ├── home
│   │   ├── common.nix     # CLI tools, git, zsh plugins (all hosts)
│   │   ├── desktop.nix    # GUI apps (workstations)
│   │   ├── firefox.nix    # Firefox config, policies, search engines
│   │   ├── gnome.nix      # GNOME keybindings, extensions, dconf
│   │   ├── tmux.nix       # tmux config + resurrect
│   │   ├── timers.nix     # systemd timers (zephyrus)
│   │   ├── pc-timers.nix  # backup/sync timers (pc)
│   │   ├── wayland.nix
│   │   └── hosts/         # per-machine: imports + stateVersion
│   └── nixos/             # NixOS system configs
├── nvim          # neovim config (lazy.nvim)
├── zsh
│   ├── aliases       # shell aliases
│   ├── exports       # env vars, PATH
│   ├── functions     # shell functions
│   ├── plugins       # extra zsh plugins
│   └── zshrc         # main config (baked by HM, sources the above)
├── flake.nix     # nix flake (NixOS + HM hosts)
├── secrets/      # private repo (SSH, API keys, backup configs)
└── setup         # bootstrap script
```

## Setup (Ubuntu)

### Fresh install (LUKS + LVM)

Boot a live USB, then:

```bash
sudo apt-get install -y debootstrap gdisk
curl -sLO https://raw.githubusercontent.com/MaxWolf-01/dotfiles/master/bin/ubuntu-install
chmod +x ubuntu-install && sudo ./ubuntu-install /dev/nvmeXnY --root 200
```

Reboot, remove USB.

### Post-install

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup minimal
```

Restart shell, then:

```bash
./setup host zephyrus          # sets NIX_HOST, runs first HM switch
./setup ubuntu                 # NVIDIA drivers, codecs, cleanup
sudo reboot
./setup gpu                    # nix GPU driver symlinks
gh auth login -w
./setup secrets                # clones secrets repo, decrypts SSH key + secrets
restore-working                # restore data from rsync.net backup
./setup get_claude             # after restore to avoid .claude/ conflicts
```

After first run, use `hmswitch` to apply HM changes.

All `./setup` functions are idempotent — safe to re-run.

<details>
<summary>Other setup functions</summary>

```bash
./setup docker
./setup nvidia_container_toolkit
./setup get_vibetyper
```
</details>

## Setup (NixOS)

```bash
git clone https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup minimal
./setup host pc
nswitch
```

Place age key at `~/.local/secrets/age-key.txt`, then: `./setup secrets`

## Setup (Server/Container)

```bash
apt-get update && apt-get install -y git
git clone --depth 1 https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup minimal
```

Restart shell, then:

```bash
./setup host minimal    # or minimal-root if running as root
nix run home-manager/master -- switch --flake ~/.dotfiles#$NIX_HOST
```

## Setup (Android / Termux)

Install [Termux](https://f-droid.org/en/packages/com.termux/) and [Termux:Boot](https://f-droid.org/en/packages/com.termux.boot/) from F-Droid.

In Termux, grant storage access and set up SSH:
```bash
termux-setup-storage    # grants access to /sdcard
pkg update && pkg upgrade && pkg install openssh
mkdir -p ~/.ssh && curl -sL https://github.com/MaxWolf-01.keys >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
sshd
```

`~/storage/shared` is [symlinked](https://android.stackexchange.com/a/185949) to `/storage/emulated/0` (where Downloads, DCIM, etc. live on Android).

From your laptop (assuming Tailscale): `ssh <phone-tailscale-ip> -p 8022`

Auto-start sshd on boot (requires Termux:Boot + battery optimization exemption for both Termux and Termux:Boot):
```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-sshd << 'SCRIPT'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sshd
SCRIPT
chmod +x ~/.termux/boot/start-sshd
```

After SSH is working, the rest can be done from the laptop over SSH.

## Credits

- [rime](https://github.com/lukasl-dev/rime) + claude for making nix easy
- [Jovial Theme](https://github.com/zthxxx/jovial)
- [Nix/Home Manager](https://github.com/nix-community/home-manager)
- Various functions and scripts from other dotfiles repos (see top of [functions](zsh/functions))
- [dotfiles.github.io](https://dotfiles.github.io/)

## Eye Candy

<img width="2560" height="1600" alt="Image" src="https://github.com/user-attachments/assets/b1ac8b4f-d2c4-4f55-b77a-1c886e956653" />
