{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  imports = [
    ../common.nix
    ../container-hub.nix
    ../pc-timers.nix
  ];

  # No loopback port: the dispatch workers run beside max here. The socket goes
  # on the tailnet through the serve table pc's system config owns
  # (nix/nixos/pc/container-hub.nix).
  containerHub.url = "https://pc.tail710178.ts.net:8377";

  targets.genericLinux.enable = false;

  home.packages = [
    (pkgs.btop.override { cudaSupport = true; })
  ];
}
