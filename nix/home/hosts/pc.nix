{ ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  imports = [
    ../pc-timers.nix
    ../syncthing.nix
  ];
}
