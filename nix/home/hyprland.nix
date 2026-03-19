{ pkgs, config, lib, ... }:

let
  screenshotArea = pkgs.writeShellScript "screenshot-area" ''
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    f="$dir/$(date +%Y%m%d_%H%M%S).png"
    grim -g "$(slurp)" "$f" && wl-copy < "$f" && notify-send -t 2000 "Screenshot" "$f"
  '';
  screenshotFull = pkgs.writeShellScript "screenshot-full" ''
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    f="$dir/$(date +%Y%m%d_%H%M%S).png"
    grim "$f" && wl-copy < "$f" && notify-send -t 2000 "Screenshot" "$f"
  '';
  brightnessCycle = pkgs.writeShellScript "brightness-cycle" ''
    current=$(brightnessctl get)
    max=$(brightnessctl max)
    pct=$((current * 100 / max))
    if [ "$pct" -lt 17 ]; then
      brightnessctl set 33%
    elif [ "$pct" -lt 50 ]; then
      brightnessctl set 66%
    elif [ "$pct" -lt 83 ]; then
      brightnessctl set 100%
    else
      brightnessctl set 10%
    fi
  '';
  powerProfileCycle = pkgs.writeShellScript "power-profile-cycle" ''
    current=$(powerprofilesctl get)
    case "$current" in
      performance) powerprofilesctl set balanced ;;
      balanced)    powerprofilesctl set power-saver ;;
      *)           powerprofilesctl set performance ;;
    esac
  '';
  hyprsunsetToggle = pkgs.writeShellScript "hyprsunset-toggle" ''
    if pgrep -x hyprsunset > /dev/null; then
      pkill -x hyprsunset
    else
      hyprsunset -t 3500 &
    fi
  '';
