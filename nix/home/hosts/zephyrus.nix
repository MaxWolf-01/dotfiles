{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  home.packages = [ pkgs.brave ];

  imports = [
    ../desktop.nix
    ../gnome.nix
    ../timers.nix
    ../wayland.nix
  ];
}
