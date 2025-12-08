{ pkgs, config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.file.".config/vesktop/themes/custom.theme.css".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/desktop/discord/themes/custom.theme.css";

  home.packages = with pkgs; [
    nemo
    nerd-fonts.ubuntu-sans
    vesktop
  ];
}
