# NixOS on a New Machine

Last updated 2026-03-15 after xmg19 install. Re-verify before acting — tools evolve fast.

## The Stack

- **disko** (`github:nix-community/disko`) — declarative disk partitioning as Nix code. Replaces manual fdisk/parted. nixos-anywhere calls it automatically.
- **nixos-facter** (in nixpkgs) — generates JSON hardware report. Replaces `nixos-generate-config`. Dynamic: NixOS modules interpret the report, so it improves as nixpkgs evolves. Use via `hardware.facter.reportPath = ./facter.json;`
- **nixos-anywhere** (`github:nix-community/nixos-anywhere`) — one-command remote NixOS install over SSH. Orchestrates kexec + disko + facter + install.

## Key Command

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#hostname \
  --generate-hardware-config nixos-facter ./path/to/facter.json \
  --target-host root@<ip>
```

## Lessons Learned (xmg19 install, 2026-03-15)

### CRITICAL: disko must use stable disk IDs

**Never use `/dev/nvmeXn1`** in disko configs. NVMe probe order changes across boots and kexec. Use `/dev/disk/by-id/nvme-MODEL_SERIAL` instead. Get the ID from the target before writing the config:
```bash
ssh root@<target> 'ls -la /dev/disk/by-id/ | grep nvme | grep -v part'
```
We installed to the wrong drive (256GB Patriot instead of 1TB Samsung) because of this.

### nixos-anywhere kexec changes IP

kexec replaces the running kernel. The new kernel does its own DHCP and gets a different IP. nixos-anywhere tries to reconnect but often fails. Workaround: check the new IP on the target's console, then re-run with `--phases disko,install` at the new IP:
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#hostname \
  --generate-hardware-config nixos-facter ./path/to/facter.json \
  --target-host root@<NEW_IP> \
  --phases disko,install
```

### Bootstrap essentials in system config

The NixOS config needs packages available before HM applies:
- `environment.systemPackages = [ git firefox ]` — clone dotfiles + browse docs
- `users.users.<name>.initialPassword = "changeme"` — login before passwd is set
- Without these, you can't clone dotfiles or log into SDDM after first boot

### HM-as-NixOS-module: common.nix must be imported explicitly

`mkHome` (for standalone HM) auto-includes `common.nix`. The NixOS path (`home-manager.users.max = import ./hosts/foo.nix`) does NOT. The host's nix file must explicitly `import ../common.nix`. Without it: no zsh, no git, no aliases, no SSH config — nothing from common.

Also set `targets.genericLinux.enable = false` on NixOS hosts (it's `mkDefault true` in common.nix for Ubuntu machines).

### Set user password before rebooting

After nixos-anywhere finishes but before reboot:
```bash
ssh root@<installer-ip> 'nixos-enter --root /mnt -c "echo max:<password> | chpasswd"'
```
Or set `initialPassword` in the config.

### SSH access to new install

The installed system has new SSH host keys. After reboot:
1. `ssh-keygen -R <ip>` to clear old host key
2. SSH pubkeys in `openssh.authorizedKeys.keys` must match your current machine's key
3. On the target, `curl -sL https://github.com/MaxWolf-01.keys >> ~/.ssh/authorized_keys` as a quick fix

### Stage facter.json immediately

nixos-anywhere generates `facter.json` — stage it with `git add` right away. Flakes only see tracked files. Also add `hardware.facter.reportPath = ./facter.json;` to the configuration.nix for future `nswitch` rebuilds.

### The target needs `cpio`

nixos-anywhere's kexec needs `cpio` on the target. If missing: `ssh root@<target> 'apt-get install -y cpio'`

## Gotchas & Non-Obvious Things

- **nixos-facter doesn't handle filesystems** — that's disko's job. They're complementary.
- **nixos-hardware** has no XMG/Schenker/Tongfang profiles. Use `common-pc-laptop` for generic laptop power mgmt. Zephyrus models ARE covered.
- **kexec needs ~2GB RAM** on the target for nixos-anywhere to work.
- **LUKS keys**: pass via `--disk-encryption-keys /tmp/secret.key <(pass ...)` during nixos-anywhere.
- **Secrets bootstrapping** (sops-nix): use `--extra-files` to inject host SSH keys so sops can decrypt on first boot.
- **`system.configurationRevision`**: use `self.rev or self.dirtyRev or "unknown"` — pass `self` via `specialArgs` in flake.nix. Shows git commit via `nixos-version --configuration-revision`.

## Post-Install Steps (after first boot)

```bash
# 1. Set password (if initialPassword wasn't in config)
passwd

# 2. Get SSH access from other machines
curl -sL https://github.com/MaxWolf-01.keys >> ~/.ssh/authorized_keys

# 3. Clone dotfiles
git clone https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles

# 4. Set NIX_HOST + create dirs (still needed on NixOS for nswitch alias)
cd ~/.dotfiles && ./setup host <hostname>

# 5. First full rebuild (applies NixOS config + HM with all symlinks, zsh, tools)
sudo nixos-rebuild switch --flake ~/.dotfiles#<hostname>

# 6. Log out and back in (new shell environment)
```

After step 5, everything is declarative — `nswitch` for future changes.

## Sources

- nixos-anywhere docs: https://github.com/nix-community/nixos-anywhere
- disko examples: https://github.com/nix-community/disko/tree/master/example
- disko templates: https://github.com/nix-community/disko-templates
- nixos-facter: https://github.com/nix-community/nixos-facter
- nixos-hardware profiles: https://github.com/NixOS/nixos-hardware

## Current Setup

- **pc**: NixOS with manual `hardware-configuration.nix` + ext4. No disko/facter.
- **xmg19**: NixOS via nixos-anywhere + disko (LUKS+LVM on Samsung 1TB, stable disk ID) + facter. Hyprland desktop.
- **zephyrus**: Ubuntu with standalone HM. Not NixOS.
