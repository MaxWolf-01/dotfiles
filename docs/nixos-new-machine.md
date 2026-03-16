# NixOS on a New Machine

Last updated 2026-03-16 after xmg19 install. Re-verify before acting — tools evolve fast.

## Quick Reference

### Ideal flow (with custom installer ISO)

1. Build ISO: `nix build .#nixosConfigurations.installer.config.system.build.isoImage`
2. Flash + boot from USB (SSH + keys baked in, no manual setup)
3. Note IP from console
4. From any machine: `nix run github:nix-community/nixos-anywhere -- --flake .#hostname --target-host root@<ip>`
5. Enter LUKS passphrase when prompted
6. After install finishes: `ssh root@<ip> 'nixos-enter --root /mnt -c "echo max:max | chpasswd"'`
7. Reboot, select new drive in BIOS
8. Log in, clone dotfiles, nswitch:
   ```bash
   curl -sL https://github.com/MaxWolf-01.keys >> ~/.ssh/authorized_keys
   git clone https://github.com/MaxWolf-01/dotfiles.git ~/.dotfiles
   sudo nixos-rebuild switch --flake ~/.dotfiles#$(hostname)
   ```
9. Log out and back in

### Without custom ISO (from existing Linux)

Same as above, but step 1-2 replaced with: boot any Linux, set up root SSH manually, install `cpio` if needed. nixos-anywhere will kexec into a NixOS installer — **IP changes after kexec**. Re-run with `--phases disko,install` at the new IP.

### SSH host key cleanup

Every boot/kexec/reinstall changes the host key. Run `ssh-keygen -R <ip>` before connecting.

## Prerequisites for a new host config

Before running nixos-anywhere, create these files:

1. **Get stable disk ID** from the target:
   ```bash
   ssh root@<target> 'ls -la /dev/disk/by-id/ | grep nvme | grep -v part'
   ```

2. **`nix/nixos/<hostname>/disk-config.nix`** — disko config using the stable disk ID. Use a **unique VG name** (e.g. `vg-<hostname>`, never `vg0`).

3. **`nix/nixos/<hostname>/configuration.nix`** — must include:
   - `hardware.facter.reportPath = ./facter.json;`
   - `environment.systemPackages = [ git firefox ];` (bootstrap)
   - `users.users.max.initialPassword = "max";`
   - `openssh.authorizedKeys.keys` with your current SSH pubkey
   - Import `./disk-config.nix`

4. **`nix/home/hosts/<hostname>.nix`** — must import `../common.nix` + set `targets.genericLinux.enable = false;`

5. **`flake.nix`** — add to `nixosConfigurations` with `disko.nixosModules.disko` in modules

6. **`git add`** all new files (flakes only see tracked files)

7. **`nix flake lock`** if new inputs were added (e.g. disko)

## Gotchas

### CRITICAL: stable disk IDs in disko

**Never use `/dev/nvmeXn1`**. NVMe probe order changes across boots, kexec, and live USBs. We installed to the wrong drive (256GB instead of 1TB) because of this. Always use `/dev/disk/by-id/nvme-MODEL_SERIAL`.

### CRITICAL: unique LVM VG names

If the target has multiple drives with LVM, VG name collisions cause boot failure — initrd activates the wrong VG. Use `vg-<hostname>` in disko, never `vg0`. **Never rename a VG on a running system** — boot a live USB instead.

### kexec changes IP

nixos-anywhere kexecs the target into a NixOS installer. DHCP assigns a new IP. Check the console, re-run with `--phases disko,install --target-host root@<new-ip>`.

### Ubuntu live USB can't run nixos-install

nixos-anywhere's `--phases disko,install` needs `nixos-install` on the target. Ubuntu doesn't have it. Either: let nixos-anywhere do the full kexec flow (no `--phases`), or boot a NixOS live USB.

### HM common.nix import

`mkHome` (standalone HM) auto-includes `common.nix`. NixOS HM module path does NOT. The host nix file must explicitly `import ../common.nix` and set `targets.genericLinux.enable = false`.

## Sources

- nixos-anywhere: https://github.com/nix-community/nixos-anywhere
- disko examples: https://github.com/nix-community/disko/tree/master/example
- nixos-facter: https://github.com/nix-community/nixos-facter

## Current Setup

- **pc**: NixOS, manual hardware-configuration.nix, ext4, no disko/facter
- **xmg19**: NixOS via nixos-anywhere, disko (LUKS+LVM, Samsung 1TB by stable ID, VG `vg-xmg19`), facter, Hyprland
- **zephyrus**: Ubuntu 26.04 with standalone HM (NixOS planned)
