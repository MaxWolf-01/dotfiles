{ pkgs, config, lib, ... }:

let
  screenshotArea = "grim -g \"$(slurp)\" - | wl-copy";
  screenshotFull = "grim - | wl-copy";
in
{
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
        mfact = 0.65; # master takes 65% of screen
      };

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
        "waybar"
        "clipse -listen"
      ];

      # Keybindings
      "$mod" = "SUPER";

      bind = [
        # Apps
        "$mod, Return, exec, ghostty"
        "$mod, Space, exec, fuzzel"
        "$mod, E, exec, nautilus"
        "$mod, C, exec, firefox"
        "CTRL SHIFT, L, exec, hyprlock"

        # Window management
        "$mod, W, killactive,"
        "$mod, M, fullscreen, 1"
        "$mod SHIFT, M, fullscreen, 0"
        "$mod, F, togglefloating,"
        "$mod, P, pin,"

        # Master layout
        "$mod SHIFT, Return, layoutmsg, swapwithmaster" # swap focused ↔ master
        "$mod SHIFT, period, layoutmsg, addmaster"       # add a second master window
        "$mod SHIFT, comma, layoutmsg, removemaster"    # back to single master

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

        # Screenshots
        "$mod, S, exec, ${screenshotArea}"
        "$mod SHIFT, S, exec, ${screenshotFull}"

        # Clipboard history
        "CTRL ALT, H, exec, ghostty --class=clipse -e clipse"

        # Notifications
        "$mod, N, exec, makoctl dismiss"
        "$mod SHIFT, N, exec, makoctl dismiss --all"

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

  # Status bar
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "battery" "network" "pulseaudio" "tray" ];

      clock = {
        format = "{:%H:%M  %a %d %b}";
        tooltip-format = "{:%Y-%m-%d %H:%M}";
      };

      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "" "" "" "" "" ];
        states = {
          warning = 20;
          critical = 10;
        };
      };

      network = {
        format-wifi = " {signalStrength}%";
        format-ethernet = " {ifname}";
        format-disconnected = "⚠ disconnected";
        tooltip-format = "{essid} ({signalStrength}%)";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = " muted";
        format-icons.default = [ "" "" "" ];
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };
    }];

    style = ''
      * {
        font-family: "Hack Nerd Font";
        font-size: 13px;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.9);
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 8px;
        color: #6c7086;
      }

      #workspaces button.active {
        color: #cdd6f4;
        background-color: rgba(137, 180, 250, 0.2);
        border-bottom: 2px solid #89b4fa;
      }

      #clock, #battery, #network, #pulseaudio, #tray {
        padding: 0 10px;
      }

      #battery.warning {
        color: #fab387;
      }

      #battery.critical {
        color: #f38ba8;
      }
    '';
  };

  # Notifications
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      border-radius = 8;
      font = "Hack Nerd Font 11";
      background-color = "#1e1e2e";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
      border-size = 2;
    };
  };

  # Screen lock
  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true;
      background = [{
        path = "screenshot";
        blur_passes = 3;
        blur_size = 8;
      }];
      input-field = [{
        size = "200, 50";
        position = "0, -20";
        halign = "center";
        valign = "center";
        placeholder_text = "";
        fade_on_empty = true;
        outer_color = "rgba(137, 180, 250, 0.5)";
        inner_color = "rgba(30, 30, 46, 0.9)";
        font_color = "rgb(205, 214, 244)";
        check_color = "rgba(166, 227, 161, 0.5)";
        fail_color = "rgba(243, 139, 168, 0.5)";
      }];
      label = [{
        text = "$TIME";
        font_size = 64;
        font_family = "Hack Nerd Font";
        position = "0, 80";
        halign = "center";
        valign = "center";
        color = "rgba(205, 214, 244, 0.8)";
      }];
    };
  };

  # Idle management
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
          timeout = 300; # 5 min
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600; # 10 min
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800; # 30 min
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # App launcher
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "Hack Nerd Font:size=12";
        terminal = "ghostty -e";
        width = 40;
        lines = 12;
      };
      colors = {
        background = "1e1e2edd";
        text = "cdd6f4ff";
        selection = "89b4fa33";
        selection-text = "cdd6f4ff";
        border = "89b4faff";
      };
      border.width = 2;
      border.radius = 8;
    };
  };

  # Packages for Hyprland ecosystem
  home.packages = with pkgs; [
    clipse
    grim
    slurp
    wl-clipboard
    hyprpolkitagent
    playerctl
    brightnessctl
    networkmanagerapplet
    pavucontrol
  ];
}
