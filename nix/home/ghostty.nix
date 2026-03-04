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
    };
  };

  home.packages = [
    pkgs.nerd-fonts.ubuntu-sans
  ];
}
