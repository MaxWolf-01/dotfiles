{ pkgs, config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  # TODO: make pure once theme works on Ubuntu 26
  home.file.".config/vesktop/themes/custom.theme.css".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/desktop/discord/themes/custom.theme.css";

  home.packages = with pkgs; [
    alacritty
    ast-grep
    fastmod
    ffmpeg
    gedit # TODO(ubuntu-26): remove, workaround for GTK conflicts
    nautilus # TODO(ubuntu-26): remove, workaround for GTK conflicts
    nemo # TODO(ubuntu-26): remove, workaround for GTK conflicts
    signal-desktop
    vesktop
    yaru-theme # TODO(ubuntu-26): remove, workaround for GTK conflicts
    yt-dlp
  ];

  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    genericName = "Discord Client";
    exec = "vesktop %U";
    icon = toString ../../desktop/icons/vesktop.svg;
    type = "Application";
    categories = [ "Network" "InstantMessaging" ];
    terminal = false;
  };
}
