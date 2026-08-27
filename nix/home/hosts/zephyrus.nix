{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  home.packages = [ pkgs.brave ];

  imports = [
    ../desktop.nix
    ../gnome.nix
    ../greyline.nix
    ../timers.nix
    ../vibe-typer.nix
    ../wayland.nix
  ];
}
