# display-layout watch: puts a saved display layout back when monitors are
# plugged in or the lid opens or closes. What it applies, and why nothing is
# written to monitors.xml: bin/display-layout --help.
#
# A service rather than a timer or a one-off, because an applied layout does not
# persist and has to be remade on every change of the connected monitors.
#
# The script is a uv PEP 723 script, so uv resolves its deps at run. jq because
# bin/run-log, which it calls to record each outcome, builds its line with it.
# /usr/bin for gdctl and gdbus: gdctl imports the system python3's GObject
# bindings, which a nix-store python does not carry.
{ config, pkgs, lib, ... }:
let
  scriptPath = lib.makeBinPath (with pkgs; [ bash coreutils uv jq ]);
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  systemd.user.services.display-layout = {
    Unit = {
      Description = "Put a saved display layout back when the connected monitors change";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dotfiles}/bin/display-layout watch";
      Environment = [ "PATH=${scriptPath}:/usr/bin" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
