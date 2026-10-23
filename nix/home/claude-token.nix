# `claude` on PATH is claude-token.sh in front of the real binary, which the
# installer keeps in ~/.local/bin; the script's header says which token it
# hands each profile. ~/.nix-profile/bin comes first on a shell's PATH and on
# every unit's here that runs claude, which is what puts it in front.
# Tested by tests/claude-token.test.
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "claude" ''
      exec ${pkgs.bash}/bin/bash ${./claude-token.sh} ${pkgs.sops}/bin/sops "$0" "$@"
    '')
  ];
}
