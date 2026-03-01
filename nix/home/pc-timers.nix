{ config, pkgs, lib, ... }:

let
  home = config.home.homeDirectory;
  dotfiles = "${home}/.dotfiles";
  secrets = "${dotfiles}/secrets";

  backupPath = lib.makeBinPath (with pkgs; [
    bash coreutils gnused gnugrep restic openssh sops curl jq age
  ]);

  syncPath = lib.makeBinPath (with pkgs; [
    bash coreutils util-linux rsync openssh curl
  ]);

  ytPath = lib.makeBinPath (with pkgs; [
    bash coreutils gnused gnugrep yt-dlp ffmpeg curl
  ]);
in
{
  # --- YouTube download ---

  systemd.user.services.youtube-download = {
    Unit = {
      Description = "Download YouTube playlists";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${ytPath}" ];
      EnvironmentFile = "${secrets}/env/youtube-download.env";
      ExecStart = "${dotfiles}/backup/youtube_archive.sh ${secrets}/backup/playlists.txt ${home}/data/yt";
    };
  };

  systemd.user.timers.youtube-download = {
    Unit.Description = "Daily YouTube playlist download";
    Timer = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- YouTube → rsync.net ---

  systemd.user.services.youtube-rsyncnet = {
    Unit = {
      Description = "Restic backup to rsync.net (YouTube archive)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${backupPath}" ];
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
      Environment = [ "PATH=${syncPath}" ];
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
      Environment = [ "PATH=${backupPath}" ];
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
      Environment = [ "PATH=${backupPath}" ];
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
      Environment = [ "PATH=${backupPath}" ];
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
}
