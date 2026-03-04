{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "UbuntuSansMono Nerd Font Mono";
      package = pkgs.nerd-fonts.ubuntu-sans;
    };
    settings = {
      confirm_os_window_close = 0;
    };
    keybindings = {
      "cmd+alt+plus" = "change_font_size current +1.0";
      "cmd+alt+minus" = "change_font_size current -1.0";
      "shift+enter" = "send_text all \\e\\r";
    };
  };
}
