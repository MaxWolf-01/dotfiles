# display-layout — keep the external monitor above the laptop panel. What it
# does and why it cannot simply save the layout: bin/display-layout --help.
#
# A service rather than a timer or a one-off, because the fix does not persist
# and has to be remade every time mutter falls back.
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
      Description = "Arrange monitors when mutter falls back to its row layout";
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
