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
# NO_CLEANUP: every copy of one AppImage version unpacks into the same directory,
# named after the file's hash, and without this flag deletes it on exit. A second
# launch while the app runs would take the running app's files with it. The
# trees stay in /var/tmp, where systemd-tmpfiles deletes files unread for 30
# days (Ubuntu's default): whole trees of replaced versions, and in the current
# one the files the app never loaded. The next launch unpacks what is missing.
# A running app that needs such a file later, e.g. for the software GPU
# fallback, fails; under the unit, Restart=on-failure brings it back.
#
# TMPDIR: /tmp is tmpfs here, so the default would hold the unpacked tree in RAM.
#
# Startup lives here, not in ~/.config/autostart: the app rewrites its own
# .desktop file whenever its "start on login" setting changes, which would drop
# the environment above. Leave that setting off in the app. The app grid entry
# runs the AppImage with the same environment; launched while the app runs, that
# copy only brings the running app's window forward and quits.
#
# X-SwitchMethod: the app moves itself out of the unit's cgroup into a scope of
# its own, so restarting the unit on a switch kills only its helper processes,
# and the app dies without them. A changed unit applies at the next start.
{ config, lib, ... }:
let
  appImage = "${config.home.homeDirectory}/applications/VibeTyper.AppImage";
  environment = [
    "APPIMAGE_EXTRACT_AND_RUN=1"
    "NO_CLEANUP=1"
    "TMPDIR=/var/tmp"
  ];
in
{
  systemd.user.services.vibe-typer = {
    Unit = {
      Description = "VibeTyper dictation";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Environment = environment;
      ExecStart = "${appImage} --autostart";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.desktopEntries.vibe-typer = {
    name = "Vibe Typer";
    # Copied out of the AppImage's own icon theme, whose extracted tree is named
    # after the version's hash and deleted after 30 days unread.
    icon = toString ../../desktop/icons/vibe-typer.png;
    exec = "env ${lib.concatStringsSep " " environment} ${appImage}";
    type = "Application";
    categories = [ "Utility" ];
    terminal = false;
  };
}
