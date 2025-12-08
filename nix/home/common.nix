{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  xdg.enable = true;

  programs.zsh = {
    enable = true;
    initExtra = ''
      source ~/.dotfiles/zsh/zshrc
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    age
    # btop - compiled from source in setup script for GPU support
    cargo
    curl
    dysk
    fastfetch
    git
    git-lfs
    gnumake
    go
    jq
    neovim
    nvtopPackages.full
    openssh
    ripgrep
    sops
    tmux
    tree
    uv
    vim
  ];
}
