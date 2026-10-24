{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  imports = [
    ../claude-token.nix
    ../common.nix
    ../pc-timers.nix
  ];

  targets.genericLinux.enable = false;

  # Decrypted to tmpfs from ~/.local/secrets/age-key.txt.enc at the first
  # interactive login after a boot (secrets/zshrc).
  home.sessionVariables.SOPS_AGE_KEY_FILE = "/run/user/1000/age-key.txt";

  home.packages = [
    (pkgs.btop.override { cudaSupport = true; })
  ];
}
