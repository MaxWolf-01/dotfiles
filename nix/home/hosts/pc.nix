{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  imports = [
    ../claude-token.nix
    ../common.nix
    ../container-hub.nix
    ../pc-timers.nix
  ];

  # No loopback port, since the dispatch workers run beside max here. The
  # socket goes on the tailnet through the serve table pc's system config owns
  # (nix/nixos/pc/container-hub.nix).
  containerHub.url = "https://pc.tail710178.ts.net:8377";
  containerHub.host = "pc";

  tmuxServer.atBoot = true;

  targets.genericLinux.enable = false;

  # Decrypted to tmpfs from ~/.local/secrets/age-key.txt.enc at the first
  # interactive login after a boot (secrets/zshrc).
  home.sessionVariables.SOPS_AGE_KEY_FILE = "/run/user/1000/age-key.txt";

  home.packages = [
    (pkgs.btop.override { cudaSupport = true; })
  ];
}
