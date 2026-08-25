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
  # dying when this laptop suspends. As `agent`, not as max: workers get an
  # unprivileged user of their own there (nix/nixos/pc/agent-user.nix). Dispatch
  # from here needs this host's key in that user's authorizedKeys.
  home.sessionVariables.MX_WORKER_HOST = "agent@pc";
}
