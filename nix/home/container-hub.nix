# container-hub: the one server every page an agent opens goes through, and the
# hub tab that shows max's sessions. It listens on a unix socket only max can
# open; claude-browser hands it each page there. What a unit is, how a page
# finds its own, and where the hub listens: bin/container-hub --help. Up from
# login, so the hub tab is the way back to every unit after a reboot.
#
# `tailscale serve` puts the hub on the tailnet at
# https://<host>.tail710178.ts.net:8377/, so the phone opens it: the socket
# where a root unit serves it (pc), the loopback port where the hub's own user
# service does (the laptop), since serving a socket takes root. 8377 is a
# port Funnel cannot publish (it serves only 443, 8443 and 10000), so running
# `tailscale funnel` by mistake where `tailscale serve` was meant cannot put
# the hub on the internet. Which devices may open it is the tailnet policy's
# (secrets/tailscale/policy.hujson). pc's system config names the same port and
# socket (nix/nixos/pc/container-hub.nix); the tools find the socket as the
# hub's default, which this one is.
#
# The hub is a uv PEP 723 script, so uv resolves its deps at run. git reads the
# sessions' commits; curl fetches trellis on first use, and asks a page on
# another origin whether it allows framing; the tracker it reads
# comes from the mx plugin under ~/.claude*/plugins, found by the hub itself,
# and is a uv script too. diffview, which renders a ticket's recorded ranges,
# sits beside the hub in bin/.
#
# The hub types the user's answers into a session's tmux pane. It needs the
# tmux package the sessions' server runs, since a client speaks only its own
# server's protocol, and that server's socket, which tmux.nix puts under
# TMUX_TMPDIR=%t.
#
# Restart=always, not on-failure: the hub never exits on its own, so any exit,
# a clean one included, leaves every agent's pages opening as plain tabs.
#
# A peer is another host's hub this one relays (the hub's --peer), reached
# over ssh as max: ssh forwards the peer's socket to one here that only max
# can open, since ssh makes it 0600 (StreamLocalBindMask) in a directory of
# his. Not over the peer's tailnet port: the tailnet policy cannot tell max's
# processes on pc from the dispatch workers beside them, so a grant from pc to
# that port would let a worker drive the peer's sessions, and the workers hold
# no ssh login to the peer. The forward is a unit of its own: a peer asleep or
# out of reach is ssh failing and trying again every 30s, while the hub shows
# what it last read of the peer.
{ config, pkgs, lib, ... }:
let
  cfg = config.containerHub;
  port = "8377";
  state = "${config.home.homeDirectory}/.local/state/container-hub";
  socket = "${state}/hub.sock";
  peerSocket = name: "${state}/peers/${name}.sock";
  scriptPath = lib.makeBinPath ((with pkgs; [ bash coreutils uv git curl ]) ++ [ config.programs.tmux.package ]);
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  options.containerHub = {
    loopback = lib.mkEnableOption ''
      the hub on 127.0.0.1:8377 as well, for a browser on this host. Every
      user of the host can open that port, so it is only for a host where all
      of them are max'';
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The hub tab's address the tools open and link (the hub's --url); its loopback port where unset.";
    };
    tailnet = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Where the hub's own service has `tailscale serve` put its loopback
        port on the tailnet (the hub's --tailnet). A host whose serve table a
        system unit owns (pc) serves the socket from there instead.'';
    };
    peers = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { zephylux = "zephylux"; };
      description = ''
        The other hosts' hubs this one relays: the host name the hub tab
        shows, to the ssh destination that reaches that host. Its hub listens
        where this host's does, under the same home.'';
    };
  };

  config.assertions = [
    {
      assertion = cfg.loopback || cfg.url != null;
      message = "containerHub: the hub needs an address a browser opens it at, its loopback port or a url";
    }
    {
      assertion = cfg.tailnet == null || cfg.loopback;
      message = "containerHub: tailnet serves the loopback port, so it needs loopback";
    }
  ];

  config.systemd.user.services = {
    container-hub = {
      Unit.Description = "The container hub: every page an agent opens, in its orchestrator's unit";
      Service = {
        ExecStart = lib.escapeShellArgs ([ "${dotfiles}/bin/container-hub" "--socket" socket ]
          ++ lib.optionals cfg.loopback [ "--port" port ]
          ++ lib.optionals (cfg.url != null) [ "--url" cfg.url ]
          ++ lib.optionals (cfg.tailnet != null) [ "--tailnet" cfg.tailnet ]
          ++ lib.optionals (cfg.peers != { }) ([ "--peer" ] ++ lib.mapAttrsToList (name: _: "${name}=${peerSocket name}") cfg.peers));
        # "-": the hub never waits on tailscale, so a laptop offline or with
        # tailscaled stopped keeps its hub. tailscale is the Ubuntu system
        # package in /usr/bin. max is its operator, which lets him proxy a port
        # without sudo, though not serve a socket.
        ExecStartPost = lib.optional (cfg.tailnet != null)
          "-/usr/bin/tailscale serve --bg --yes --https=${port} http://127.0.0.1:${port}";
        Environment = [ "PATH=${scriptPath}" "TMUX_TMPDIR=%t" ];
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "default.target" ];
    };
  } // lib.mapAttrs' (name: destination: lib.nameValuePair "container-hub-peer-${name}" {
    Unit = {
      Description = "The container hub's way to ${name}'s hub: its socket, forwarded over ssh";
      After = [ "ssh-agent.service" ];
      Wants = [ "ssh-agent.service" ];
      StartLimitIntervalSec = 0; # a peer asleep for a week is tried all week
    };
    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p -m 700 ${state}/peers";
      # BatchMode: no prompt waits on nobody, so a key still locked after a
      # reboot is a failure tried again. ExitOnForwardFailure: an ssh that
      # could not make the socket exits rather than holding nothing.
      # StreamLocalBindUnlink: the socket a killed ssh left is made anew.
      ExecStart = lib.escapeShellArgs [ "${pkgs.openssh}/bin/ssh" "-N" "-oBatchMode=yes" "-oConnectTimeout=10"
        "-oServerAliveInterval=15" "-oServerAliveCountMax=3" "-oExitOnForwardFailure=yes"
        "-oStreamLocalBindUnlink=yes" "-L" "${peerSocket name}:${socket}" destination ];
      Environment = [ "SSH_AUTH_SOCK=%t/ssh-agent" ];
      Restart = "always";
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  }) cfg.peers;
}
