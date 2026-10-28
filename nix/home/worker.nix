# Home Manager for a dispatch worker user on pc or xmg19.
# nix/nixos/agent-user.nix creates the users; this is a function of what
# differs between them: the user's name and the identity its commits carry.
# Its entry in ./machines.nix says the rest. It does not import common.nix,
# which is max's environment (his git identity, ssh hosts, symlinks into
# ~/.dotfiles); a worker user gets only what a worker needs.
#
# Done by hand once per user, over `ssh <user>@<host>`: install claude (`curl
# -fsSL https://claude.ai/install.sh | bash`) and the plugin (`claude plugin
# marketplace add MaxWolf-01/agents`, `claude plugin install mx@MaxWolf-01`).
# Dispatch updates the plugin at the start of every run. Claude signs in with
# no browser: `clawd push` on zephylux gives the user its account's
# token.
{ name, identity }:
{ config, osConfig, pkgs, lib, ... }:

let
  host = osConfig.networking.hostName;
  # Installed as packages, and listed in HOST.md by mainProgram (`make`, `rg`),
  # so the record names the commands a worker types and cannot list a tool that
  # is not installed. A package without mainProgram fails evaluation.
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
    # mainProgram is the versioned `python3.14`; the record names what a worker types.
    (lib.addMetaAttrs { mainProgram = "python3"; } python3)
    ripgrep
    rsync
    tmux
    uv
    xvfb-run
  ];

  # max's own value, from his Claude Code settings in the agents repo.
  cleanupPeriodDays = 99999;
in
{
  home.username = name;
  home.homeDirectory = "/home/${name}";
  home.stateVersion = "26.05";

  targets.genericLinux.enable = false;

  home.packages = toolchain;

  # The claude installer puts its binary here and cannot add it to PATH itself:
  # home-manager owns .zshrc as a read-only store symlink.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # This user's own rootless daemon. Set per user rather than through
  # `virtualisation.docker.rootless.setSocketVariable`, which would export it
  # for max too; see nix/nixos/agent-user.nix.
  home.sessionVariables.DOCKER_HOST =
    "unix:///run/user/${toString osConfig.users.users.${name}.uid}/docker.sock";

  # `ssh <user>@<host> <cmd>` runs a non-login zsh, which reads .zshenv and nothing
  # else; that is where home-manager puts the session variables and PATH above.
  programs.zsh.enable = true;

  # Every process an ssh command starts inherits it; why 500 is beside the
  # memory ceiling in nix/nixos/agent-user.nix.
  programs.zsh.envExtra = ''
    if (( $(</proc/self/oom_score_adj) < 500 )); then echo 500 >/proc/self/oom_score_adj; fi
  '' + builtins.readFile ./worker-claude-token.zsh;

  # Claude Code deletes transcripts older than cleanupPeriodDays, 30 by
  # default, and a worker's transcripts are kept for good, as max's are: the
  # laptop's session copies carry them into its backups. Merged into the
  # settings file rather than owned by home-manager, because `claude plugin
  # install` and dispatch's plugin updates write that file too.
  home.activation.claudeKeepsTranscripts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.claude/settings.json"
    if ! ${pkgs.jq}/bin/jq -e '.cleanupPeriodDays == ${toString cleanupPeriodDays}' "$settings" > /dev/null 2>&1; then
      if [[ -v DRY_RUN ]]; then
        echo "would set cleanupPeriodDays in $settings"
      else
        mkdir -p "$(dirname "$settings")"
        [[ -s $settings ]] || echo '{}' > "$settings"
        tmp=$(mktemp "$settings.hm-XXXXXX")
        if ${pkgs.jq}/bin/jq '.cleanupPeriodDays = ${toString cleanupPeriodDays}' "$settings" > "$tmp"; then
          mv "$tmp" "$settings"
        else
          rm -f "$tmp"
          echo "claude: $settings is not JSON jq can read, so cleanupPeriodDays is not set; transcripts older than 30 days will be deleted" >&2
        fi
      fi
    fi
  '';

  # Commit identity. There is no GitHub credential here; the identity matters
  # because the commits leave this host by push and land in `git log`.
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
  # the machine is headless. Enough to attach and watch a worker.
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

  imports = [ ./machines.nix ];

  # What dispatch reads before planning a wave, and what `worker-hosts` (bin/)
  # shows for this user. Its frontmatter is the user's entry in ./machines.nix;
  # the rest is hand-written: the user's own lead paragraph, in
  # ./hosts/<host>-<user>/HOST.md, kept in the checkout so that a host which is
  # down still describes itself to the orchestrator. @BODY@ there is the
  # machine's tools and limits, ./hosts/<host>-worker-body.md, one file shared
  # by every worker user on it; @TOOLCHAIN@ inside that is the package list
  # above.
  home.file."HOST.md".text =
    let
      tools = lib.concatStringsSep " " (
        map (c: "`${c}`") (lib.sort lib.lessThan (map (p: p.meta.mainProgram) toolchain))
      );
      record = builtins.readFile (./hosts + "/${host}-${name}/HOST.md");
      body = builtins.readFile (./hosts + "/${host}-worker-body.md");
    in
    config.machineRecords."${name}@${host}"
    + builtins.replaceStrings [ "@TOOLCHAIN@" ] [ tools ] (builtins.replaceStrings [ "@BODY@\n" ] [ body ] record);
}
