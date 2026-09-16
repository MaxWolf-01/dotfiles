{ lib, pkgs, ... }:
{
  programs.brave = {
    enable = true;
    # External-extension manifests: Brave installs these into every profile.
    extensions = [
      { id = "jnbbnacmeggbgdjgaoojpmhdlkkpblgi"; } # WakaTime
    ];
    # BraveCommander (Quick commands) owns Ctrl+Space, VibeTyper's dictation key.
    # Vulkan: Brave's Wayland backend refuses it ("'--ozone-platform=wayland' is
    # not compatible with Vulkan", logged at every launch), so brave://flags'
    # enable-vulkan only adds a failed start; a feature disabled here wins over
    # the flag.
    # Chromium reads only the last --disable-features, and the nixpkgs wrapper
    # passes its own first: its list is repeated here, or this flag erases it.
    # After a flake update, compare with the wrapper's first match in
    # `grep -o -- '--disable-features=[^ ]*' $(which brave)`.
    commandLineArgs = [
      "--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder,BraveCommander,Vulkan"
    ];
  };

  # New-tab wallpaper off: the page falls back to the theme's flat background.
  # Brave ships no policy for it, and Chromium reads policies from /etc only, so
  # the profile pref is the only lever. Brave holds that file in memory and
  # rewrites it on exit, hence a seed while Brave is down rather than a managed
  # file; toggling it back on in the NTP settings lasts until the next switch.
  home.activation.braveNewTabBackground = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ${pkgs.procps}/bin/pgrep -x -u "$USER" 'brave|\.brave-wrapped' > /dev/null; then
      echo "brave: running, new-tab prefs untouched -- quit it and switch again"
    else
      for prefs in "$HOME/.config/BraveSoftware/Brave-Browser"/*/Preferences; do
        [[ -e $prefs ]] || continue
        if ${pkgs.jq}/bin/jq -e '.brave.new_tab_page.show_background_image == false' "$prefs" > /dev/null; then
          continue
        fi
        if [[ -v DRY_RUN ]]; then
          echo "would disable new-tab background images in $prefs"
        else
          tmp=$(mktemp "$prefs.hm-XXXXXX")
          ${pkgs.jq}/bin/jq -c '.brave.new_tab_page.show_background_image = false' "$prefs" > "$tmp"
          mv "$tmp" "$prefs"
          echo "brave: new-tab background images off in $prefs"
        fi
      done
    fi
  '';
}
