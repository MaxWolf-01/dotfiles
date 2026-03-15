{ pkgs, lib, ... }:

let
  cacheDb = "$HOME/.local/share/newsboat/cache.db";

  codeberg-feed-filter = pkgs.writers.writePython3 "codeberg-feed-filter" { flakeIgnore = [ "E501" ]; } (
    # Strip shebang — writers.writePython3 adds its own
    builtins.concatStringsSep "\n" (builtins.tail (lib.splitString "\n" (builtins.readFile ../../bin/codeberg-feed-filter)))
  );

  codebergFeed = url: {
    url = "filter:${codeberg-feed-filter}:${url}";
    tags = [ "lucidrains" ];
  };

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

    urls = [
      { url = "https://ludwigabap.com/rss.xml"; }
      { url = "https://www.julian.ac/feeds/all.rss.xml"; }
      { url = "https://geohot.github.io/blog/feed.xml"; }
      { url = "https://stephango.com/feed.xml"; }
      { url = "https://steipete.me/rss.xml"; }
      { url = "https://lucumr.pocoo.org/feed.xml"; }
      { url = "https://earendil.com/posts/feed.rss"; }
      (codebergFeed "https://codeberg.org/lucidrains/x-evolution.rss")
      (codebergFeed "https://codeberg.org/lucidrains/streaming-deep-rl.rss")
      (codebergFeed "https://codeberg.org/lucidrains/metacontroller.rss")
      (codebergFeed "https://codeberg.org/lucidrains/x-transformers.rss")
      (codebergFeed "https://codeberg.org/lucidrains/recurrent-memory-transformer-pytorch.rss")
      (codebergFeed "https://codeberg.org/lucidrains/x-mlps.rss")
      (codebergFeed "https://codeberg.org/lucidrains/evolutionary-policy-optimization.rss")
      (codebergFeed "https://codeberg.org/lucidrains/torch-einops-utils.rss")
      (codebergFeed "https://codeberg.org/lucidrains/fast-weight-product-key-memory.rss")
      (codebergFeed "https://codeberg.org/lucidrains/rotary-embedding-torch.rss")
      (codebergFeed "https://codeberg.org/lucidrains/native-sparse-attention-pytorch.rss")
    ];

    queries = {
      "All Unread" = "unread = \"yes\"";
      "lucidrains" = "tags # \"lucidrains\"";
    };

    extraConfig = ''
      notify-program "${pkgs.libnotify}/bin/notify-send"
      notify-format "%d new articles (%n unread articles, %f unread feeds)"
      notify-always no

      browser "xdg-open %u >/dev/null 2>&1 &"

      bind-key j down
      bind-key k up
      bind-key J next-feed articlelist
      bind-key K prev-feed articlelist
      bind-key g home
      bind-key G end

      cleanup-on-quit yes
      datetime-format "%Y-%m-%d"
      articlelist-format "%4i %D  %?T?|%-17T|  ?%t"
      article-sort-order date-asc
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
