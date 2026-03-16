# disko config for xmg19 (Tongfang/XMG, 931GB NVMe)
# LUKS + LVM: EFI (1G) + boot (2G) + encrypted root (200G) + encrypted home (rest)
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
            content = {
              type = "lvm_pv";
              vg = "vg-xmg19";
            };
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
      home = {
        size = "100%FREE";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/home";
        };
      };
    };
  };
}
