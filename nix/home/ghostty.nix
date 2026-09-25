{ pkgs, lib, ... }:
let
  # The colours are config rather than pywal's escapes, which it writes to
  # every open terminal and would paint over bin/ssh-tint's tint. The prompt
  # and LS_COLORS read the same file through wal's cache
  # (zsh/wal-theme-config.zsh).
  wal = builtins.fromJSON (builtins.readFile ../../zsh/wal-themes/ghibli-dark.json);
in
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      background = wal.special.background;
      foreground = wal.special.foreground;
      cursor-color = wal.special.cursor;
      palette = map (i: "${toString i}=${wal.colors."color${toString i}"}") (lib.range 0 15);
      font-family = "UbuntuSansMono Nerd Font Mono";
      shell-integration-features = "ssh-terminfo,ssh-env";
      confirm-close-surface = false;
      clipboard-paste-protection = false;
      copy-on-select = "clipboard";
      # Pass Alt+N through to tmux instead of ghostty tab switching
      keybind = [
        "alt+one=unbind"
        "alt+two=unbind"
        "alt+three=unbind"
        "alt+four=unbind"
        "alt+five=unbind"
        "alt+six=unbind"
        "alt+seven=unbind"
        "alt+eight=unbind"
        "alt+nine=unbind"
        "ctrl+shift+t=unbind"
        "shift+enter=text:\\n" # https://github.com/anthropics/claude-code/issues/1282
      ];
    };
  };

  home.packages = [
    pkgs.nerd-fonts.ubuntu-sans
  ];
}
