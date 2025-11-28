{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    btop
    fastfetch
    fzf
    git
    git-lfs
    jq
    neovim
    ripgrep
    tmux
    tree
    zoxide
  ];
}
