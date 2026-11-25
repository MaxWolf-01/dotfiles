{ config, pkgs, lib, ... }:

# --- HELFERLINE org → ~/work/helferline ---
# On every host that works on HELFERLINE, each keeping its own clones; the runs
# only fetch and fast-forward, so the hosts never step on each other. The
# workspace those clones sit in and its agent/ repo are max's own repos, kept
# current the same way, so what one host pushes there reaches the other within
# the hour.
# These clones are read as what is on GitHub, so they are pruned, and fetched from
# origin alone, where an unreachable ssh remote cannot use up a fetch's time limit.
# Hourly because a day-old view of them misleads, and a run with nothing new takes
# seconds. The ssh agent is for a clone whose origin is ssh.

let
  home = config.home.homeDirectory;
  dotfiles = "${home}/.dotfiles";
  workspace = "${home}/work/helferline";

  mirrorPath = lib.makeBinPath (with pkgs; [
    bash coreutils gnugrep git gh openssh jq # jq: bin/run-log builds its line with it
  ]);

  sshAuthSock = "/run/user/1000/ssh-agent";
in
{
  systemd.user.services.helferline-mirror = {
    Unit = {
      Description = "Keep the HELFERLINE clones matching GitHub";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${mirrorPath}"
        "SSH_AUTH_SOCK=${sshAuthSock}"
      ];
      ExecStart = "${dotfiles}/bin/github-mirror HELFERLINE ${workspace} ${workspace} ${workspace}/agent";
      # oneshot has no start timeout of its own; a hung run would make every later
      # firing a silent no-op.
      TimeoutStartSec = "1h";
    };
  };

  systemd.user.timers.helferline-mirror = {
    Unit.Description = "HELFERLINE clones (hourly)";
    Timer = {
      OnCalendar = "*:15:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
