{ pkgs, config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  imports = [ ./firefox.nix ./ghostty.nix ./newsboat.nix ];

  home.file.".icons".source = ../../desktop/icons;

  programs.mpv = {
    enable = true;
    scripts = [ pkgs.mpvScripts.autoload ];
  };

  programs.vesktop = {
    enable = true;
    # Nix-pinned Vencord: no runtime self-download to go stale. Forgoes the
    # binary cache; vesktop builds from source on every bump.
    vencord.useSystem = true;
    # Vencord only loads userplugins that were in src/ at build time, so the
    # WakaTime plugin is spliced into the nixpkgs Vencord source. Its API key
    # is entered in the plugin's settings UI, never here.
    package = pkgs.vesktop.override {
      vencord = pkgs.vencord.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          mkdir -p src/userplugins
          cp -r ${pkgs.fetchFromGitHub {
            owner = "wakatime";
            repo = "vencord-wakatime";
            rev = "de045a0767dde6708d36f96387d389c814789fd4";
            hash = "sha256-k+UqTHCTTsSCb6Enl6gNUhIvb5+5OGsYa0jbJB2pL3U=";
          }} src/userplugins/vencord-wakatime
          chmod -R u+w src/userplugins/vencord-wakatime
          # Upstream sends a heartbeat every two minutes while Discord runs,
          # even minimized to tray. Only a focused window counts as activity.
          substituteInPlace src/userplugins/vencord-wakatime/index.tsx \
            --replace-fail 'if (!apiKey) return;' 'if (!apiKey || !document.hasFocus()) return;'
          # Vencord's content-security policy blocks renderer requests to hosts
          # outside its allowlist. A plugin registers its host from native.ts.
          cat > src/userplugins/vencord-wakatime/native.ts <<'EOF'
          import { ConnectSrc, CspPolicies } from "@main/csp";

          CspPolicies["api.wakatime.com"] = ConnectSrc;
          EOF
        '';
      });
    };
    settings = {
      discordBranch = "stable";
      minimizeToTray = true;
      arRPC = false;
      hardwareAcceleration = true;
      splashColor = "rgb(220, 220, 223)";
      splashBackground = "rgba(0, 0, 0, 0)";
      splashTheming = true;
      spellCheckLanguages = [ "en-US" "en" ];
    };
    vencord.themes."custom.theme" =
      config.lib.file.mkOutOfStoreSymlink "${dotfiles}/desktop/discord/themes/custom.theme.css";
  };

  home.packages = with pkgs; [
    dconf2nix
    loupe
    obsidian
    qdirstat
    signal-desktop
    slack
    sshfs
    chromium
    codex
    zathura
    texliveFull
  ];

  xdg.configFile."xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";

  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    genericName = "Discord Client";
    exec = "vesktop --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist %U";
    icon = toString ../../desktop/icons/vesktop.svg;
    type = "Application";
    categories = [ "Network" "InstantMessaging" ];
    terminal = false;
  };

  xdg.desktopEntries.nvim = {
    name = "Neovim";
    comment = "Edit files with Neovim";
    exec = "nvim %F";
    icon = toString ../../desktop/icons/nvim.svg;
    type = "Application";
    categories = [ "Utility" "Development" "TextEditor" ];
    mimeType = [ "text/markdown" "text/plain" ];
    terminal = true;
    settings.Path = "${config.home.homeDirectory}/Downloads";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = "nvim.desktop";
      "text/markdown" = "nvim.desktop";
      "text/x-python" = "nvim.desktop";
      "text/x-shellscript" = "nvim.desktop";
      "text/x-yaml" = "nvim.desktop";
      "text/x-toml" = "nvim.desktop";
      "application/json" = "nvim.desktop";
      "application/javascript" = "nvim.desktop";
      "application/x-shellscript" = "nvim.desktop";
      "audio/mpeg" = "org.gnome.Showtime.desktop";
      "video/mp4" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/mpeg" = "mpv.desktop";
      "x-scheme-handler/obsidian" = "obsidian.desktop";
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
