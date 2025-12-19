{ ... }:
{
  home.stateVersion = "24.05";

  imports = [
    ../desktop.nix
    ../gnome.nix
    ../x11.nix
  ];
}
