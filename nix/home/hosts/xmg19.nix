{ ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  imports = [
    ../common.nix
    ../ghostty.nix
    ../hyprland.nix
  ];

  targets.genericLinux.enable = false;

  # Long unattended jobs (dispatch workers, training runs) go here instead of
  # dying when this laptop suspends.
  home.sessionVariables.MX_WORKER_HOST = "pc";
}
