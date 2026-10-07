# Hardware faults that otherwise stay silent reach max through the alert
# channel (bin/alert-send): a weekly RAM stress test, and ZFS's own events.
{ pkgs, lib, ... }:

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
  # the workers (agent-user.nix), and the test would compete with them there.
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
}
