# `claude` on PATH is claude-token.sh in front of the real binary, which the
# installer keeps in ~/.local/bin; the script's header says which token it
# hands each profile. Home Manager's profile (~/.nix-profile, or
# /etc/profiles/per-user/<user> where Home Manager is a NixOS module) comes first
# on an interactive shell's PATH (zsh/exports) and on every unit's that runs
# claude, which is what puts it in front.
# Tested by tests/claude-token.test.
{ config, pkgs, ... }:
{
  # An ssh command's zsh reads .zshenv alone, so without these it finds the
  # wrapper behind ~/.local/bin, or no real claude at all.
  home.sessionPath = [
    "${config.home.profileDirectory}/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.packages = [
    (pkgs.writeShellScriptBin "claude" ''
      exec ${pkgs.bash}/bin/bash ${./claude-token.sh} ${pkgs.sops}/bin/sops "$0" "$@"
    '')
  ];
}
