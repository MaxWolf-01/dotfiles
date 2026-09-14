{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";
  home.stateVersion = "26.05";

  programs.brave = {
    enable = true;
    # External-extension manifests: Brave installs these into every profile.
    extensions = [
      { id = "jnbbnacmeggbgdjgaoojpmhdlkkpblgi"; } # WakaTime
    ];
    # BraveCommander (Quick commands) owns Ctrl+Space, VibeTyper's dictation key.
    # Chromium reads only the last --disable-features, and the nixpkgs wrapper
    # passes its own first: its list is repeated here, or this flag erases it.
    # After a flake update, compare with the wrapper's first match in
    # `grep -o -- '--disable-features=[^ ]*' $(which brave)`.
    commandLineArgs = [
      "--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder,BraveCommander"
    ];
  };

  # This machine's capability record, read by a worker running locally and by
  # `worker-hosts` (bin/). No @TOOLCHAIN@ token: what is installed here is
  # spread across common.nix and its imports rather than one list, so the
  # record points at the config instead of enumerating it.
  home.file."HOST.md".source = ./zephyrus/HOST.md;

  imports = [
    ../desktop.nix
    ../display-layout.nix
    ../dotnet.nix
    ../gnome.nix
    ../greyline.nix
    ../timers.nix
    ../vibe-typer.nix
    ../wayland.nix
  ];
}
