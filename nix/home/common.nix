{ pkgs, config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  xdg.enable = true;

  home.file.".config/vesktop/themes/custom.theme.css".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/desktop/discord/themes/custom.theme.css";

  home.packages = with pkgs; [
    btop
    fastfetch
    fzf
    git
    git-lfs
    jq
    nemo
    neovim
    ripgrep
    tmux
    tree
    vesktop
    zoxide
  ];
}
