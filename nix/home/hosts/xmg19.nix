{ ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  imports = [
    ../ghostty.nix
    ../hyprland.nix
  ];
}
