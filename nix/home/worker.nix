# Home Manager for a dispatch worker user on pc (nix/nixos/pc/agent-user.nix
# creates the users). A function of what differs between them: the user's
# name, the identity its commits carry, and the HOST.md record it publishes.
# Deliberately not an import of common.nix: that file is max's environment,
# down to his git identity, his ssh hosts and symlinks into ~/.dotfiles, none
# of which exist or belong here. A worker user starts from nothing and gets
# only what a worker needs.
#
# What nix cannot do is done by hand once per user, over `ssh -t <user>@pc`:
# install claude (`curl -fsSL https://claude.ai/install.sh | bash`), log it into
# the user's account (`claude`, then the URL flow), and install the plugin
# (`claude plugin marketplace add MaxWolf-01/agents`, then
# `claude plugin install mx@MaxWolf-01`). Dispatch updates the plugin itself at
# the start of every run.
{ name, identity, record }:
{ config, osConfig, pkgs, lib, ... }:

let
  # The one list: installed as packages, and spliced into HOST.md below. It is
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
  home.username = name;
  home.homeDirectory = "/home/${name}";
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
    "unix:///run/user/${toString osConfig.users.users.${name}.uid}/docker.sock";

  # Minimal on purpose: `ssh <user>@pc <cmd>` runs a non-login zsh, which reads
  # .zshenv and nothing else -- that is where home-manager puts the session
  # variables and PATH above.
  programs.zsh.enable = true;

  # Identity, not access: there is no GitHub credential here. Which identity is
  # the caller's call -- the bot account for personal work, the work address for
  # work -- because the commits leave this host by push and land in `git log`.
  programs.git = {
    enable = true;
    settings = {
      user = identity;
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
  # finds this user's description. Hand-written beside the host config so that
  # a host which is down still describes itself from the orchestrator's
  # checkout. The record is the user's own lead; @BODY@ is the machine's tools
  # and limits, one file for every worker user on it, and inside that the tool
  # list is spliced in from the packages above, so that neither half can drift:
  # not from what is installed, not between the users.
  home.file."HOST.md".text =
    let
      body = builtins.readFile ./hosts/pc-worker-body.md;
      tools = lib.concatStringsSep " " (
        map (c: "`${c}`") (lib.sort lib.lessThan (map (p: p.meta.mainProgram) toolchain))
      );
    in
    builtins.replaceStrings [ "@TOOLCHAIN@" ] [ tools ]
      (builtins.replaceStrings [ "@BODY@\n" ] [ body ] (builtins.readFile record));
}
