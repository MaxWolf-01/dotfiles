{ config, pkgs, lib, ... }:

let
  home = config.home.homeDirectory;
  dotfiles = "${home}/.dotfiles";
  secrets = "${dotfiles}/secrets";

  backupPath = lib.makeBinPath (with pkgs; [
    bash coreutils gnused gnugrep restic openssh sops curl jq age
  ]);
in
{
  systemd.user.services.working-rsyncnet = {
    Unit = {
      Description = "Restic backup to rsync.net (working data)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${backupPath}" ];
      ExecStart = "${dotfiles}/backup/restic_backup.sh ${secrets}/backup/restic/working/rsyncnet.conf";
    };
  };

  systemd.user.timers.working-rsyncnet = {
    Unit.Description = "Daily backup to rsync.net (working data)";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.working-pc = {
    Unit = {
      Description = "Restic backup to PC (working data)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${backupPath}" ];
      ExecStart = "${dotfiles}/backup/restic_backup.sh ${secrets}/backup/restic/working/pc.conf";
    };
  };

  systemd.user.timers.working-pc = {
    Unit.Description = "Daily backup to PC (working data)";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.yapit-health-report = {
    Unit = {
      Description = "Yapit daily health report";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "${home}/repos/code/yapit-tts/yapit";
      EnvironmentFile = "${secrets}/env/yapit-health-report.env";
      Environment = [ "PATH=${lib.makeBinPath (with pkgs; [ bash coreutils openssh curl jq ])}" ];
      ExecStart = "${home}/repos/code/yapit-tts/yapit/scripts/report.sh";
    };
  };

  systemd.user.timers.yapit-health-report = {
    Unit.Description = "Yapit health report (10pm daily)";
    Timer = {
      OnCalendar = "*-*-* 22:00:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
