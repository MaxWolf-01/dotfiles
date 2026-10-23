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

  home.sessionVariables.SOPS_AGE_KEY_FILE = "/home/max/.local/secrets/age-key.txt";
}
