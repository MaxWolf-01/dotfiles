{ pkgs, ... }:
{
  programs.newsboat = {
    enable = true;

    # urls left empty — managed imperatively via ~/.newsboat/urls
    autoReload = true;
    reloadTime = 60;

    # Background fetch via systemd timer (works when newsboat isn't open)
    autoFetchArticles = {
      enable = true;
      onCalendar = "hourly";
    };

    extraConfig = ''
      # Desktop notifications on new articles
      notify-program "${pkgs.libnotify}/bin/notify-send"
      notify-format "%d new articles (%n unread articles, %f unread feeds)"
      notify-always no

      browser "xdg-open %u"

      # Vim-like navigation
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
}
