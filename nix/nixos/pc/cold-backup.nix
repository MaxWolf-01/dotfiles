# Plugging the cold disk into pc starts bin/cold-backup, which copies tank/max
# onto it and mails when it can be unplugged. What a run does: cold-backup --help.
{ config, pkgs, lib, ... }:

let
  # The 2 TB Seagate FireCuda (USB), matched by udev's ID_SERIAL so no other
  # disk starts a run.
  coldDiskSerial = "Seagate_FireCuda_HDD_00000000NAD31L08-0:0";
in
{
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="${coldDiskSerial}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cold-backup.service"
  '';

  systemd.services.cold-backup = {
    description = "Copy tank/max onto the cold disk";
    path = [ config.boot.zfs.package ] ++ (with pkgs; [
      bash coreutils util-linux getent gnused gnugrep gawk jq sops curl git age
    ]);
    # alert-send needs the age key, decrypted on max's first login after a
    # boot; until then the mail is undelivered and the run log keeps the record.
    environment.SOPS_AGE_KEY_FILE = "/run/user/1000/age-key.txt";
    serviceConfig = {
      Type = "oneshot";
      # The pool's partitions appear a moment after the disk itself.
      ExecStartPre = "${pkgs.systemd}/bin/udevadm settle";
      ExecStart = "/home/max/.dotfiles/bin/cold-backup --notify";
      # The first run sends all of tank/max, and every run scrubs: hours.
      TimeoutStartSec = "infinity";
    };
  };
}
