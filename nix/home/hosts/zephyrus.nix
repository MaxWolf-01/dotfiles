{ ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  # This machine's capability record, read by a worker running locally and by
  # `worker-hosts` (bin/). No @TOOLCHAIN@ token: what is installed here is
  # spread across common.nix and its imports rather than one list, so the
  # record points at the config instead of enumerating it.
  home.file."HOST.md".source = ./zephyrus/HOST.md;

  # Every process here is max's, so the hub keeps its loopback port beside the
  # socket, and the laptop's browser and tools reach it with no network at all.
  containerHub = {
    host = "zephylux";
    loopback = true;
    tailnet = "https://zephylux.tail710178.ts.net:8377";
  };

  imports = [
    ../brave.nix
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
