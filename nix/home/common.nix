{ config, pkgs, lib, rime, system, ... }:
{
  imports = [
    ./tmux.nix
  ];

  programs.home-manager.enable = true;

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  # Non-NixOS: add ~/.nix-profile/share to XDG_DATA_DIRS so GNOME finds desktop entries
  targets.genericLinux.enable = lib.mkDefault true;

  xdg.enable = true;

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    initContent = builtins.readFile ../../zsh/zshrc;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    history = {
      size = 1000000;
      save = 1000000;
      ignoreAllDups = true;
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [
      "agent/transcripts"
      "agent/handoffs"
      "agent/research"
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

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    extraPackages = with pkgs; [ trash-cli ];
    initLua = ''
      -- Override built-in size linemode to also show mtime
      function Linemode:size()
        local time = math.floor(self._file.cha.mtime or 0)
        local time_str
        if time == 0 then
          time_str = ""
        elseif os.date("%Y", time) == os.date("%Y") then
          time_str = os.date("%m/%d %H:%M", time)
        else
          time_str = os.date("%m/%d  %Y", time)
        end

        local size = self._file:size()
        local size_str
        if size then
          size_str = ya.readable_size(size)
        else
          local folder = cx.active:history(self._file.url)
          size_str = folder and tostring(#folder.files) or ""
        end

        return string.format("%s %s", size_str, time_str)
      end
    '';
    settings = {
      manager = {
        show_hidden = true;
        sort_by = "modified";
        sort_reverse = true;
        linemode = "size";
      };
    };
    theme = {
      mgr = {
        cwd = { fg = "yellow"; };
        marker_copied = { fg = "green"; bg = "green"; };
        marker_cut = { fg = "red"; bg = "red"; };
        marker_marked = { fg = "magenta"; bg = "magenta"; };
        marker_selected = { fg = "yellow"; bg = "yellow"; };
        count_copied = { fg = "black"; bg = "green"; };
        count_cut = { fg = "black"; bg = "red"; };
        count_selected = { fg = "black"; bg = "yellow"; };
        border_style = { fg = "darkgray"; };
      };
      tabs = {
        active = { fg = "black"; bg = "yellow"; bold = true; };
        inactive = { fg = "lightgray"; bg = "darkgray"; };
      };
      mode = {
        normal_main = { fg = "black"; bg = "green"; bold = true; };
        normal_alt = { fg = "green"; bg = "darkgray"; };
        select_main = { fg = "black"; bg = "red"; bold = true; };
        select_alt = { fg = "red"; bg = "darkgray"; };
        unset_main = { fg = "black"; bg = "magenta"; bold = true; };
        unset_alt = { fg = "magenta"; bg = "darkgray"; };
      };
      status = {
        perm_type = { fg = "green"; };
        perm_read = { fg = "yellow"; };
        perm_write = { fg = "red"; };
        perm_exec = { fg = "magenta"; };
        progress_normal = { fg = "green"; bg = "black"; };
        progress_error = { fg = "yellow"; bg = "red"; };
      };
      filetype.rules = [
        { mime = "image/*"; fg = "yellow"; }
        { mime = "{audio,video}/*"; fg = "magenta"; }
        { mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}"; fg = "red"; }
        { mime = "application/{pdf,doc,rtf}"; fg = "lightcyan"; }
        { name = "*"; is = "orphan"; fg = "red"; }
        { name = "*/"; fg = "green"; bold = true; }
      ];
    };
  };

  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
      };
      "rsyncnet zh5684.rsync.net" = {
        hostname = "zh5684.rsync.net";
        user = "zh5684";
        extraOptions = {
          BatchMode = "yes";
          StrictHostKeyChecking = "accept-new";
        };
      };
      "a55 phone" = {
        hostname = "100.65.181.6";
        port = 8022;
      };
      yapit-prod = {
        hostname = "100.87.244.58";
        user = "root";
      };
      "*" = {
        extraOptions = {
          AddKeysToAgent = "yes";
          IdentitiesOnly = "yes";
        };
        identityFile = [ "~/.ssh/id_ed25519" ];
      };
    };
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
    nodejs
    nvd
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
    wakatime-cli
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
