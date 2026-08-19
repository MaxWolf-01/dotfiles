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
  # unprivileged user of their own there (nix/nixos/pc/agent-user.nix). That
  # user authorizes zephyrus's key only, so dispatch from here fails until
  # this host's key is added there too.
  home.sessionVariables.MX_WORKER_HOST = "agent@pc";
}
