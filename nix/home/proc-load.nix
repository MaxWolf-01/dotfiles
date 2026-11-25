# proc-load record: every process's CPU and memory, one line a minute, so a busy
# stretch can be traced to its process (and, for Firefox, its tabs) afterwards
# with `proc-load top`. What it records and where: bin/proc-load --help.
#
# The Firefox half is desktop/firefox-tab-map.js, which firefox.nix appends to
# Firefox's autoconfig; it writes only into a directory this service creates.
{ config, pkgs, lib, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  systemd.user.services.proc-load = {
    Unit = {
      Description = "Record every process's CPU and memory, one line a minute";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dotfiles}/bin/proc-load record";
      Environment = [ "PATH=${lib.makeBinPath (with pkgs; [ coreutils uv ])}" ];
      Restart = "on-failure";
      RestartSec = 30;
      Nice = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
