# disko config for xmg19 (Tongfang/XMG): two NVMe disks.
# Samsung 1TB, LUKS + LVM unlocked by the TPM: EFI (1G) + boot (2G) + root (200G)
#   + swap (32G) + /srv (rest).
# Patriot 256GB, LUKS with a key of its own: /home, locked after every boot until
#   `host-unlock xmg19` on zephylux sends the key (home-unlock.nix).
{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4W6NF0M500455Y";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot/efi";
            mountOptions = [ "umask=0077" ];
          };
        };
        boot = {
          size = "2G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/boot";
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            # Unlocks from the TPM, with the passphrase as the fallback slot. The
            # TPM key is enrolled once by hand (docs/nixos-new-machine.md). With
            # Secure Boot off this protects only a drive pulled out of the laptop.
            settings.crypttabExtraOpts = [ "tpm2-device=auto" ];
            content = {
              type = "lvm_pv";
              vg = "vg-xmg19";
            };
          };
        };
      };
    };
  };

  disko.devices.disk.home = {
    device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_256GB_P300ABBB22111825230";
    type = "disk";
    content = {
      type = "gpt";
      partitions.luks = {
        size = "100%";
        content = {
          type = "luks";
          name = "home";
          # Not unlocked at boot, neither by the TPM nor at a prompt.
          initrdUnlock = false;
          settings.allowDiscards = true;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/home";
            # Mounted by host-unlock-receive once the volume is open; a boot
            # without it is a normal boot with /home empty.
            mountOptions = [ "noauto" "nofail" ];
          };
        };
      };
    };
  };

  disko.devices.lvm_vg.vg-xmg19 = {
    type = "lvm_vg";
    lvs = {
      root = {
        size = "200G";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
      # A fresh key each boot: memory swapped out of a session in /home must not
      # outlive the boot on a disk the TPM unlocks for anyone. Rules out hibernation.
      swap = {
        size = "32G";
        content = {
          type = "swap";
          randomEncryption = true;
        };
      };
      # Backups (restic ciphertext, written by pc and zephylux) and large data that
      # is not sensitive. Here rather than in /home so that backups land while /home
      # is locked.
      srv = {
        size = "100%FREE";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/srv";
        };
      };
    };
  };
}
