{ ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  imports = [
    ../desktop.nix
    ../gnome.nix
    ../timers.nix
    ../x11.nix
  ];
}
