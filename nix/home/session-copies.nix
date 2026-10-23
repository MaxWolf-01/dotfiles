# session-copies: every 2 minutes, pull max's sessions from each host this
# one's hub relays (containerHub.peers, by the rule ./session-hosts.nix
# states), into ~/.local/share/session-copies/<host>/<user>/. What a pull
# copies: bin/session-copies --help.
#
# The copies are what the hub reads of a host that does not answer, and what
# it forks from. On the laptop they also land in its working backup, which is
# how the transcripts of pc and the worker hosts reach a restic snapshot at
# all; so the laptop pulls the worker users too (sessionCopies.workerHosts),
# whom `worker-hosts --targets` names, so one whose host publishes a record
# is pulled without an edit here.
#
# Every 2 minutes because the copies stand in for a host while it is down, and
# a run with nothing new costs a file list per source. While the ssh key is
# locked after a reboot, every run is a skip. A host with nothing to pull has
# no unit.
{ config, pkgs, lib, ... }:
let
  cfg = config.sessionCopies;
  peers = config.containerHub.peers;
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # bin/session-copies is a uv script driving rsync over ssh; sed for
  # worker-hosts --targets; jq for bin/run-log.
  path = lib.makeBinPath (with pkgs; [ bash coreutils gnused uv rsync openssh jq ]);
  sources = lib.attrNames peers ++ lib.optional cfg.workerHosts "the worker hosts";
in
{
  options.sessionCopies.workerHosts = lib.mkEnableOption ''
    pulling every worker host's user as well (bin/worker-hosts --targets), for
    the host whose backups keep their transcripts'';

  config = lib.mkIf (sources != [ ]) {
    systemd.user.services.session-copies = {
      Unit = {
        Description = "Pull the sessions of ${lib.concatStringsSep " and " sources} into session copies";
        After = [ "network-online.target" "ssh-agent.service" ];
        Wants = [ "network-online.target" "ssh-agent.service" ];
      };
      Service = {
        Type = "oneshot";
        Environment = [ "PATH=${path}" "SSH_AUTH_SOCK=%t/ssh-agent" ];
        ExecStart = lib.escapeShellArgs ([ "${dotfiles}/bin/session-copies" ]
          ++ lib.optionals (peers != { }) ([ "--sources" ] ++ lib.mapAttrsToList (name: host: "${name}=${host.ssh}") peers)
          ++ lib.optional cfg.workerHosts "--worker-hosts"
          ++ [ "--record" ]);
        # The first run copies every transcript a source has; later ones send
        # what changed. oneshot has no start timeout of its own, and a hung run
        # would make every later firing a silent no-op.
        TimeoutStartSec = "2h";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.user.timers.session-copies = {
      Unit.Description = "Session copies from ${lib.concatStringsSep " and " sources} (every 2 min)";
      Timer = {
        OnCalendar = "*:0/2";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
