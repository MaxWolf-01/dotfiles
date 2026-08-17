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
{ ... }:
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
      ExecStart = "%h/applications/VibeTyper.AppImage --autostart";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
