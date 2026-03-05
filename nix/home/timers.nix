{ config, pkgs, lib, ... }:

let
  home = config.home.homeDirectory;
  dotfiles = "${home}/.dotfiles";
  secrets = "${dotfiles}/secrets";

  backupPath = lib.makeBinPath (with pkgs; [
    bash coreutils gnused gnugrep restic openssh sops curl jq age
  ]);

  ytCookiePath = lib.makeBinPath (with pkgs; [
    bash coreutils yt-dlp openssh
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

  # --- YouTube cookie export → PC ---

  systemd.user.services.youtube-cookies-export = {
    Unit = {
      Description = "Export YouTube cookies from Firefox and push to PC";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${ytCookiePath}"
        "SSH_AUTH_SOCK=/run/user/1000/ssh-agent"
      ];
      ExecStart = pkgs.writeShellScript "youtube-cookies-export" ''
        set -uo pipefail
        tmp=$(mktemp)
        trap "rm -f $tmp" EXIT

        # Seed with Netscape header (yt-dlp reads before writing)
        echo "# Netscape HTTP Cookie File" > "$tmp"

        # Export cookies from Firefox — exit code ignored (video processing may fail)
        yt-dlp --cookies-from-browser firefox \
          --cookies "$tmp" \
          --skip-download "https://www.youtube.com/watch?v=jNQXAC9IVRw" >/dev/null 2>&1 || true

        # Verify cookies were written, then push to PC
        if [ "$(wc -l < "$tmp")" -gt 10 ]; then
          scp -q "$tmp" pc:/home/max/.local/secrets/youtube-cookies.txt
        else
          echo "Cookie export produced no data" >&2
          exit 1
        fi
      '';
    };
  };

  systemd.user.timers.youtube-cookies-export = {
    Unit.Description = "Weekly YouTube cookie export to PC";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
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
      Environment = [ "PATH=${home}/.nix-profile/bin:${home}/.claude/local:${home}/.local/bin:/usr/local/bin:/usr/bin:/bin" ];
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
