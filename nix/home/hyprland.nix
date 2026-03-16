{ pkgs, config, lib, inputs, ... }:

let
  screenshotArea = "grim -g \"$(slurp)\" - | wl-copy";
  screenshotFull = "grim - | wl-copy";
  noctalia = cmd: "noctalia-shell ipc call ${cmd}";
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use system package from NixOS module
    systemd.enable = false; # MUST be false with UWSM

    settings = {
      # Master layout: one big window left, rest stack right
      general = {
        layout = "master";
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(88c0d0ff) rgba(81a1c1ff) 45deg";
        "col.inactive_border" = "rgba(4c566aaa)";
        allow_tearing = false;
      };

      master = {
        new_status = "slave";
        mfact = 0.65;
      };

      monitor = [ ",preferred,auto,1" ]; # force scale 1x (auto-detect picks 1.5x on 1080p 15.6")

      input = {
        kb_layout = "de";
        kb_variant = "nodeadkeys";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
        sensitivity = 0;
        repeat_rate = 25;
        repeat_delay = 400;
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
      };

      animations = {
        enabled = true;
        bezier = [ "ease, 0.25, 0.1, 0.25, 1.0" ];
        animation = [
          "windows, 1, 4, ease"
          "windowsOut, 1, 4, ease, popin 80%"
          "border, 1, 6, ease"
          "fade, 1, 4, ease"
          "workspaces, 1, 4, ease"
        ];
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_guiutils_check = true;
      };

      cursor.no_hardware_cursors = 2; # auto, recommended for NVIDIA

      # Environment
      env = [
        "NIXOS_OZONE_WL,1"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "QT_QPA_PLATFORM,wayland"
        "GDK_BACKEND,wayland,x11"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
      ];

      # Autostart
      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "noctalia-shell"
        "clipse -listen"
      ];

      # Keybindings
      "$mod" = "SUPER";

      bind = [
        # Apps
        "$mod, Return, exec, ghostty"
        "$mod, Space, exec, ${noctalia "launcher toggle"}"
        "$mod, E, exec, ghostty -e yazi"
        "$mod, C, exec, firefox"

        # Session
        "$mod SHIFT, Q, exit,"
        "CTRL SHIFT, L, exec, ${noctalia "lockScreen lock"}"
        "$mod, P, exec, ${noctalia "sessionMenu toggle"}"

        # Window management
        "$mod, W, killactive,"
        "$mod, M, fullscreen, 1"
        "$mod SHIFT, M, fullscreen, 0"
        "$mod, F, togglefloating,"

        # Master layout
        "$mod SHIFT, Return, layoutmsg, swapwithmaster"
        "$mod SHIFT, period, layoutmsg, addmaster"
        "$mod SHIFT, comma, layoutmsg, removemaster"

        # Focus (vim keys)
        "$mod, H, movefocus, l"
        "$mod, J, movefocus, d"
        "$mod, K, movefocus, u"
        "$mod, L, movefocus, r"

        # Move windows
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, J, movewindow, d"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, L, movewindow, r"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # Screenshots (fallback — also via Noctalia screenshot plugin)
        "$mod, S, exec, ${screenshotArea}"
        "$mod SHIFT, S, exec, ${screenshotFull}"

        # Clipboard history
        "CTRL ALT, H, exec, ghostty --class=clipse -e clipse"

        # Notifications + night light
        "$mod, N, exec, ${noctalia "notifications dismiss"}"
        "$mod SHIFT, N, exec, ${noctalia "nightLight toggle"}"

        # Cycle windows
        "ALT, Tab, cyclenext,"
        "ALT SHIFT, Tab, cyclenext, prev"

        # Resize master area
        "$mod, comma, layoutmsg, mfact -0.05"
        "$mod, period, layoutmsg, mfact +0.05"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Window rules
      windowrule = [
        # Clipboard popup
        "float on, match:class clipse"
        "size 700 500, match:class clipse"
        "center on, match:class clipse"

        # Picture-in-picture
        "float on, match:title Picture-in-picture"
        "pin on, match:title Picture-in-picture"
        "float on, match:title Picture-in-Picture"
        "pin on, match:title Picture-in-Picture"

        # File picker
        "float on, match:class Xdg-desktop-portal-gtk"
        "center on, match:class Xdg-desktop-portal-gtk"
      ];
    };
  };

  # Noctalia Shell
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = false; # started via exec-once

    settings = {
      settingsVersion = 59;

      bar = {
        position = "bottom";
        density = "compact";
        showCapsule = false;
        widgetSpacing = 0;
        contentPadding = 0;
        fontScale = 0.95;

        widgets = {
          left = [
            {
              id = "SystemMonitor";
              compactMode = true;
              showCpuTemp = true;
              showCpuUsage = false;
              showMemoryUsage = true;
              showDiskAvailable = true;
              useMonospaceFont = true;
              usePadding = false;
            }
            { id = "plugin:privacy-indicator"; }
            {
              id = "plugin:catwalk";
              defaultSettings = { minimumThreshold = 10; hideBackground = false; };
            }
          ];
          center = [
            {
              id = "Clock";
              formatHorizontal = "HH:mm ddd, MMM dd";
              tooltipFormat = "HH:mm ddd, MMM dd";
            }
            {
              id = "Workspace";
              characterCount = 2;
              showLabelsOnlyWhenOccupied = true;
              labelMode = "index";
              fontWeight = "bold";
              showBadge = true;
            }
          ];
          right = [
            { id = "Tray"; drawerEnabled = true; }
            { id = "Volume"; displayMode = "onhover"; middleClickCommand = "pavucontrol"; }
            { id = "Brightness"; displayMode = "onhover"; }
            { id = "plugin:screen-recorder"; }
            { id = "plugin:screenshot"; }
            { id = "plugin:tailscale"; }
            { id = "plugin:network-indicator"; }
            { id = "plugin:noctalia-supergfxctl"; }
            {
              id = "Battery";
              displayMode = "graphic-clean";
              hideIfNotDetected = true;
              showPowerProfiles = false;
            }
            { id = "NotificationHistory"; showUnreadBadge = true; }
            { id = "ControlCenter"; icon = "noctalia"; }
          ];
        };
      };

      general = {
        telemetryEnabled = false;
        lockOnSuspend = true;
      };

      ui = {
        fontDefaultScale = 0.9;
        tooltipsEnabled = false;
      };

      location = {
        name = "Vienna";
        weatherEnabled = false;
        hideWeatherTimezone = true;
        hideWeatherCityName = true;
      };

      calendar.cards = [
        { enabled = true; id = "calendar-header-card"; }
        { enabled = true; id = "calendar-month-card"; }
        { enabled = false; id = "weather-card"; }
      ];

      wallpaper = {
        overviewEnabled = true;
        automationEnabled = true;
      };

      appLauncher.enableClipboardHistory = false; # using clipse

      controlCenter.cards = [
        { enabled = true; id = "profile-card"; }
        { enabled = true; id = "shortcuts-card"; }
        { enabled = true; id = "audio-card"; }
        { enabled = false; id = "brightness-card"; }
        { enabled = false; id = "weather-card"; }
        { enabled = false; id = "media-sysmon-card"; }
      ];

      colorSchemes = {
        predefinedScheme = "Catppuccin";
        darkMode = true;
      };

      nightLight = {
        enabled = true;
        forced = true;
        autoSchedule = true;
        nightTemp = "3553";
      };

      dock.enabled = false;

      idle = {
        enabled = true;
        screenOffTimeout = 600;
        lockTimeout = 660;
        suspendTimeout = 1800;
      };
    };

    plugins = {
      sources = [
        {
          enabled = true;
          name = "Official Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
      ];
      states = {
        catwalk = { enabled = true; sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins"; };
        network-indicator = { enabled = true; sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins"; };
        privacy-indicator = { enabled = true; sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins"; };
        tailscale = { enabled = true; sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins"; };
        screenshot = { enabled = true; sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins"; };
        screen-recorder = { enabled = true; sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins"; };
        noctalia-supergfxctl = { enabled = true; sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins"; };
      };
      version = 2;
    };

    pluginSettings = {
      catwalk = { minimumThreshold = 10; hideBackground = false; };
      tailscale.compactMode = true;
    };
  };

  # MIME defaults
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "application/pdf" = "org.pwmt.zathura.desktop";
        "image/png" = "org.gnome.Loupe.desktop";
        "image/jpeg" = "org.gnome.Loupe.desktop";
        "image/webp" = "org.gnome.Loupe.desktop";
        "image/gif" = "org.gnome.Loupe.desktop";
        "video/mp4" = "org.gnome.Showtime.desktop";
        "video/webm" = "org.gnome.Showtime.desktop";
        "video/x-matroska" = "org.gnome.Showtime.desktop";
        "inode/directory" = "yazi.desktop";
      };
    };
  };

  # Qt theming
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  # Packages
  home.packages = with pkgs; [
    clipse
    grim
    gpu-screen-recorder
    showtime
    slurp
    wl-clipboard
    hyprpolkitagent
    playerctl
    brightnessctl
    networkmanagerapplet
    pavucontrol
  ];
}
