{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  home.packages = [ pkgs.brave ];

  # Long unattended jobs (dispatch workers, training runs) go here instead of
  # dying when this laptop suspends. As `agent`, not as max: workers get an
  # unprivileged user of their own there (nix/nixos/pc/agent-user.nix).
  home.sessionVariables.MX_WORKER_HOST = "agent@pc";

  imports = [
    ../desktop.nix
    ../gnome.nix
    ../greyline.nix
    ../timers.nix
    ../vibe-typer.nix
    ../wayland.nix
  ];
}
