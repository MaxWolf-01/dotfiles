{ pkgs, rime, system, ... }:
{
  imports = [
    ./tmux.nix
  ];

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
    # btop - compiled from source in setup script for GPU support
    cargo
    curl
    dysk
    fastfetch
    fd
    gh
    git
    git-lfs
    gnumake
    go
    jq
    manix
    neovim
    nnn
    nodejs
    nvtopPackages.full
    openssh
    restic
    ripgrep
    rime.packages.${system}.default
    sqlite
    sops
    stripe-cli
    tree
    uv
    vim
  ];
}
