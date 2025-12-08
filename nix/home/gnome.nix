{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    gnomeExtensions.tiling-shell
  ];

  # GNOME doesn't see ~/.nix-profile in XDG_DATA_DIRS, so symlink extensions here
  xdg.dataFile."gnome-shell/extensions/tilingshell@ferrarodomenico.com".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.nix-profile/share/gnome-shell/extensions/tilingshell@ferrarodomenico.com";

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
