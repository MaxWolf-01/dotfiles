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
    nemo
    signal-desktop
    vesktop
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
