{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnomeExtensions.tiling-shell
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [ "tilingshell@ferrarodomenico.com" ];
    };

    # Screen timeout: 1 hour before blanking
    "org/gnome/desktop/session" = {
      idle-delay = 3600;  # seconds (1 hour)
    };

    # Lock screen: enabled, but 2 hour delay after screen blanks
    "org/gnome/desktop/screensaver" = {
      lock-enabled = true;
      lock-delay = 7200;  # seconds (2 hours) after screen blanks
    };
  };
}
