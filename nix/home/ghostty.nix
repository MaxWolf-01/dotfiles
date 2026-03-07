{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      font-family = "UbuntuSansMono Nerd Font Mono";
      shell-integration-features = "ssh-terminfo,ssh-env";
      confirm-close-surface = false;
      copy-on-select = "clipboard";
      # Pass Alt+N through to tmux instead of ghostty tab switching
      keybind = "alt+one=unbind\nalt+two=unbind\nalt+three=unbind\nalt+four=unbind\nalt+five=unbind\nalt+six=unbind\nalt+seven=unbind\nalt+eight=unbind\nalt+nine=unbind\nctrl+shift+t=unbind";
    };
  };

  home.packages = [
    pkgs.nerd-fonts.ubuntu-sans
  ];
}
