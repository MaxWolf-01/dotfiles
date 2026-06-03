{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    # TODO make handy work properly else remove
    # NOT wtype: Mutter (GNOME) refuses to implement zwp_virtual_keyboard_v1,
    # so wtype always fails on GNOME. Handy prefers wtype if present and won't
    # fall through to dotool, so having wtype installed actively breaks Handy.
    dotool  # uinput-based input injection; bypasses the compositor (Handy fallback)
  ];
}
