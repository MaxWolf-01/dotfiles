{ pkgs, lib, config, ... }:
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
      enabled-extensions = [
        "tilingshell@ferrarodomenico.com"
        "GPaste@gnome-shell-extensions.gnome.org"
      ];
    };

    "org/gnome/desktop/default-applications/terminal" = {
      exec = "ghostty";
    };

    "org/gnome/desktop/input-sources" = {
      sources = [ (lib.hm.gvariant.mkTuple [ "xkb" "de+nodeadkeys" ]) ];
    };

    "org/gnome/desktop/session" = {
      idle-delay = 3600;
    };

    "org/gnome/desktop/screensaver" = {
      lock-enabled = true;
      lock-delay = 7200;
    };

    # Window management keybindings
    "org/gnome/desktop/wm/keybindings" = {
      minimize = [ "<Super>m" ];
      maximize = [ "<Shift><Super>m" ];
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      # Alt+Tab for windows, Super+Tab for apps
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
      switch-applications = [ "<Super>Tab" ];
      switch-applications-backward = [ "<Shift><Super>Tab" ];
      # Disable workspace move/switch defaults that conflict with tiling-shell
      cycle-windows = [];
      move-to-workspace-1 = [];
      move-to-workspace-down = [];
      move-to-workspace-up = [];
      move-to-workspace-last = [];
      switch-to-workspace-down = [];
      switch-to-workspace-up = [];
      switch-to-workspace-last = [];
    };

    # Media/shortcut keys
    "org/gnome/settings-daemon/plugins/media-keys" = {
      control-center = [ "<Super>s" ];
      search = [ "<Super>f" ];
      www = [ "<Super>c" ];
      screensaver = [ "<Super>l" ];
      terminal = [ "<Primary><Alt>t" ];
      # Custom keybindings list
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];
    };

    # Custom: file manager
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Open file manager";
      command = "nautilus";
      binding = "<Super>e";
    };

    # Custom: nightlight toggle
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name = "Toggle nightlight";
      command = "toggle_nightlight";
      binding = "<Primary><Super>n";
    };

    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "interactive";
    };

    # Tiling Shell extension
    "org/gnome/shell/extensions/tilingshell" = {
      enable-autotiling = true;
      enable-screen-edges-windows-suggestions = true;
      enable-snap-assistant-windows-suggestions = true;
      enable-tiling-system-windows-suggestions = true;
      enable-window-border = true;
      window-border-width = lib.hm.gvariant.mkUint32 10;
      top-edge-maximize = false;
      inner-gaps = lib.hm.gvariant.mkUint32 0;
      outer-gaps = lib.hm.gvariant.mkUint32 0;
      quarter-tiling-threshold = lib.hm.gvariant.mkUint32 40;
      # Keybindings
      cycle-layouts = [ "<Control><Super>p" ];
      move-window-center = [ "<Control><Super>c" ];
      span-window-all-tiles = [ "<Control><Super>f" ];
      span-window-down = [ "<Control><Super>Down" ];
      span-window-left = [ "<Control><Super>Left" ];
      span-window-right = [ "<Control><Super>Right" ];
      span-window-up = [ "<Control><Super>Up" ];
      focus-window-down = [ "<Control><Alt>j" ];
      focus-window-left = [ "<Control><Alt>h" ];
      focus-window-right = [ "<Control><Alt>l" ];
      focus-window-up = [ "<Control><Alt>k" ];
      focus-window-next = [];
      focus-window-prev = [];
      # Layouts
      selected-layouts = [ [ "Layout 3" "Layout 3" ] [ "Layout 3" "Layout 3" ] ];
      layouts-json = ''[{"id":"Layout 1","tiles":[{"x":0,"y":0,"width":0.22,"height":0.5,"groups":[1,2]},{"x":0,"y":0.5,"width":0.22,"height":0.5,"groups":[1,2]},{"x":0.22,"y":0,"width":0.56,"height":1,"groups":[2,3]},{"x":0.78,"y":0,"width":0.22,"height":0.5,"groups":[3,4]},{"x":0.78,"y":0.5,"width":0.22,"height":0.5,"groups":[3,4]}]},{"id":"Layout 2","tiles":[{"x":0,"y":0,"width":0.22,"height":1,"groups":[1]},{"x":0.22,"y":0,"width":0.56,"height":1,"groups":[1,2]},{"x":0.78,"y":0,"width":0.22,"height":1,"groups":[2]}]},{"id":"Layout 3","tiles":[{"x":0,"y":0,"width":0.33,"height":1,"groups":[1]},{"x":0.33,"y":0,"width":0.67,"height":1,"groups":[1]}]},{"id":"Layout 4","tiles":[{"x":0,"y":0,"width":0.67,"height":1,"groups":[1]},{"x":0.67,"y":0,"width":0.33,"height":1,"groups":[1]}]},{"id":"13597114","tiles":[{"x":0,"y":0,"width":0.36770833333333336,"height":0.5,"groups":[1,2]},{"x":0.36770833333333336,"y":0,"width":0.6322916666666674,"height":1,"groups":[1]},{"x":0,"y":0.5,"width":0.36770833333333336,"height":0.5,"groups":[2,1]}]},{"id":"13201446","tiles":[{"x":0,"y":0,"width":0.29069767441860467,"height":1,"groups":[1]},{"x":0.29069767441860467,"y":0,"width":0.5087209302325582,"height":1,"groups":[2,1]},{"x":0.7994186046511628,"y":0,"width":0.20058139534883718,"height":1,"groups":[2]}]},{"id":"13300092","tiles":[{"x":0,"y":0,"width":0.5,"height":1,"groups":[1]},{"x":0.5,"y":0,"width":0.4999999999999982,"height":1,"groups":[1]}]}]'';
      # Settings tiling-shell overrides in GNOME
      overridden-settings = ''{"org.gnome.mutter.keybindings":{"toggle-tiled-right":"['<Super>Right']","toggle-tiled-left":"['<Super>Left']"},"org.gnome.desktop.wm.keybindings":{"maximize":"['<Super>Up']","unmaximize":"['<Super>Down', '<Alt>F5']"},"org.gnome.mutter":{"edge-tiling":"true"}}'';
    };
  };
}
