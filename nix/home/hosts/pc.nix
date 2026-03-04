{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  imports = [
    ../common.nix
    ../pc-timers.nix
  ];

  targets.genericLinux.enable = false;

  home.packages = [
    (pkgs.btop.override { cudaSupport = true; })
  ];
}
