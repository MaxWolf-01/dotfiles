{ pkgs, config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  vesktop-wrapped = pkgs.writeShellScriptBin "vesktop" ''
    exec ${pkgs.vesktop}/bin/vesktop --disable-gpu "$@"
  '';
in
{
  home.file.".config/vesktop/themes/custom.theme.css".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/desktop/discord/themes/custom.theme.css";

  home.packages = with pkgs; [
    alacritty
    nemo
    vesktop-wrapped
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
