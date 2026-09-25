{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
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
