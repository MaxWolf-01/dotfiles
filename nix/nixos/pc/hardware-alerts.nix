# Hardware faults that otherwise stay silent reach max through the alert
# channel (bin/alert-send): a weekly RAM stress test, ZFS's own events, the
# disks' SMART counters, and tank filling up.
{ config, pkgs, lib, ... }:

let
  dotfiles = "/home/max/.dotfiles";
  # Decrypted to tmpfs on max's first login after a boot (secrets/zshrc); until
  # then nothing can mail, and the run log keeps the record.
  ageKeyFile = "/run/user/1000/age-key.txt";

  # alert-send needs sops for its password and curl for SMTP; run-log needs jq.
  alertPath = lib.makeBinPath (with pkgs; [ bash coreutils gnused gnugrep gawk jq sops curl ]);

  # zed runs as root and hands each notification's subject as the argument and
  # its body on stdin; the channel's config and key are max's. zed discards the
  # program's output, so an undelivered mail is logged here or nowhere:
  # `journalctl -t zed-alert-send`.
  zedMail = pkgs.writeShellScript "zed-alert-send" ''
    ${pkgs.util-linux}/bin/runuser -u max -- ${pkgs.coreutils}/bin/env \
      HOME=/home/max SOPS_AGE_KEY_FILE=${ageKeyFile} PATH=${alertPath} \
      ${dotfiles}/bin/alert-send "🗄️ $1" \
      || { ${pkgs.util-linux}/bin/logger -t zed-alert-send "undelivered: $1"; exit 1; }
  '';

  # smartd runs this as root, with the warning in SMARTD_* variables. An
  # undelivered one is not lost: -M diminishing sends it again a day later,
  # then after two days, four, ... while the problem lasts.
  smartdMail = pkgs.writeShellScript "smartd-alert-send" ''
    { echo "$SMARTD_FULLMESSAGE"; echo; echo "Next: sudo smartctl -a $SMARTD_DEVICE"; } |
      ${pkgs.util-linux}/bin/runuser -u max -- ${pkgs.coreutils}/bin/env \
        HOME=/home/max SOPS_AGE_KEY_FILE=${ageKeyFile} PATH=${alertPath} \
        ${dotfiles}/bin/alert-send "💽 $SMARTD_SUBJECT" \
      || { ${pkgs.util-linux}/bin/logger -t smartd-alert-send "undelivered: $SMARTD_SUBJECT"; exit 1; }
  '';

  # Past ~80% full ZFS finds free blocks slower and writes slow down; 75 leaves
  # time to order disks.
  fillThreshold = 75;
  zpoolFillCheck = pkgs.writeShellScript "zpool-fill-check" ''
    set -uo pipefail
    log() { ${dotfiles}/bin/run-log zpool-fill-check "$@" || true; }
    if ! cap=$(${config.boot.zfs.package}/bin/zpool list -Hp -o capacity tank); then
      log fail --reason "zpool list tank failed"
      exit 1
    fi
    stats=$(jq -nc --argjson capacity_pct "$cap" '$ARGS.named')
    if [ "$cap" -ge ${toString fillThreshold} ]; then
      free=$(${config.boot.zfs.package}/bin/zpool list -H -o free tank)
      body="tank on pc is $cap% full, $free free. ZFS slows down past ~80%: grow the pool or free space.
    Biggest datasets: zfs list -o name,used -s used -r tank"
      ${dotfiles}/bin/alert-send "🗄️ tank on pc is $cap% full" <<<"$body" \
        && alert=sent || alert=undelivered
      stats=$(jq -c --arg alert "$alert" '. + {alert: $alert}' <<<"$stats")
    fi
    log ok --stats "$stats"
  '';
in
{
  # The notify zedlets (data errors, a scrub finishing with errors, a disk
  # changing state) mail only when ZED_EMAIL_ADDR is set. alert-send has its
  # own recipient, so the address here is never used.
  services.zfs.zed.settings = {
    ZED_EMAIL_ADDR = [ "max" ];
    ZED_EMAIL_PROG = "${zedMail}";
    ZED_EMAIL_OPTS = "'@SUBJECT@'";
    ZED_NOTIFY_INTERVAL_SECS = 3600;
    ZED_NOTIFY_VERBOSE = false;
  };

  # A system unit, not a user one: user.slice caps max's units together with
  # the workers (../agent-user.nix), and the test would compete with them there.
  systemd.services.memory-test = {
    description = "Stress the RAM and mail if it fails";
    serviceConfig = {
      Type = "oneshot";
      User = "max";
      Group = "users";
      # If memory runs short mid-test, the OOM killer takes the test, never a
      # worker or max's session.
      OOMScoreAdjust = 1000;
      Environment = [
        "PATH=${alertPath}:${lib.makeBinPath [ pkgs.stressapptest ]}"
        "SOPS_AGE_KEY_FILE=${ageKeyFile}"
      ];
      ExecStart = "${dotfiles}/bin/memory-test --record";
    };
  };

  systemd.timers.memory-test = {
    description = "Weekly RAM stress test";
    timerConfig = {
      OnCalendar = "Sun *-*-* 04:00:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    wantedBy = [ "timers.target" ];
  };

  # SMART counters (sectors remapped or waiting to be, CRC errors, temperature)
  # usually climb weeks before ZFS reads its first bad block.
  services.smartd = {
    enable = true;
    # Listed by ID, so a USB disk plugged in for a backup is left alone.
    autodetect = false;
    notifications = {
      wall.enable = false;
      mail.enable = false;
    };
    extraOptions = [ "--savestates=/var/lib/smartd/" ];
    defaults.monitored = "-a -M diminishing -m <nomailer> -M exec ${smartdMail}";
    devices =
      let
        # -n standby,q: a disk hd-idle stopped is skipped, since reading its
        # counters would spin it up every 30 min. A test due meanwhile runs once
        # it spins again. The short self-test (~2 min) falls in the nightly
        # window when the jobs wake the disks anyway. No long one: it runs inside
        # the drive, hd-idle sees no I/O and would stop the disk mid-test; the
        # monthly scrub reads every used block instead.
        tankDisk = id: {
          device = "/dev/disk/by-id/${id}";
          options = "-n standby,q -R 5! -W 0,45,50 -s S/../.././00";
        };
      in
      [
        (tankDisk "ata-ST2000VN004-2E4164_Z52C8ML1")
        (tankDisk "ata-ST2000VN004-2E4164_Z52C8N2D")
        {
          device = "/dev/disk/by-id/nvme-MS200-_2TB_MS200200TTS000009790";
          options = "-d nvme -W 0,65,75";
        }
      ];
  };
  systemd.services.smartd.serviceConfig.StateDirectory = "smartd";

  systemd.services.zpool-fill-check = {
    description = "Mail when tank passes ${toString fillThreshold}% full";
    serviceConfig = {
      Type = "oneshot";
      User = "max";
      Group = "users";
      Environment = [ "PATH=${alertPath}" "SOPS_AGE_KEY_FILE=${ageKeyFile}" ];
      ExecStart = "${zpoolFillCheck}";
    };
  };

  # Weekly, so a full pool reminds without becoming noise.
  systemd.timers.zpool-fill-check = {
    description = "Weekly tank fill check";
    timerConfig = {
      OnCalendar = "Mon *-*-* 08:00:00";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };
}
