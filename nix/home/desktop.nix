{ pkgs, config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.file.".config/vesktop/themes/custom.theme.css".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/desktop/discord/themes/custom.theme.css";

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
    icon = "${dotfiles}/desktop/icons/vesktop.svg";
    type = "Application";
    categories = [ "Network" "InstantMessaging" ];
    terminal = false;
  };
}
