# display-layout — keep the external monitor above the laptop panel.
#
# mutter keys the layouts in ~/.config/monitors.xml on each monitor's connector
# name, and one monitor reaches a different connector through a different port:
# HDMI-1 on the discrete GPU, DP-1 or DP-2 on the two USB-C ports. A layout
# saved on one port is therefore not found on another, and mutter lays the
# monitors out in a left-to-right row instead. bin/display-layout watches for
# that row and replaces it, for the session only — mutter shows the "keep these
# display settings?" dialog for any config a D-Bus client saves. So the fix has
# to be reapplied on every fallback, which is what makes this a service rather
# than a one-off. See its --help.
#
# The script is a uv PEP 723 script, so uv resolves its deps at run. gdctl and
# gdbus stay on /usr/bin: gdctl imports the system python3's GObject bindings,
# which a nix-store python does not carry.
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
      Environment = [ "PATH=${scriptPath}:${dotfiles}/bin:/usr/bin" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
