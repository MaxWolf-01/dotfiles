{ ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  imports = [
    ../common.nix
  ];

  targets.genericLinux.enable = false;
}
