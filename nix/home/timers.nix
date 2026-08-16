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

  thermalPath = lib.makeBinPath (with pkgs; [
    bash coreutils findutils gawk
  ]);

  lockSignPath = lib.makeBinPath (with pkgs; [
    bash coreutils jq
  ]);

  # The dns-* scripts are PEP 723 uv scripts, so uv resolves their deps at run.
  dnsPath = lib.makeBinPath (with pkgs; [
    bash coreutils uv
  ]);

  # util-linux for flock (vpn-pick serializes watcher vs. manual runs)
  vpnPath = lib.makeBinPath (with pkgs; [
    bash coreutils util-linux gawk curl jq libnotify
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

  # --- Backup staleness alarm ---
  # pc runs the same check without the offset, so it normally alerts first and
  # this stays quiet. The offset exists so that a dead pc — which would take its
  # alarm down with it — still surfaces here a week later.

  systemd.user.services.backup-staleness-check = {
    Unit = {
      Description = "Alert on restic repos that stopped receiving snapshots";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${backupPath}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/bin/backup-staleness-check --extra-days 7";
    };
  };

  systemd.user.timers.backup-staleness-check = {
    Unit.Description = "Daily backup staleness check (7d behind pc's)";
    Timer = {
      OnCalendar = "*-*-* 09:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Claude usage-window anchor ---
  # The 5-hour window starts with your first message, so these pings pin it to a
  # fixed grid: 08:30 → 13:30 → 18:30 → 23:30. Deliberately no 04:30 ping: it
  # would open a window running to 09:30 that swallows the 08:30 anchor, and
  # that anchor is the one that matters — it leaves ~2.5h of window in hand when
  # the workday starts around 11:00, then a fresh 5h block at 13:30.
  # 04:30–08:30 is the only gap, and it sits inside sleep.

  systemd.user.services.claude-ping = {
    Unit = {
      Description = "Anchor the Claude 5-hour usage window";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "/tmp";
      Environment = [ "PATH=${home}/.local/bin:${home}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin" ];
      ExecStart = "${dotfiles}/bin/claude-ping";
    };
  };

  systemd.user.timers.claude-ping = {
    Unit.Description = "Claude window anchor (08:30, then every 5h to 23:30)";
    Timer = {
      OnCalendar = "*-*-* 08,13,18,23:30:00";
      # Laptop: a missed anchor replays once on resume, which is no worse than
      # the window you would have opened with your first message anyway.
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Thermal history ---
  # Runs continuously rather than on a timer: the point is the seconds before a
  # hard power cut, which a timer's granularity would miss.

  systemd.user.services.thermal-log = {
    Unit.Description = "Sample temperatures, fans and CPU power caps to CSV";
    Service = {
      Environment = [ "PATH=${thermalPath}" ];
      ExecStart = "${dotfiles}/bin/thermal-log";
      Restart = "always";
      RestartSec = 10;
      Nice = 19;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # --- Tailnet Lock: keep Mullvad exit nodes signed ---
  # A user timer suffices here: zephylux grants max the tailscale operator role,
  # which carries the write access `lock sign` needs. pc has no operator, so its
  # equivalent is a root service in nix/nixos/pc/tailnet-lock.nix.

  systemd.user.services.tailnet-lock-sign = {
    Unit = {
      Description = "Sign Mullvad exit nodes locked out by Tailnet Lock";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      # tailscale is the Ubuntu system package in /usr/bin
      Environment = [ "PATH=${lockSignPath}:/usr/bin:/bin" ];
      ExecStart = "${dotfiles}/bin/tailnet-lock-sign";
    };
  };

  systemd.user.timers.tailnet-lock-sign = {
    Unit.Description = "Periodic Tailnet Lock signing of Mullvad exit nodes";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "15m";
      RandomizedDelaySec = "1m";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # --- Exit-node watchdog ---
  # Cloudflare blocks some Mullvad IPs for Chrome-family clients (Vesktop, any
  # Electron app), invisibly to Tailscale's own failover; and a pinned exit
  # node has no native failover at all. Runs continuously rather than on a
  # timer: the watcher reacts to exit-node changes and deaths within seconds
  # by polling local tailscale state, and probing Discord only on those
  # events. Rationale and probe: bin/vpn-pick.

  systemd.user.services.vpn-watchdog = {
    Unit = {
      Description = "Rotate the Mullvad exit node when Cloudflare blocks it or it dies";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      # tailscale is the Ubuntu system package in /usr/bin
      Environment = [ "PATH=${vpnPath}:/usr/bin:/bin" ];
      ExecStart = "${dotfiles}/bin/vpn-pick --watch";
      Restart = "on-failure";
      RestartSec = "30s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # --- DNS audit ---

  systemd.user.services.dns-audit = {
    Unit = {
      Description = "Classify refused DNS lookups, alert on newly blocked domains";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      # ${home}/bin for dns-blocked, which dns-audit shells out to
      Environment = [ "PATH=${dnsPath}:${home}/bin:/usr/bin:/bin" ];
      EnvironmentFile = "${secrets}/env/dns-audit.env";
      ExecStart = "${secrets}/scripts/dns-audit";
      # oneshot defaults to no timeout; without this a wedged run leaves the
      # unit activating forever and every later firing is a silent no-op.
      TimeoutStartSec = "30min";
    };
  };

  systemd.user.timers.dns-audit = {
    Unit.Description = "Daily DNS blocklist audit";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
