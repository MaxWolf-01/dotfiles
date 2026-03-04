{ config, pkgs, lib, ... }:

let
  home = config.home.homeDirectory;
  dotfiles = "${home}/.dotfiles";
  secrets = "${dotfiles}/secrets";

  backupPath = lib.makeBinPath (with pkgs; [
    bash coreutils util-linux gnused gnugrep restic openssh sops curl jq age
  ]);

  syncPath = lib.makeBinPath (with pkgs; [
    bash coreutils util-linux rsync openssh curl
  ]);

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
      EnvironmentFile = "${secrets}/env/phone-sync.env";
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
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
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

  # --- Catch up missed backups after age key is decrypted ---

  systemd.user.paths.age-key-available = {
    Unit.Description = "Watch for age key availability";
    Path.PathExists = ageKeyFile;
    Install.WantedBy = [ "paths.target" ];
  };

  systemd.user.services.age-key-available = {
    Unit.Description = "Run missed backups after age key appears";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl --user start youtube-rsyncnet.service phone-rsyncnet.service phone-pc.service encrypted-rsyncnet.service || true'";
    };
  };
}
