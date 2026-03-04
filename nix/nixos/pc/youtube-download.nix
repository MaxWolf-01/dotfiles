{ pkgs, lib, ... }:

let
  dotfiles = "/home/max/.dotfiles";
  secrets = "${dotfiles}/secrets";

  ytPath = lib.makeBinPath (with pkgs; [
    bash coreutils gnused gnugrep yt-dlp ffmpeg curl
  ]);
in
{
  systemd.tmpfiles.rules = [
    "d /home/max/logs/youtube 0755 max users -"
  ];

  systemd.services.youtube-download = {
    description = "Download YouTube playlists";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "max";
      Group = "users";
      Environment = [ "PATH=${ytPath}" ];
      EnvironmentFile = "${secrets}/env/youtube-download.env";
      ExecStart = "${dotfiles}/backup/youtube_archive.sh ${secrets}/backup/playlists.txt /home/max/data/yt";

      # Sandboxing: yt-dlp parses arbitrary web content, isolate it from secrets
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [
        "${dotfiles}/backup/youtube_archive.sh"
        "${secrets}/backup/playlists.txt"
      ];
      BindPaths = [
        "/home/max/data/yt"
        "/home/max/logs/youtube"
      ];
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
    };
  };

  systemd.timers.youtube-download = {
    description = "Daily YouTube playlist download";
    timerConfig = {
      OnCalendar = "*-*-* 00:00:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
    wantedBy = [ "timers.target" ];
  };

  # Allow max to manage this service without password
  security.sudo.extraRules = [{
    users = [ "max" ];
    commands = [
      { command = "/run/current-system/sw/bin/systemctl start youtube-download.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl stop youtube-download.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl status youtube-download.service"; options = [ "NOPASSWD" ]; }
    ];
  }];
}
