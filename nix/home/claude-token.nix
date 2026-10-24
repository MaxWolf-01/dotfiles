# `claude` on PATH is claude-token.sh in front of the real binary, which the
# installer keeps in ~/.local/bin; the script's header says which token it
# hands each profile in each mode. Home Manager's profile (~/.nix-profile, or
# /etc/profiles/per-user/<user> where Home Manager is a NixOS module) comes first
# on an interactive shell's PATH (zsh/exports) and on every unit's that runs
# claude, which is what puts it in front.
# Tested by tests/claude-token.test.
{ config, lib, pkgs, ... }:
{
  options.claudeToken.mode = lib.mkOption {
    type = lib.types.enum [ "profile" "switch" ];
    default = "profile";
    description = ''
      profile: every profile runs on its account's token. switch: every profile
      runs on its own /login unless `claude-account` switched the host.
    '';
  };

  config = {
    # An ssh command's zsh reads .zshenv alone, whose PATH these go in front of,
    # in this order: without ~/.local/bin it finds no real claude, and with it
    # alone the real claude comes before the wrapper.
    home.sessionPath = [
      "${config.home.profileDirectory}/bin"
      "${config.home.homeDirectory}/.local/bin"
    ];

    home.packages = [
      (pkgs.writeShellScriptBin "claude" ''
        exec ${pkgs.bash}/bin/bash ${./claude-token.sh} ${pkgs.sops}/bin/sops "$0" ${config.claudeToken.mode} "$@"
      '')
    ];
  };
}
