{ lib, pkgs, ... }:
let
  # Settings Brave keeps per profile, seeded by the activation script below.
  # Key paths are the ones brave-core registers (`strings` on the binary lists
  # them); the value here wins over whatever the UI last wrote.
  profilePrefs = {
    brave = {
      new_tab_page = {
        # Black rather than off, because a page with show_background_image
        # off falls back to a bright gradient. The dict is what the new-tab
        # settings write for a solid colour; NTPBackgroundPrefs in
        # browser/ntp_background/ntp_background_prefs.h documents its shape.
        show_background_image = true;
        background = {
          type = "color";
          selected_value = "#000000";
          random = false;
        };
        show_branded_background_image = false;
        show_sponsored_sites = false;
        hide_all_widgets = true;
        show_stats = false;
        show_clock = false;
        show_brave_news = false;
        show_rewards = false;
        show_brave_vpn = false;
      };
      # Leo's surfaces. The feature itself only goes away through the
      # BraveAIChatEnabled policy: brave-core ignores an unmanaged
      # brave.ai_chat.enabled_by_policy (IsDisabledByPolicy in
      # components/ai_chat/core/browser/utils.cc).
      ai_chat = {
        show_toolbar_button = false;
        context_menu_enabled = false;
        autocomplete_provider_enabled = false;
        tab_organization_enabled = false;
      };
      rewards = {
        enabled = false;
        show_brave_rewards_button_in_location_bar = false;
      };
      brave_ads.enabled = false;
      wallet.show_wallet_icon_on_toolbar = false;
      # Brave News, under its old name.
      today = {
        opted_in = false;
        should_show_toolbar_button = false;
      };
    };
  };
in
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

  # Brave exposes none of the above as policy, and Chromium reads policy files
  # from /etc only, which standalone Home Manager cannot write here. So the
  # prefs are merged into each profile's Preferences instead -- while Brave is
  # down, because a running Brave rewrites that file from memory on exit.
  home.activation.braveProfilePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ${pkgs.procps}/bin/pgrep -x -u "$USER" 'brave|\.brave-wrapped' > /dev/null; then
      echo "brave: running, profile prefs untouched -- quit it and switch again"
    else
      for prefs in "$HOME/.config/BraveSoftware/Brave-Browser"/*/Preferences; do
        [[ -e $prefs ]] || continue
        if ${pkgs.jq}/bin/jq -e --argjson patch '${builtins.toJSON profilePrefs}' '. * $patch == .' "$prefs" > /dev/null; then
          continue
        fi
        if [[ -v DRY_RUN ]]; then
          echo "would update brave prefs in $prefs"
        else
          tmp=$(mktemp "$prefs.hm-XXXXXX")
          ${pkgs.jq}/bin/jq -c --argjson patch '${builtins.toJSON profilePrefs}' '. * $patch' "$prefs" > "$tmp"
          mv "$tmp" "$prefs"
          echo "brave: prefs applied to $prefs"
        fi
      done
    fi
  '';
}
