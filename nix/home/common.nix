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
    ast-grep
    # btop - compiled from source in setup script for GPU support
    cargo
    curl
    duckdb
    dysk
    fastfetch
    fastmod
    fd
    ffmpeg
    gh
    git
    git-lfs
    gnumake
    go
    jq
    manix
    neovim
    nerd-fonts.hack
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
    yt-dlp
  ];

  # Weekly GC: delete generations older than 30 days, then remove unreferenced store paths.
  # Works together with min-free/max-free in /etc/nix/nix.conf (daemon-level safety net).
  systemd.user.services.nix-gc = {
    Unit.Description = "Nix garbage collection";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 30d";
    };
  };

  systemd.user.timers.nix-gc = {
    Unit.Description = "Weekly Nix garbage collection";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
