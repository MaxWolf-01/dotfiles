{ ... }:
{
  home.stateVersion = "24.05";

  imports = [
    ../desktop.nix
    ../gnome.nix
    ../wayland.nix
  ];
}
