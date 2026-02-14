{ pkgs, ... }:
{
  # Systemd timer for tmux session auto-save (more reliable than continuum)
  systemd.user.services.tmux-resurrect-save = {
    Unit.Description = "Save tmux sessions";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "tmux-save" ''
        # Only save if tmux server is running
        ${pkgs.tmux}/bin/tmux list-sessions &>/dev/null || exit 0
        # Get the save script path from tmux and run it
        save_script=$(${pkgs.tmux}/bin/tmux show-options -gqv @resurrect-save-script-path)
        [ -x "$save_script" ] && ${pkgs.tmux}/bin/tmux run-shell "$save_script"
      '');
    };
  };
  systemd.user.timers.tmux-resurrect-save = {
    Unit.Description = "Auto-save tmux sessions every minute";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  programs.tmux = {
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
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '1'
          set -g @continuum-save-last-timestamp '0'
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

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Enter copy mode (easier than [)
      bind v copy-mode
      bind / copy-mode \; send-keys /

      # Vi copy mode bindings
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "xclip -selection clipboard -i"
      bind -T copy-mode-vi C-v send -X rectangle-toggle
      bind -T copy-mode-vi Escape send -X cancel

      # Intuitive splits (in current directory)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"

      # New window in current directory
      bind c new-window -c "#{pane_current_path}"

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

      # Ctrl+s to save (no prefix needed!)
      bind -n C-s run-shell '#{@resurrect-save-script-path}'

      # Detach to terminal when session is destroyed (instead of switching to another)
      set -g detach-on-destroy on

      # Status bar (clean, minimal)
      set -g status-position bottom
      set -g status-style "bg=colour235,fg=colour250"
      set -g status-left-length 30
      set -g status-left "#[fg=colour117,bold] #S #[fg=colour244]│ "
      set -g status-right "#[fg=colour244]%H:%M "
      set -g window-status-format "#[fg=colour244] #I:#W "
      set -g window-status-current-format "#[fg=colour117,bold] #I:#W "
      set -g pane-border-style "fg=colour238"
      set -g pane-active-border-style "fg=colour117"
    '';
  };
}
