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

  syncPath = lib.makeBinPath (with pkgs; [
    bash coreutils rsync openssh
  ]);

  mirrorPath = lib.makeBinPath (with pkgs; [
    bash coreutils gnugrep git gh openssh
  ]);

  sshAuthSock = "/run/user/1000/ssh-agent";
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

  # --- Jarvis VPS workspace → rsync.net (via SSHFS) ---

  systemd.user.services.jarvis-rsyncnet = {
    Unit = {
      Description = "Restic backup to rsync.net (jarvis workspace via SSHFS)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${backupPath}:${lib.makeBinPath [ pkgs.sshfs ]}:/usr/bin"
        "SSH_AUTH_SOCK=/run/user/1000/ssh-agent"
      ];
      ExecStart = "${dotfiles}/backup/jarvis_backup.sh ${secrets}/backup/restic/jarvis/rsyncnet.conf";
    };
  };

  systemd.user.timers.jarvis-rsyncnet = {
    Unit.Description = "Daily backup to rsync.net (jarvis workspace)";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "20m";
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

  systemd.user.services.yapit-dep-scout = {
    Unit = {
      Description = "Yapit dependency scout";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "${home}/repos/code/yapit-tts/yapit";
      Environment = [ "PATH=${home}/.nix-profile/bin:${home}/.claude/local:${home}/.local/bin:/usr/local/bin:/usr/bin:/bin" ];
      ExecStart = "${home}/repos/code/yapit-tts/yapit/scripts/dep-scout.sh";
    };
  };

  systemd.user.timers.yapit-dep-scout = {
    Unit.Description = "Yapit dependency scout (biweekly)";
    Timer = {
      OnCalendar = "Mon *-*-1..7,15..21 20:00:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- GitHub repo mirror (clone missing, fetch existing) ---

  systemd.user.services.github-mirror = {
    Unit = {
      Description = "Mirror GitHub repos (clone missing, fetch existing)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${mirrorPath}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/bin/github-mirror";
    };
  };

  systemd.user.timers.github-mirror = {
    Unit.Description = "Daily GitHub repo mirror";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Browsing archive: append new Firefox visits ---

  systemd.user.services.browsing-archive = {
    Unit.Description = "Append new Firefox visits to the browsing archive";
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${home}/.nix-profile/bin:${home}/.local/bin:/usr/bin:/bin" ];
      ExecStart = "${secrets}/scripts/browsing-archive";
    };
  };

  systemd.user.timers.browsing-archive = {
    Unit.Description = "Browsing archive collection (every 30 min)";
    Timer = {
      OnCalendar = "*:00/30";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Browsing-time dashboard (localhost + tailnet, port 8930) ---

  systemd.user.services.browsing-dash = {
    Unit = {
      Description = "Live browsing-time dashboard";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      # uv via nix-profile; tailscale is the Ubuntu system package in /usr/bin
      Environment = [ "PATH=${home}/.nix-profile/bin:${home}/.local/bin:/usr/bin:/bin" ];
      ExecStart = "${secrets}/scripts/browsing-dash";
      Restart = "on-failure";
      RestartSec = "30s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # --- YouTube watch history → browsing archive ---

  systemd.user.services.yt-watch = {
    Unit = {
      Description = "Append YouTube watch history to the browsing archive";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=${home}/.nix-profile/bin:${home}/.local/bin:/usr/bin:/bin" ];
      ExecStart = "${secrets}/scripts/yt-watch-collect";
    };
  };

  systemd.user.timers.yt-watch = {
    Unit.Description = "Daily YouTube watch history collection";
    Timer = {
      OnCalendar = "*-*-* 12:30:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Documents → jarvis (read-only mirror for the agent) ---

  systemd.user.services.jarvis-sync = {
    Unit = {
      Description = "Sync selected dirs to jarvis VPS (read-only mirror)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${syncPath}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${secrets}/scripts/jarvis-sync";
    };
  };

  systemd.user.timers.jarvis-sync = {
    Unit.Description = "jarvis sync (every 30 min, offset 5 min behind browsing-archive)";
    Timer = {
      OnCalendar = "*:05/30";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
