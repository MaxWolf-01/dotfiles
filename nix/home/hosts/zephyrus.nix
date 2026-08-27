{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  home.packages = [ pkgs.brave ];

  # This machine's capability record, read by a worker running locally and by
  # `worker-hosts` (bin/). No @TOOLCHAIN@ token: what is installed here is
  # spread across common.nix and its imports rather than one list, so the
  # record points at the config instead of enumerating it.
  home.file."HOST.md".source = ./zephyrus/HOST.md;

  imports = [
    ../desktop.nix
    ../gnome.nix
    ../greyline.nix
    ../timers.nix
    ../vibe-typer.nix
    ../wayland.nix
  ];
}
