{ config, pkgs, lib, ... }:

let
  home = config.home.homeDirectory;
  dotfiles = "${home}/.dotfiles";
  secrets = "${dotfiles}/secrets";

  backupPath = lib.makeBinPath (with pkgs; [
    bash coreutils util-linux gnused gnugrep restic openssh sops curl jq age sqlite
  ]);

  # jq: bin/run-log builds its JSON line with it
  syncPath = lib.makeBinPath (with pkgs; [
    bash coreutils util-linux rsync openssh gnugrep jq
  ]);

  # systemd for journalctl: the watchdog asks it when units without a run log
  # last finished cleanly, here and (over ssh) on the laptop.
  watchdogPath = "${backupPath}:${lib.makeBinPath [ pkgs.systemd ]}";

  # Age key on tmpfs (decrypted on first SSH login, see secrets/zshrc)
  ageKeyFile = "/run/user/1000/age-key.txt";

  # ssh-agent socket (managed by services.ssh-agent in common.nix)
  sshAuthSock = "/run/user/1000/ssh-agent";
in
{
  # --- YouTube download: moved to nix/nixos/pc/youtube-download.nix (system-level, sandboxed) ---

  # --- YouTube → rsync.net ---

  systemd.user.services.youtube-rsyncnet = {
    Unit = {
      Description = "Restic backup to rsync.net (YouTube archive)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${backupPath}"
        "SOPS_AGE_KEY_FILE=${ageKeyFile}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/backup/restic_backup.sh ${secrets}/backup/restic/youtube/rsyncnet.conf";
    };
  };

  systemd.user.timers.youtube-rsyncnet = {
    Unit.Description = "Daily backup to rsync.net (YouTube archive)";
    Timer = {
      OnCalendar = "*-*-* 00:30:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Phone sync (rsync over Tailscale SSH) ---

  systemd.user.services.phone-sync = {
    Unit = {
      Description = "Sync phone data via rsync over Tailscale";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${syncPath}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/backup/phone_sync.sh";
    };
  };

  systemd.user.timers.phone-sync = {
    Unit.Description = "Daily phone sync";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Phone → rsync.net ---

  systemd.user.services.phone-rsyncnet = {
    Unit = {
      Description = "Restic backup to rsync.net (phone data)";
      # Ordered after the sync so we never snapshot a half-copied tree. Wants,
      # not Requires: a failed or skipped sync should still leave us backing up
      # whatever already landed on disk.
      After = [ "network-online.target" "phone-sync.service" ];
      Wants = [ "network-online.target" "phone-sync.service" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${backupPath}"
        "SOPS_AGE_KEY_FILE=${ageKeyFile}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/backup/restic_backup.sh ${secrets}/backup/restic/phone/rsyncnet.conf";
    };
  };

  systemd.user.timers.phone-rsyncnet = {
    Unit.Description = "Daily backup to rsync.net (phone data)";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "20m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Phone → PC local ---

  systemd.user.services.phone-pc = {
    Unit = {
      Description = "Restic backup local (phone data)";
      After = [ "network-online.target" "phone-sync.service" ];
      Wants = [ "network-online.target" "phone-sync.service" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${backupPath}"
        "SOPS_AGE_KEY_FILE=${ageKeyFile}"
      ];
      ExecStart = "${dotfiles}/backup/restic_backup.sh ${secrets}/backup/restic/phone/pc.conf";
    };
  };

  systemd.user.timers.phone-pc = {
    Unit.Description = "Daily local backup (phone data)";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "40m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Encrypted → rsync.net ---

  systemd.user.services.encrypted-rsyncnet = {
    Unit = {
      Description = "Restic backup to rsync.net (encrypted data)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${backupPath}"
        "SOPS_AGE_KEY_FILE=${ageKeyFile}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/backup/restic_backup.sh ${secrets}/backup/restic/encrypted/rsyncnet.conf";
    };
  };

  systemd.user.timers.encrypted-rsyncnet = {
    Unit.Description = "Weekly backup to rsync.net (encrypted data)";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h20m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- pc service state → rsync.net ---
  # pc-local app state (e.g. mdsr's spaced-repetition DB) that lives on pc's own
  # disk, not in a tank dataset. ExecStartPre stages consistent snapshots; the
  # backup then sweeps the staging tree. Add services by editing the snapshot
  # script + pcstate/dirs.txt — this unit doesn't change.

  systemd.user.services.pcstate-rsyncnet = {
    Unit = {
      Description = "Restic backup to rsync.net (pc service state)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${backupPath}"
        "SOPS_AGE_KEY_FILE=${ageKeyFile}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStartPre = "${dotfiles}/backup/pcstate_snapshot.sh";
      ExecStart = "${dotfiles}/backup/restic_backup.sh ${secrets}/backup/restic/pcstate/rsyncnet.conf";
    };
  };

  systemd.user.timers.pcstate-rsyncnet = {
    Unit.Description = "Weekly backup to rsync.net (pc service state)";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Overdue watchdog ---
  # The only scheduled alerter; what it watches and why is in bin/overdue-check.
  # No offset here: this host reaches its bounds first, and the laptop runs the
  # same check with --extra-days so either machine dying leaves an alarm standing.

  systemd.user.services.overdue-check = {
    Unit = {
      Description = "Alert on units and repos that stopped succeeding";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${watchdogPath}"
        "SOPS_AGE_KEY_FILE=${ageKeyFile}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/bin/overdue-check";
    };
  };

  systemd.user.timers.overdue-check = {
    Unit.Description = "Daily overdue check";
    Timer = {
      OnCalendar = "*-*-* 09:00:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

}
