# greyline — live world-time desktop wallpaper (github:cothinking-dev/greyline).
# Renders a PNG once a minute (systemd user timer) and sets it as the GNOME
# wallpaper. No daemon; the renderer runs and exits each tick.
#
# zephyrus is Ubuntu GNOME (Wayland) with Home Manager standalone, so this
# overrides the module's sway-oriented defaults:
#   - backend "command": GNOME sets its own wallpaper via gsettings.
#   - target graphical-session.target: the generic GNOME session target.
#   - /usr/bin/gsettings (absolute): Ubuntu's binary knows the GNOME schemas;
#     a nix-store gsettings would not find org.gnome.desktop.background.
#   - empty-then-set: greyline re-renders to the same path each tick, so we
#     clear picture-uri first to defeat GNOME's same-URI cache; both light and
#     dark keys are set so it shows in either colour scheme.
#   - extraPackages = []: the default pulls in sway, which we don't need.
#
# `command` goes in settings (config.toml), NOT services.greyline.command: the
# module fuses `--font-family "<value>"` with `--command` (a stripped leading
# space in its ExecStart) whenever the family has a space, producing a malformed
# unit. Reading the command from config avoids the broken CLI concatenation.
{ ... }:
{
  services.greyline = {
    enable = true;
    backend = "command";
    target = "graphical-session.target";
    extraPackages = [ ];

    settings = {
      command =
        ''/usr/bin/gsettings set org.gnome.desktop.background picture-uri "" ''
        + ''&& /usr/bin/gsettings set org.gnome.desktop.background picture-uri "file://{path}" ''
        + ''&& /usr/bin/gsettings set org.gnome.desktop.background picture-uri-dark "file://{path}"'';
      map_style = "vector";
      theme = "dark";
      format = "24h";
      logo = false;
      resolution = "3840x2400"; # native panel; the service can't rely on xrandr
      twilight = {
        bands = true;
        darkness = "subtle";
      };
      home = {
        tz = "Europe/Vienna";
        column_highlight = true;
      };
      city = [
        { name = "Vienna"; lat = 48.21; lon = 16.37; tz = "Europe/Vienna"; }
        { name = "San Francisco"; lat = 37.77; lon = -122.42; tz = "America/Los_Angeles"; }
        { name = "New York"; lat = 40.71; lon = -74.01; tz = "America/New_York"; }
        { name = "London"; lat = 51.51; lon = -0.13; tz = "Europe/London"; }
        { name = "Moscow"; lat = 55.76; lon = 37.62; tz = "Europe/Moscow"; }
        { name = "Tokyo"; lat = 35.68; lon = 139.69; tz = "Asia/Tokyo"; }
        { name = "Sydney"; lat = -33.87; lon = 151.21; tz = "Australia/Sydney"; }
      ];
    };
  };
}
