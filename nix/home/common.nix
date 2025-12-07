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

  # Shell integration via programs modules
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
    # CLI tools
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

    # Fonts
    nerd-fonts.ubuntu-sans

    # GUI apps
    nemo
    vesktop
  ];
}
