{ config, pkgs, ... }:

# Phone → PC sync via Syncthing.
# The PC receives phone media (DCIM, Pictures, Download, Documents, Recordings)
# into the ZFS encrypted dataset at /home/max/data/phone/.
#
# ZFS mount guard: ExecStartPre checks that the dataset is mounted.
# If not, Syncthing won't start. Use `zfs-unlock phone` to mount + restart.
{
  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      devices = {
        # TODO: replace with actual device ID from phone
        # (Syncthing app → Settings → Show Device ID)
        phone.id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
      };

      folders = let
        phonePath = "/home/max/data/phone";
      in {
        "phone-dcim" = {
          path = "${phonePath}/DCIM";
          devices = [ "phone" ];
          type = "receiveonly";
          id = "phone-dcim";
        };
        "phone-pictures" = {
          path = "${phonePath}/Pictures";
          devices = [ "phone" ];
          type = "receiveonly";
          id = "phone-pictures";
        };
        "phone-download" = {
          path = "${phonePath}/Download";
          devices = [ "phone" ];
          type = "receiveonly";
          id = "phone-download";
        };
        "phone-documents" = {
          path = "${phonePath}/Documents";
          devices = [ "phone" ];
          type = "receiveonly";
          id = "phone-documents";
        };
        "phone-recordings" = {
          path = "${phonePath}/Recordings";
          devices = [ "phone" ];
          type = "receiveonly";
          id = "phone-recordings";
        };
      };
    };
  };

  # Don't start Syncthing unless the ZFS dataset is mounted.
  # Prevents writing to the parent dataset (ZFS mountpoint shadowing).
  systemd.user.services.syncthing = {
    Service.ExecStartPre = "${pkgs.util-linux}/bin/mountpoint -q /home/max/data/phone";
  };
}
