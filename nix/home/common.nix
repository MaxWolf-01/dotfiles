{ pkgs, lib, rime, system, ... }:
{
  imports = [
    ./tmux.nix
  ];

  programs.home-manager.enable = true;

  # Non-NixOS: add ~/.nix-profile/share to XDG_DATA_DIRS so GNOME finds desktop entries
  targets.genericLinux.enable = lib.mkDefault true;

  xdg.enable = true;

  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ../../zsh/zshrc;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [
      "agent/transcripts"
      "agent/handoffs"
      "agent/research"
      ".claude"
      "node_modules"
      "repomix-output.*"
      "**/uv.lock"
      ".idea"
      ".vscode"
      "*.swp"
      "*.class"
      "*.dll"
      "*.exe"
      "*.o"
      "*.so"
      "*.pyc"
      ".pytest_cache"
      ".mypy_cache"
      ".ruff_cache"
      ".venv"
      "build"
      "*.log"
      "*.sqlite"
      "*.db"
      "*.zip"
      "*.gz"
      "*.tar"
      "*.tar.gz"
      "*.7z"
      "*.pdf"
      "**/notes/*"
      "**/notebooks/*"
    ];
    attributes = [
      "*.lockb binary diff=lockb"
    ];
    includes = [
      { path = "~/.gitconfig_local"; }
    ];
    settings = {
      user.name = "Maximilian Wolf";
      user.email = "69987866+MaxWolf-01@users.noreply.github.com";
      init.defaultBranch = "master";
      push.default = "current";
      credential."https://github.com".helper = "!gh auth git-credential";
      diff.lockb = { textconv = "bun"; binary = true; };
      help.autocorrect = 2;
      branch.sort = "-committerdate";
      transfer.fsckobjects = true;
      fetch.fsckobjects = true;
      receive.fsckObjects = true;
      pull.rebase = false;
    };
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
    cargo
    curl
    duckdb
    dust
    dysk
    fastfetch
    fastmod
    fd
    ffmpeg
    gcc
    gh
    gnumake
    go
    jq
    manix
    ncdu
    neovim
    nerd-fonts.hack
    nnn
    nodejs
    nvtopPackages.full
    openssh
    python3Packages.ipdb
    pywal
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
