{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";

  programs.home-manager.enable = true;

  # Non-NixOS: add ~/.nix-profile/share to XDG_DATA_DIRS so GNOME finds desktop entries
  targets.genericLinux.enable = true;

  xdg.enable = true;

  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ../../zsh/zshrc;
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
    ast-grep
    # btop - compiled from source in setup script for GPU support
    cargo
    curl
    dysk
    fastfetch
    fastmod
    fd
    ffmpeg
    git
    git-lfs
    gnumake
    go
    jq
    neovim
    nodejs
    nvtopPackages.full
    openssh
    restic
    ripgrep
    sops
    tmux
    tree
    uv
    vim
    yt-dlp
  ];
}
