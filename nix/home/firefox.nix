{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  # Firefox runs under firejail with a tmpfs $HOME. A protocol handler it
  # launches itself runs inside that jail: empty ~/.config, no access to the
  # already-running instance outside (Slack's magic-login lands in a throwaway
  # second Slack, Obsidian opens without its vaults). Firefox's own portal
  # pref covers file reveal only, not protocol links, so route
  # those through the OpenURI portal explicitly: this xdg-open is a pure
  # portal client and the portal launches the handler in the host session.
  portalOpen = {
    action = "useHelperApp";
    ask = false;
    handlers = [{
      name = "xdg-desktop-portal";
      path = "${pkgs.flatpak-xdg-utils}/bin/xdg-open";
    }];
  };
  firefoxBin = "${home}/.nix-profile/bin/firefox";
  # Pre-launch history maintenance — fresh starts only. When Firefox is already
  # running (link clicks from other apps), exec immediately: any delay here sits
  # between click and page.
  firefoxLaunch = pkgs.writeShellScript "firefox-launch" ''
    export PATH="${home}/.nix-profile/bin:$PATH"
    if ! pgrep firefox >/dev/null; then
      secrets=${home}/.dotfiles/secrets
      $secrets/scripts/browsing-archive || true
      $secrets/scripts/browsing-cleanup --quiet || true
    fi
    exec /usr/bin/firejail ${firefoxBin} "$@"
  '';
in
{
  home.file.".config/firejail/firefox.local".source = ../../firejail/firefox.local;

  xdg.desktopEntries.firefox = {
    name = "Firefox";
    genericName = "Web Browser";
    exec = "${firefoxLaunch} %u";
    icon = "firefox";
    type = "Application";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "text/html"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "application/xhtml+xml"
      "application/pdf"
    ];
    terminal = false;
  };

  programs.firefox = {
    enable = true;

    # Pin the legacy native profile dir. HM 26.05+ defaults to XDG
    # (~/.config/mozilla/firefox) once stateVersion >= 26.05, which we are.
    # TODO: migrate ~/.mozilla → ~/.config/mozilla eventually (move dir, update
    # firejail whitelist + backup paths in dirs.txt), then drop this pin.
    configPath = ".mozilla/firefox";

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisableRemoteImprovements = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";

      EnableTrackingProtection = {
        Value = true;
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
      };

      PasswordManagerEnabled = false;

      GenerativeAI = {
        Chatbot = false;
        LinkPreviews = false;
      };

      Handlers.schemes = {
        slack = portalOpen;
        obsidian = portalOpen;
      };
    };

    profiles.default = {
      isDefault = true;

      search = {
        default = "google";
        force = true;
        engines = {
          "GitHub" = {
            urls = [{ template = "https://github.com/search?q={searchTerms}&type=repositories"; }];
            definedAliases = [ "@gh" ];
          };
          "Nix Packages" = {
            urls = [{ template = "https://search.nixos.org/packages?query={searchTerms}"; }];
            definedAliases = [ "@nix" ];
          };
          "PyPI" = {
            urls = [{ template = "https://pypi.org/search/?q={searchTerms}"; }];
            definedAliases = [ "@pypi" ];
          };
          "MDN" = {
            urls = [{ template = "https://developer.mozilla.org/en-US/search?q={searchTerms}"; }];
            definedAliases = [ "@mdn" ];
          };
          "bing".metaData.hidden = true;
          "amazon".metaData.hidden = true;
          "ebay".metaData.hidden = true;
        };
      };

      settings = {
        # Session & startup
        "browser.startup.page" = 3;
        "browser.newtabpage.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.aboutConfig.showWarning" = false;

        # UI
        "browser.toolbars.bookmarks.visibility" = "never";
        "browser.download.autohideButton" = false;
        "browser.zoom.siteSpecific" = false;

        # Tab unloading & memory pressure
        "browser.tabs.unloadOnLowMemory" = true;
        "browser.low_commit_space_threshold_percent" = 15;
        "browser.tabs.min_inactive_duration_before_unload" = 300000; # 5min (default 10min)
        "memory.free_dirty_pages" = true;

        # Search
        "browser.search.suggest.enabled" = false;
        "browser.urlbar.quicksuggest.dataCollection.enabled" = false;

        # Privacy
        "privacy.donottrackheader.enabled" = true;
        "privacy.globalprivacycontrol.enabled" = true;
        "network.dns.disablePrefetch" = true;
        "network.http.speculative-parallel-limit" = 0;
        "network.prefetch-next" = false;
        "dom.security.https_only_mode" = true;

        # Containers
        "privacy.userContext.enabled" = true;
        "privacy.userContext.ui.enabled" = true;

        # Appearance
        "layout.css.prefers-color-scheme.content-override" = 0;
        "layout.spellcheckDefault" = 0;

        # Reader Mode — disabled so Alt+Shift+R goes to Obsidian Web Clipper
        "reader.parse-on-load.enabled" = false;

        # Translations
        "browser.translations.automaticallyPopup" = false;
        "browser.translations.neverTranslateLanguages" = "de";

        # GPU / performance
        "media.ffmpeg.vaapi.enabled" = true;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        # Reveal-in-file-manager goes through the portal, so it runs the
        # session's file manager, not one inside the jail. Protocol links are
        # not covered by this pref: see Handlers above.
        "widget.use-xdg-desktop-portal.open-uri" = 1;
        "media.eme.enabled" = true;
        "media.webspeech.synth.enabled" = false;
      };
    };
  };
}
