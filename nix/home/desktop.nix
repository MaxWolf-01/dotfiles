{ pkgs, config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.file.".config/vesktop/themes/custom.theme.css".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/desktop/discord/themes/custom.theme.css";

  imports = [ ./firefox.nix ./ghostty.nix ./newsboat.nix ];

  home.file.".icons".source = ../../desktop/icons;

  home.file.".config/newsboat/urls".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/newsboat/urls";

  home.packages = with pkgs; [
    dconf2nix
    loupe
    obsidian
    qdirstat
    signal-desktop
    vesktop
    zathura
  ];

  xdg.configFile."xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";

  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    genericName = "Discord Client";
    exec = "vesktop %U";
    icon = toString ../../desktop/icons/vesktop.svg;
    type = "Application";
    categories = [ "Network" "InstantMessaging" ];
    terminal = false;
  };

  xdg.desktopEntries.nvim = {
    name = "Neovim";
    comment = "Edit files with Neovim";
    exec = "nvim %F";
    icon = toString ../../desktop/icons/nvim.svg;
    type = "Application";
    categories = [ "Utility" "Development" "TextEditor" ];
    mimeType = [ "text/markdown" "text/plain" ];
    terminal = true;
    settings.Path = "${config.home.homeDirectory}/Downloads";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = "nvim.desktop";
      "text/markdown" = "nvim.desktop";
      "text/x-python" = "nvim.desktop";
      "text/x-shellscript" = "nvim.desktop";
      "text/x-yaml" = "nvim.desktop";
      "text/x-toml" = "nvim.desktop";
      "application/json" = "nvim.desktop";
      "application/javascript" = "nvim.desktop";
      "application/x-shellscript" = "nvim.desktop";
      "x-scheme-handler/obsidian" = "obsidian.desktop";
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
