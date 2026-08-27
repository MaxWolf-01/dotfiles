# Home Manager for `agent@pc` -- the user dispatch workers run as. Deliberately
# not an import of common.nix: that file is max's environment, down to his git
# identity, his ssh hosts and symlinks into ~/.dotfiles, none of which exist or
# belong here. This user starts from nothing and gets only what a worker needs.
{ config, osConfig, pkgs, lib, ... }:

let
  # The one list: installed as packages and named in HOST.md below, so the
  # record dispatch reads cannot drift from what is actually here. It is
  # rendered there by mainProgram, because a worker looks for `make` and `rg`,
  # not for `gnumake` and `ripgrep`. A package that declares no mainProgram
  # fails evaluation rather than falling back to its package name -- the record
  # naming a command that does not exist is the failure worth being loud about.
  toolchain = with pkgs; [
    ast-grep
    chromium
    curl
    fd
    gh
    git
    gnumake
    jq
    nodejs
    ripgrep
    rsync
    tmux
    uv
    xvfb-run
  ];
in
{
  home.username = "agent";
  home.homeDirectory = "/home/agent";
  home.stateVersion = "26.05";

  targets.genericLinux.enable = false;

  home.packages = toolchain;

  # The claude native installer puts its binary here, and cannot add it to PATH
  # itself: home-manager owns .zshrc as a read-only store symlink.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # Points at this user's own rootless daemon. Set per-user rather than through
  # `virtualisation.docker.rootless.setSocketVariable`, which would export it
  # for max too -- see nix/nixos/pc/agent-user.nix.
  home.sessionVariables.DOCKER_HOST =
    "unix:///run/user/${toString osConfig.users.users.agent.uid}/docker.sock";

  # Minimal on purpose: `ssh agent@pc <cmd>` runs a non-login zsh, which reads
  # .zshenv and nothing else -- that is where home-manager puts the session
  # variables and PATH above.
  programs.zsh.enable = true;

  programs.git = {
    enable = true;
    settings = {
      # Worker commits are attributable in `git log` as the bot account, not as
      # max. There is no GitHub credential here; this is identity, not access.
      user.name = "MaxWolf-01-clanker";
      user.email = "MaxWolf-01-clanker@users.noreply.github.com";
      init.defaultBranch = "master";
      push.default = "current";
      pull.rebase = false;
    };
  };

  # No resurrect, no clipboard integration: worker sessions are ephemeral and
  # this machine is headless. Just enough that attaching to watch a worker
  # feels like max's own tmux.
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    escapeTime = 0;
    historyLimit = 50000;
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    extraConfig = ''
      set -g default-terminal "tmux-256color"
      set -g renumber-windows on
      set -g status-style "bg=colour235,fg=colour250"
      set -g status-left "#[fg=colour117,bold] #S #[fg=colour244]| "
    '';
  };

  # What dispatch reads before planning a wave, and where `worker-hosts` (bin/)
  # finds this machine's description. Hand-written beside this file so that a
  # host which is down still describes itself from the orchestrator's checkout;
  # only the tool list is spliced in from the packages above, so that half
  # cannot drift from what is installed.
  home.file."HOST.md".text = builtins.replaceStrings [ "@TOOLCHAIN@" ] [
    (lib.concatStringsSep " " (
      map (c: "`${c}`") (lib.sort lib.lessThan (map (p: p.meta.mainProgram) toolchain))
    ))
  ] (builtins.readFile ./pc-agent/HOST.md);
}
