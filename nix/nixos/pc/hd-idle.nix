# Spin down the tank HDDs after 30 min of no I/O.
#
# Everything that touches tank is nocturnal (backups, phone sync, youtube
# download, all between 00:00 and 01:00, staleness check at 09:06), so the
# disks can stand still ~22 h a day: ~8 W less draw, less heat and rattle.
# First access after standby pays ~10 s of spin-up latency.
#
# 30 min, not less: the nightly jobs are spaced up to ~20 min apart, and a
# shorter timeout would cycle the disks between them. Not more: past the
# job windows the pool sits untouched for hours, so a longer timeout only
# adds spinning time.
#
# hd-idle over the drives' own hdparm -S timer because many drives (Seagates
# included) ignore the internal timer; hd-idle watches /proc/diskstats from
# userspace and issues the stop itself, and logs every spin-down/up — so
# whether something needlessly wakes the disks is auditable from the journal.
#
# -i 0 disables the default-all-disks timer; only the two tank members are
# targeted, by stable ID (sda/sdb can shuffle across boots).
{ pkgs, ... }:
{
  systemd.services.hd-idle = {
    description = "Spin down tank HDDs after 30 min idle";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.hd-idle}/bin/hd-idle"
        "-i 0"
        "-a /dev/disk/by-id/ata-ST2000VN004-2E4164_Z52C8ML1 -i 1800"
        "-a /dev/disk/by-id/ata-ST2000VN004-2E4164_Z52C8N2D -i 1800"
      ];
      Restart = "on-failure";
    };
  };
}
