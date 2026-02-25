{ pkgs, lib, ... }:

let
  cacheDb = "$HOME/.local/share/newsboat/cache.db";

  newsboat-reload-notify = pkgs.writeShellScript "newsboat-reload-notify" ''
    set -uo pipefail
    max_id_before=$(${lib.getExe pkgs.sqlite} "${cacheDb}" "SELECT COALESCE(MAX(id), 0) FROM rss_item;")
    ${lib.getExe pkgs.flock} /run/user/$(id -u)/newsboat.lock ${lib.getExe pkgs.newsboat} --execute=reload
    new=$(${lib.getExe pkgs.sqlite} "${cacheDb}" "
      SELECT f.title || ': ' || i.title
      FROM rss_item i JOIN rss_feed f ON i.feedurl = f.rssurl
      WHERE i.id > $max_id_before AND i.deleted = 0
      ORDER BY i.pubDate DESC LIMIT 10;
    ")
    count=$(${lib.getExe pkgs.sqlite} "${cacheDb}" "
      SELECT COUNT(*) FROM rss_item WHERE id > $max_id_before AND deleted = 0;
    ")
    if [ "$count" -gt 0 ]; then
      body="$new"
      [ "$count" -gt 10 ] && body="$body
...and $((count - 10)) more"
      ${pkgs.libnotify}/bin/notify-send -a "Newsboat" "📰 $count new article(s)" "$body"
    fi
  '';
in
{
  programs.newsboat = {
    enable = true;

    autoReload = true;
    reloadTime = 60;

    extraConfig = ''
      notify-program "${pkgs.libnotify}/bin/notify-send"
      notify-format "%d new articles (%n unread articles, %f unread feeds)"
      notify-always no

      browser "xdg-open %u"

      bind-key j down
      bind-key k up
      bind-key J next-feed articlelist
      bind-key K prev-feed articlelist
      bind-key g home
      bind-key G end

      articlelist-format "%4i %f %D  %?T?|%-17T|  ?%t"
      article-sort-order date-desc
    '';
  };

  systemd.user.services.newsboat-fetch-articles = {
    Unit = {
      Description = "Fetch newsboat articles and notify on new";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString newsboat-reload-notify;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.newsboat-fetch-articles = {
    Unit.Description = "Hourly newsboat fetch with notifications";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
