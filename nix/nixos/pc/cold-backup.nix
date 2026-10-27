# Plugging a cold disk into pc starts bin/cold-backup for that disk, which
# copies its share of tank onto it and mails when it can be unplugged. The
# disks are the table in cold-disks.json, which the script reads too. What a
# run does: cold-backup --help.
{ config, pkgs, lib, ... }:

let
  # Each disk is matched by udev's ID_SERIAL, so no other disk starts its run.
  # It is the part of the disk's /dev/disk/by-id name after the bus: udev names
  # the link <ID_BUS>-<ID_SERIAL>.
  disks = builtins.fromJSON (builtins.readFile ./cold-disks.json);
in
{
  services.udev.extraRules = lib.concatStrings (lib.mapAttrsToList (name: disk: ''
    ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="${disk.serial}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="${disk.unit}.service"
  '') disks);

  systemd.services = lib.mapAttrs' (name: disk: lib.nameValuePair disk.unit {
    description = "Copy ${disk.source} onto the cold disk ${name}";
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
      ExecStart = "/home/max/.dotfiles/bin/cold-backup --notify ${name}";
      # A first run sends all of its source, and every run scrubs: hours.
      TimeoutStartSec = "infinity";
    };
  }) disks;
}
