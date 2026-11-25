{ config, pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      font-family = "UbuntuSansMono Nerd Font Mono";
      shell-integration-features = "ssh-terminfo,ssh-env";
      # Every window opens in tmux (tmux-window.sh); `ghostty -e <command>` skips it.
      command = "direct:${config.home.profileDirectory}/bin/tmux-window";
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

  # The way in when tmux itself is what needs fixing.
  xdg.desktopEntries.ghostty-plain = {
    name = "Ghostty (plain shell)";
    comment = "A terminal outside tmux";
    exec = "ghostty -e zsh";
    icon = "com.mitchellh.ghostty";
    categories = [ "System" "TerminalEmulator" ];
  };

  home.packages = [
    pkgs.nerd-fonts.ubuntu-sans
  ];
}
