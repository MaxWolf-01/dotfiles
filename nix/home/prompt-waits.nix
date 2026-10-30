# prompt-waits watch: a desktop notification the moment a command in a tmux
# pane waits for a password, PIN, passphrase or touch, and the directory of
# waiting prompts other programs read and write. What it watches and what the
# files hold: bin/prompt-waits --help.
#
# A service rather than a timer: a prompt has to be seen within a second or two.
# uv runs the PEP 723 script; libnotify's notify-send shows a notification and
# glib's gdbus withdraws it. ~/.nix-profile/bin for tmux, the guard in front of
# it included, and for ghostty, which a button opens when no client is attached.
{ config, pkgs, lib, ... }:
let
  home = config.home.homeDirectory;
  scriptPath = lib.makeBinPath (with pkgs; [ coreutils uv libnotify glib ]);
in
{
  systemd.user.services.prompt-waits = {
    Unit = {
      Description = "Notify when a command in a tmux pane waits for a password, PIN or touch";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      # Unbuffered, or the watcher's lines reach the journal only when a buffer fills.
      Environment = [ "PATH=${scriptPath}:${home}/.nix-profile/bin:/usr/bin:/bin" "PYTHONUNBUFFERED=1" ];
      ExecStart = "${home}/.dotfiles/bin/prompt-waits watch";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
