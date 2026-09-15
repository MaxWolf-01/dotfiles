# VibeTyper — dictation app, shipped as an AppImage, self-updating.
#
# APPIMAGE_EXTRACT_AND_RUN makes the AppImage runtime unpack its squashfs payload
# to a directory instead of mounting it over FUSE. The mount is why suspend used
# to fail: an Electron app runs its code straight off that mount, the kernel
# freezes processes in an arbitrary order before sleep, and a thread that page
# faults on its own code after the FUSE server is frozen waits for a reply that
# cannot come. The kernel gives up on the whole suspend after 20 seconds. This
# blocked roughly half of all suspend attempts, on six days out of eleven.
# The flag is undocumented in --appimage-help but present in the runtime.
#
# TMPDIR: /tmp is tmpfs here, so the default would hold the unpacked tree in RAM
# for as long as the app runs.
#
# Startup lives here, not in ~/.config/autostart: the app rewrites its own
# .desktop file whenever its "start on login" setting changes, which would drop
# the environment above. Leave that setting off in the app.
#
# GNOME's "Vibe Typer" entry, also the vibetyper:// handler, starts this unit
# rather than the AppImage, so a launch from the app grid gets the environment
# too. When the unit already runs, the entry launches the AppImage plainly: that
# copy only hands its arguments to the running one and quits. An extracted copy
# would share the running one's directory, named after the AppImage's hash, and
# delete it on exit.
{ config, pkgs, ... }:
let
  appImage = "${config.home.homeDirectory}/applications/VibeTyper.AppImage";
  open = pkgs.writeShellScript "vibe-typer-open" ''
    if systemctl --user is-active --quiet vibe-typer.service; then
      exec ${appImage} "$@"
    fi
    exec systemctl --user start vibe-typer.service
  '';
in
{
  systemd.user.services.vibe-typer = {
    Unit = {
      Description = "VibeTyper dictation";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Environment = [
        "APPIMAGE_EXTRACT_AND_RUN=1"
        "TMPDIR=/var/tmp"
      ];
      ExecStart = "${appImage} --autostart";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Not xdg.desktopEntries: that writes into the profile, and a same-named entry
  # in ~/.local/share/applications outranks it. force replaces such a file.
  xdg.dataFile."applications/com.vibetyper.app.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Vibe Typer
      Exec=${open} %u
      Terminal=false
      Categories=Utility;AudioVideo;
      MimeType=x-scheme-handler/vibetyper;
    '';
  };
}
