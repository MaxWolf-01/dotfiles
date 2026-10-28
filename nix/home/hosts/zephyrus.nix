{ config, pkgs, lib, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  home.sessionVariables.SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.local/secrets/age-key.txt";

  claudeToken.mode = "switch";

  # This machine's capability record, read by a worker running locally and by
  # `hosts` (bin/): its entry in ../machines.nix, and the hand-written
  # rest. No @TOOLCHAIN@ token: what is installed here is spread across
  # common.nix and its imports rather than one list, so the record points at
  # the config instead of enumerating it.
  home.file."HOST.md".text = config.machineRecords."max@zephylux" + builtins.readFile ./zephylux-max/HOST.md;

  # The slots dispatch's workers here take (`host-slots --help`). Every worker
  # here runs as max, so the slots are his own, in his runtime directory, which
  # these tmpfiles rules make at login and at each switch.
  home.packages = [
    (import ../../host-slots {
      inherit pkgs lib;
      slots = 4;
      dir = "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/host-slots";
    })
  ];
  systemd.user.tmpfiles.rules = [
    "d %t/host-slots 0700 - - -"
    "f %t/host-slots/lock 0600 - - -"
  ];

  # Every process here is max's, so the hub keeps its loopback port beside the
  # socket, and the laptop's browser and tools reach it with no network at all.
  containerHub = {
    host = "zephylux";
    loopback = true;
    tailnet = "https://zephylux.tail710178.ts.net:8377";
  };

  # The working backups here are the only ones that keep the worker users'
  # transcripts, so the laptop is the host that pulls them.
  sessionCopies.workerHosts = true;

  imports = [
    ../brave.nix
    ../claude-token.nix
    ../container-hub.nix
    ../desktop.nix
    ../display-layout.nix
    ../dotnet.nix
    ../gnome.nix
    ../greyline.nix
    ../proton-mail.nix
    ../timers.nix
    ../vibe-typer.nix
    ../wayland.nix
  ];
}