in
{
  # Catppuccin theming
  catppuccin = {
    enable = true;
    flavor = "mocha";
    yazi.enable = false; # yazi has its own theme config in common.nix
  };

  # ── Hyprland ────────────────────────────────────────────────

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use system package from NixOS module
    systemd.enable = false; # MUST be false with UWSM

    settings = {
      general = {
        layout = "master";
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(89b4faff) rgba(cba6f7ff) 45deg";
        "col.inactive_border" = "rgba(585b70aa)";
        allow_tearing = false;
      };

      master = {
        new_status = "slave";
        mfact = 0.65;
      };

      monitor = [ ",preferred,auto,1" ];

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

      cursor.no_hardware_cursors = 2;

      env = [
        "NIXOS_OZONE_WL,1"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "QT_QPA_PLATFORM,wayland"
        "GDK_BACKEND,wayland,x11"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
      ];

      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "hyprpaper"
        "nm-applet"
        "blueman-applet"
        "clipse -listen"
      ];

      "$mod" = "SUPER";

      bind = [
        # Apps
        "$mod, Return, exec, ghostty"
        "$mod, Space, exec, fuzzel"
        "$mod, E, exec, ghostty -e yazi"
        "$mod, C, exec, firefox"

        # Session
        "$mod SHIFT, Q, exit,"
        "CTRL SHIFT, L, exec, pidof hyprlock || hyprlock"
        "$mod, P, exec, pgrep wlogout && pkill wlogout || wlogout"

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

        # Screenshots (kill previous slurp if running to prevent stacking)
        "$mod, S, exec, pkill slurp; ${screenshotArea}"
        ", Print, exec, ${screenshotFull}"
        "$mod SHIFT, S, exec, ${screenshotFull}"

        # Clipboard history
        "CTRL ALT, H, exec, ghostty --class=clipse -e clipse"

        # Notifications
        "$mod, N, exec, makoctl dismiss"
        "$mod SHIFT, N, exec, makoctl dismiss --all"

        # Night light
        "CTRL $mod, N, exec, ${hyprsunsetToggle}"

        # Cycle windows
        "ALT, Tab, cyclenext,"
        "ALT SHIFT, Tab, cyclenext, prev"

        # Resize master area
        "$mod, comma, layoutmsg, mfact -0.05"
        "$mod, period, layoutmsg, mfact +0.05"
      ];

      # Media/hardware keys (repeatable)
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl -n set 5%-"
      ];

      # Media/hardware keys (non-repeating)
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      windowrule = [
        "float on, match:class clipse"
        "size 700 500, match:class clipse"
        "center on, match:class clipse"

        "float on, match:title Picture-in-picture"
        "pin on, match:title Picture-in-picture"
        "float on, match:title Picture-in-Picture"
        "pin on, match:title Picture-in-Picture"

        "float on, match:class Xdg-desktop-portal-gtk"
        "center on, match:class Xdg-desktop-portal-gtk"
      ];
    };
  };

  # ── Waybar ──────────────────────────────────────────────────

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    systemd.target = "graphical-session.target";

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 4;

      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "power-profiles-daemon"
        "bluetooth"
        "network"
        "pulseaudio"
        "backlight"
        "battery"
        "custom/power"
      ];

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
        sort-by-number = true;
      };

      clock = {
        format = "{:%H:%M  %a, %b %d}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "" "" "" "" "" ];
        format-charging = " {capacity}%";
        states = {
          warning = 20;
          critical = 10;
        };
      };

      network = {
        format-wifi = " {essid}";
        format-ethernet = " {ifname}";
        format-disconnected = "󰖪 ";
        tooltip-format = "{ipaddr}/{cidr}";
        on-click = "nm-connection-editor";
      };

      bluetooth = {
        format = "";
        format-connected = " {device_alias}";
        format-disabled = "󰂲";
        on-click = "blueman-manager";
        tooltip-format = "{status}";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 ";
        format-icons.default = [ "" "" "" ];
        on-click = "pavucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      backlight = {
        format = "󰃟 {percent}%";
        on-scroll-up = "brightnessctl set 5%+";
        on-scroll-down = "brightnessctl set 5%-";
        on-click = "${brightnessCycle}";
      };

      "power-profiles-daemon" = {
        format = "{icon}";
        format-icons = {
          default = "";
          performance = "";
          balanced = "";
          power-saver = "";
        };
        tooltip-format = "Profile: {profile}";
        on-click = "${powerProfileCycle}";
      };

      tray = {
        spacing = 10;
      };

      "custom/power" = {
        format = "⏻";
        on-click = "wlogout";
        tooltip = false;
      };

    };

    style = ''
      * {
        font-family: "JetBrains Mono", "Symbols Nerd Font";
        font-size: 13px;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.9);
        color: @text;
      }

      #workspaces button {
        padding: 0 8px;
        color: @overlay1;
        border-bottom: 2px solid transparent;
      }

      #workspaces button.active {
        color: @blue;
        border-bottom: 2px solid @blue;
      }

      #workspaces button.urgent {
        color: @red;
      }

      #clock {
        font-weight: bold;
      }

      #battery.warning {
        color: @yellow;
      }

      #battery.critical {
        color: @red;
      }

      #network.disconnected {
        color: @overlay0;
      }

      #pulseaudio.muted {
        color: @overlay0;
      }

      #tray,
      #battery,
      #network,
      #bluetooth,
      #pulseaudio,
      #backlight,
      #power-profiles-daemon,
      #custom-power {
        padding: 0 8px;
      }

      #custom-power {
        color: @red;
      }
    '';
  };

  # ── Mako (notifications) ────────────────────────────────────

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 8000;
      anchor = "top-right";
      border-radius = 8;
      border-size = 2;
      padding = "10";
      margin = "10";
      width = 350;
      max-visible = 3;
    };
  };

  # ── Hyprlock (lock screen) ──────────────────────────────────

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 5;
      };

      background = [{
        path = "screenshot";
        blur_passes = 3;
        blur_size = 8;
      }];

      input-field = [{
        size = "250, 50";
        outline_thickness = 2;
        dots_center = true;
        fade_on_empty = true;
        placeholder_text = "";
        position = "0, -20";
        halign = "center";
        valign = "center";
      }];

      label = [{
        text = "$TIME";
        font_size = 64;
        position = "0, 100";
        halign = "center";
        valign = "center";
      }];
    };
  };

  # ── Hypridle (idle management) ──────────────────────────────

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 900; # 15 min — screen off
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 3600; # 1 hour — lock
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 3900; # 1h05 — suspend (only on battery, but hypridle doesn't know power state — logind handles AC)
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # ── Fuzzel (app launcher) ───────────────────────────────────

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrains Mono:size=12";
        terminal = "ghostty -e";
        layer = "overlay";
        width = 40;
        lines = 12;
      };
    };
  };

  # ── Wlogout (power menu) ────────────────────────────────────

  programs.wlogout = {
    enable = true;
    layout = [
      { label = "lock";      action = "hyprlock";                  text = "Lock";      keybind = "l"; }
      { label = "suspend";   action = "systemctl suspend";         text = "Suspend";   keybind = "s"; }
      { label = "hibernate"; action = "systemctl hibernate";       text = "Hibernate"; keybind = "h"; }
      { label = "reboot";    action = "systemctl reboot";          text = "Reboot";    keybind = "r"; }
      { label = "shutdown";  action = "systemctl poweroff";        text = "Shutdown";  keybind = "p"; }
      { label = "logout";    action = "hyprctl dispatch exit";     text = "Logout";    keybind = "e"; }
    ];
  };

  # ── Hyprpaper (wallpaper) ───────────────────────────────────

  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "off";
      splash = false;
      preload = [ "~/Pictures/Wallpapers/wallpaper.jpg" ];
      wallpaper = [ ",~/Pictures/Wallpapers/wallpaper.jpg" ];
    };
  };

  # ── MIME defaults ───────────────────────────────────────────

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

  # ── Qt theming (catppuccin handles this via kvantum) ─────────

  qt = {
    enable = true;
    style.name = "kvantum";
  };

  # ── Packages ────────────────────────────────────────────────

  home.packages = with pkgs; [
    clipse
    grim
    libnotify
    gpu-screen-recorder
    hyprsunset
    loupe
    nwg-displays
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
