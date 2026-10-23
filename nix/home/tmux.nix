{ config, pkgs, lib, ... }:
let
  tmux = "${pkgs.tmux}/bin/tmux";
  # Restores the last save when no server is running; tmux-restore.sh says how.
  # Tested by tests/tmux-restore.test.
  tmuxRestore = pkgs.writeShellScript "tmux-restore" ''
    exec ${pkgs.bash}/bin/bash ${./tmux-restore.sh} ${tmux} "$HOME/.tmux/resurrect" "$@"
  '';

  tms = pkgs.writeShellScriptBin "tms" ''
    if [ -z "$1" ] || [ "$1" = "0" ]; then
      echo "Usage: tms <session-name> (name '0' is reserved)"
      exit 1
    fi

    ${tmuxRestore} "$(${pkgs.ncurses}/bin/tput cols)" "$(${pkgs.ncurses}/bin/tput lines)"
    exec ${tmux} new-session -A -s "$1"
  '';

  # `tmux` on PATH is the guard in tmux-guard.sh, with the real binary behind
  # it; the script's header says what it refuses. Tested by tests/tmux-guard.test.
  tmuxGuard = lib.hiPrio (pkgs.writeShellScriptBin "tmux" ''
    exec ${pkgs.bash}/bin/bash ${./tmux-guard.sh} ${tmux} "$@"
  '');

  # Saves in tmux-resurrect's format, for its restore; tmux-save.sh says why it
  # replaces resurrect's own save. Tested by tests/tmux-save.test.
  tmuxSave = pkgs.writeShellScript "tmux-save" ''
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.procps pkgs.diffutils pkgs.gnused pkgs.gnutar pkgs.gzip pkgs.jq ]}
    exec ${pkgs.bash}/bin/bash ${./tmux-save.sh} ${tmux} "$HOME/.tmux/resurrect"
  '';

  # The server at boot, restored, or with one session `main` when there is no
  # save. resurrect's restore.sh runs inside the server, on the PATH the server
  # starts with, which a unit gives it here. A detached server has no terminal
  # to size its windows by; they resize to the first client that attaches.
  #
  # TMUX_RESTORED_AT_BOOT=1 is in the environment of the panes this restore
  # creates and of nothing opened later, so a shell's startup can tell that
  # nobody is at the pane to answer a prompt, and that the keys arriving are
  # the resume command restore.sh types.
  tmuxBoot = pkgs.writeShellScript "tmux-boot" ''
    PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.gnused pkgs.gnutar pkgs.gzip pkgs.tmux ]}:$PATH
    export TMUX_RESTORED_AT_BOOT=1
    ${tmuxRestore} 200 50
    ${tmux} set-environment -g -u TMUX_RESTORED_AT_BOOT 2>/dev/null
    ${tmux} list-sessions &>/dev/null || exec env -u TMUX_RESTORED_AT_BOOT ${tmux} new-session -d -s main
  '';

  # The house night colours (mx house-style tokens; yellow is nvim's
  # nvim/colors/house.lua code yellow), for what tmux draws over a pane.
  house = {
    ground2 = "#1b1713";
    edge = "#463f37";
    muted = "#b0a89e";
    accent = "#75a252";
    yellow = "#bda773";
  };
