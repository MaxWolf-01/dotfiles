# container-hub: the one local server every page an agent opens goes through,
# on 127.0.0.1:8377. claude-browser hands it each page; what a unit is and how
# a page finds its own: bin/container-hub --help. Up from login, so the hub
# tab at http://127.0.0.1:8377/ is the way back to every unit after a reboot.
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
{ config, pkgs, lib, ... }:
let
  scriptPath = lib.makeBinPath ((with pkgs; [ bash coreutils uv git curl ]) ++ [ config.programs.tmux.package ]);
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  systemd.user.services.container-hub = {
    Unit.Description = "The container hub: every page an agent opens, in its orchestrator's unit";
    Service = {
      ExecStart = "${dotfiles}/bin/container-hub";
      Environment = [ "PATH=${scriptPath}" "TMUX_TMPDIR=%t" ];
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