in
{
  options.tmuxServer.atBoot = lib.mkEnableOption ''
    the tmux server from boot, restored from the last save, for a host whose
    sessions have to come back after a reboot with nobody logged in. It needs
    lingering on, so the user's systemd starts at boot. Elsewhere `tms`
    restores when it finds no server'';

  # A oneshot that stays active, so a server already running when it starts is
  # left alone. A switch keeps the running server: restarting the unit ends
  # every session in it, and so does stopping it, or removing it from the config.
  config.systemd.user.services.tmux-server = lib.mkIf config.tmuxServer.atBoot {
    Unit = {
      Description = "tmux server, restored from the last save";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [ "TMUX_TMPDIR=%t" ];
      ExecStart = toString tmuxBoot;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Systemd timer for tmux session auto-save (more reliable than continuum)
  config.systemd.user.services.tmux-resurrect-save = {
    Unit.Description = "Save tmux sessions";
    Service = {
      Type = "oneshot";
      Environment = [ "TMUX_TMPDIR=%t" ];
      ExecStart = toString (pkgs.writeShellScript "tmux-save" ''
        ${tmux} list-sessions &>/dev/null || exit 0

        # Skip save while restore is in progress (session "0" only exists during restore)
        ${tmux} has-session -t 0 2>/dev/null && exit 0

        ${tmuxSave}
      '');
    };
  };
  config.systemd.user.timers.tmux-resurrect-save = {
    Unit.Description = "Auto-save tmux sessions every minute";
    Timer = {
      OnBootSec = "1min";
      # 1min is a deliberate freshness choice. systemd may delay a timer by up to
      # its AccuracySec to batch wakeups, 1min by default, which stretched the
      # gaps between saves to 60-120 s.
      OnUnitActiveSec = "1min";
      AccuracySec = "1s";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Hourly, apart from the save: a file can outlive its retention by up to an
  # hour.
  config.systemd.user.services.tmux-resurrect-prune = {
    Unit.Description = "Prune old tmux saves";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "tmux-resurrect-prune" ''
        resurrect_dir="$HOME/.tmux/resurrect"

        # Retention: 8 days for the kept pane archives (tmux-save keeps one per
        # archive it writes), 14 for the state files below. The archives are what
        # the offsite backup pays for, ~130 MB a day against the state files'
        # ~1 MB, and 8 days still carries each archive to the snapshot that
        # captures it for as long as one snapshot a week survives retention.
        # Further back the survivors are a month apart and no window worth
        # keeping on disk bridges that. Both pipelines keep a 100k count cap
        # that cannot bind under real usage (8d of every-minute saves is ~11.5k)
        # and only guards runaway growth. Worst case: tars ~11.5k x ~250 KB =
        # ~2.9 GB, state files ~100 MB.
        ${pkgs.findutils}/bin/find "$resurrect_dir" -maxdepth 1 -name 'pane_contents_*.tar.gz' -mtime +8 -delete
        ${pkgs.coreutils}/bin/ls -t "$resurrect_dir"/pane_contents_*.tar.gz 2>/dev/null | ${pkgs.coreutils}/bin/tail -n +100001 | ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/rm

        # Resurrect dedupes identical consecutive state files but never deletes
        # old distinct ones. The newest is always kept: dedupe means it can
        # itself age past 14 days (unchanged layout), and deleting it would
        # dangle `last`.
        newest=$(${pkgs.coreutils}/bin/readlink -f "$resurrect_dir/last" 2>/dev/null)
        ${pkgs.findutils}/bin/find "$resurrect_dir" -maxdepth 1 -name 'tmux_resurrect_*.txt' -mtime +14 ! -path "$newest" -delete
        ${pkgs.coreutils}/bin/ls -t "$resurrect_dir"/tmux_resurrect_*.txt 2>/dev/null | ${pkgs.coreutils}/bin/tail -n +100001 | ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/rm
      '');
    };
  };
  config.systemd.user.timers.tmux-resurrect-prune = {
    Unit.Description = "Prune old tmux saves hourly";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  config.home.packages = [ tms tmuxGuard ];

  # tmux puts every pane in its own tmux-spawn-<uuid>.scope, and systemd-oomd
  # relieves memory pressure by SIGKILLing one whole scope. Panes hold the
  # work (agents, editors, servers); browsers and other desktop apps are
  # cheaper to lose, so panes are the last candidates. The prefix directory
  # covers every pane scope, at creation: panes already running when the
  # drop-in lands are not marked.
  config.xdg.configFile."systemd/user/tmux-spawn-.scope.d/oomd.conf".text = ''
    [Scope]
    ManagedOOMPreference=avoid
  '';

  config.programs.tmux = {
    enable = true;

    # Core
    prefix = "C-a";
    escapeTime = 0;
    historyLimit = 50000;
    baseIndex = 1;
    mouse = true;
    focusEvents = true;

    # Vi mode + hjkl navigation/resize
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    resizeAmount = 4;

    # Plugins (managed by Nix, no TPM needed)
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
          # tmux-save saves a Claude Code session's pane with the command that resumes it
          set -g @resurrect-processes '"~claude --resume "'
        '';
      }
    ];

    extraConfig = ''
      # Ctrl+a Ctrl+a sends Ctrl+a to shell (for beginning-of-line)
      bind C-a send-keys C-a

      # Unbind layout cycling (easy to trigger accidentally)
      unbind Space

      # True color support
      set -g default-terminal "tmux-256color"
      set -ga terminal-overrides ",*256col*:Tc"
      set -ga terminal-overrides ",xterm-ghostty:Tc"
      set -as terminal-overrides ',xterm-ghostty:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',xterm-ghostty:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Enter copy mode (easier than [)
      bind v copy-mode
      bind / copy-mode \; send-keys /

      # Vi copy mode bindings
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe "wl-copy"
      bind -T copy-mode-vi C-v send -X rectangle-toggle
      bind -T copy-mode-vi Escape send -X cancel

      # Copy the pane's screen to the clipboard; in copy mode, the scrolled-to screen.
      # Goes through the terminal (load-buffer -w), not wl-copy: on GNOME wl-copy
      # grabs focus for a moment, and the focus change clears the message at once.
      bind y run-shell "${tmux} capture-pane -pJM -t '#{pane_id}' | ${tmux} load-buffer -w -t '#{client_name}' -" \; display "Screen copied"

      # Open the pane's whole scrollback in nvim. The capture runs in run-shell
      # because display-popup does not expand #{pane_id} in its command.
      # Replaces the default session list (s); prefix f picks sessions.
      bind s run-shell "${tmux} capture-pane -pJS - -t '#{pane_id}' > \$XDG_RUNTIME_DIR/tmux-scrollback.txt" \; \
        display-popup -E -w 90% -h 90% "nvim + \$XDG_RUNTIME_DIR/tmux-scrollback.txt; rm -f \$XDG_RUNTIME_DIR/tmux-scrollback.txt"

      # Intuitive splits (in current directory)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"

      # New window in current directory
      bind c new-window -c "#{pane_current_path}"
      bind -n C-S-t new-window -c "#{pane_current_path}"

      # Session switching with fzf
      bind f display-popup -E "tmux list-sessions -F '#{session_name}' | fzf --reverse | xargs -r tmux switch-client -t"

      # Create new session
      bind S command-prompt -p "New session name:" "new-session -s '%%'"

      # Swap windows (no prefix)
      bind -n C-S-Left swap-window -t -1\; select-window -t -1
      bind -n C-S-Right swap-window -t +1\; select-window -t +1

      # Alt+number to switch windows
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9

      # Alt+qweasdf to switch panes (2x3 block + f for buffer)
      bind -n M-q select-pane -t 1
      bind -n M-w select-pane -t 2
      bind -n M-e select-pane -t 3
      bind -n M-a select-pane -t 4
      bind -n M-s select-pane -t 5
      bind -n M-d select-pane -t 6
      bind -n M-f select-pane -t 7

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # Ctrl+s to save (no prefix needed!). The prefix binding replaces the
      # resurrect plugin's, which runs its own save.sh: that writes the archive in
      # place, through the hardlink tmux-save keeps of it.
      bind -n C-s run-shell '${tmuxSave}' \; display-message "tmux sessions saved"
      bind C-s run-shell '${tmuxSave}' \; display-message "tmux sessions saved"

      # Detach to terminal when session is destroyed (instead of switching to another)
      set -g detach-on-destroy on

      # The status bar and messages name palette slots (colour0-15) and
      # `default`, so they follow the palette ghostty draws (terminal-colors.nix);
      # the rest takes the `house` colours set at the top of tmux.nix. The accent
      # green marks where your keys go: the active pane, a pending prefix.
      set -g status-position bottom
      set -g status-style "bg=default,fg=colour7,dim"
      set -g status-left-length 30
      set -g status-left "#{?client_prefix,#[fg=${house.accent}],#[fg=colour15]}#[bold,nodim] #S #[fg=colour8,nobold]│ "
      set -g status-right "%H:%M "
      setw -g window-status-separator ""
      setw -g window-status-format " #I:#W "
      setw -g window-status-current-format "#[fg=colour15,bold,nodim] #I:#W "
      setw -g window-status-activity-style "fg=colour3,nodim"
      set -g pane-border-style "fg=${house.edge}"
      set -g pane-active-border-style "fg=${house.accent}"
      set -g pane-border-indicators both
      set -g message-style "bg=colour8,fg=colour15"
      set -g message-command-style "bg=${house.edge},fg=${house.yellow}"
      # Selection and search hits only tint the ground, so the text under them
      # keeps its own colours.
      setw -g mode-style "bg=${house.edge}"
      setw -g copy-mode-match-style "bg=${house.edge},fg=${house.yellow}"
      setw -g copy-mode-current-match-style "bg=${house.yellow},fg=${house.ground2}"
      set -g popup-style "bg=${house.ground2}"
      # tmux drops dim on a popup border, and edge is too faint to frame one.
      set -g popup-border-style "fg=${house.muted}"
      setw -g clock-mode-colour "${house.accent}"
    '';
  };
}
