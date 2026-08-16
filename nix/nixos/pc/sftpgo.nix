{ pkgs, lib, ... }:

# SFTPGo file drop — max and friends upload/download through a web UI.
#
#   https://pc.tail710178.ts.net/        web client, public via Tailscale Funnel
#   http://pc.tail710178.ts.net:8081/    web admin + REST API, tailnet only
#   sftp://pc.tail710178.ts.net:2022/    SFTP, tailnet only
#
# The MagicDNS name, not `pc`: a router that answers for the short name hands
# back pc's LAN address, and both these ports are firewalled off every interface
# but tailscale0, so the short name hangs rather than failing.
#
# The public surface is deliberately only the web *client*: the admin UI, the
# REST API and the OpenAPI renderer are off on that binding, so the admin login,
# the first-run setup page, the token endpoints and password reset all 404 from
# the internet. The admin binding is not in `networking.firewall.allowedTCPPorts`,
# so it is reachable only over `tailscale0` (a trusted interface); same for SFTP.
#
# Accounts are runtime state, not config — mint and revoke them with
# `sftpgo-user` (bin/). Only non-secret provider state is declared here, via
# `loadDataFile`, which SFTPGo re-applies on every start.

let
  storage = "/srv/sftpgo";

  publicPort = 8080; # loopback only; tailscaled's funnel proxy is the sole client
  adminPort = 8081;
  sftpPort = 2022;

  retentionMonths = 9;

  securityHeaders = {
    enabled = true;
    content_type_nosniff = true;
    referrer_policy = "same-origin";
    cross_origin_opener_policy = "same-origin";
    permissions_policy = "geolocation=(), microphone=(), camera=()";
    # $NONCE is substituted per request and matched by the templates' CSPNonce.
    # Inline styles stay allowed: the bundled theme sets style="" attributes
    # throughout, and blob: URLs back the file preview and download paths.
    content_security_policy = lib.concatStringsSep "; " [
      "default-src 'self'"
      "script-src 'self' $NONCE"
      "style-src 'self' 'unsafe-inline'"
      "img-src 'self' data: blob:"
      "font-src 'self' data:"
      "media-src 'self' blob:"
      "object-src 'self' blob:"
      "frame-src 'self' blob:"
      "frame-ancestors 'none'"
      "base-uri 'self'"
      "form-action 'self'"
    ];
  };

  # Provider state that carries no secrets and so is safe in the world-readable
  # /nix/store. Applied at every start; see SFTPGO_LOADDATA_MODE below for why
  # editing any of it actually takes effect.
  initialData = (pkgs.formats.json { }).generate "sftpgo-initial-data.json" {
    version = 17;

    event_actions = [{
      name = "retention-check";
      description = "Delete files older than ${toString retentionMonths} months";
      type = 8; # data retention check
      options.retention_config.folders = [{
        path = "/";
        retention = retentionMonths * 30 * 24; # hours
        delete_empty_dirs = true;
      }];
    }];

    event_rules = [{
      name = "nightly-retention";
      description = "Expire dropped files so nothing rots";
      status = 1;
      trigger = 3; # schedule
      # No name filter: every account, max's included.
      conditions.schedules = [{
        hour = "4";
        day_of_month = "*";
        month = "*";
        day_of_week = "*";
      }];
      actions = [{
        name = "retention-check";
        order = 1;
        relation_options = { };
      }];
    }];

    # Backstop for a misconfigured client-IP header: if the real address ever
    # fails to resolve, every request collapses to 127.0.0.1, and a safe-listed
    # address is exempt from bans *and* from max_per_host_connections. Losing
    # brute-force protection beats banning every user at once.
    ip_lists = [
      { ipornet = "127.0.0.1/32"; description = "funnel proxy backstop"; type = 2; mode = 1; protocols = 0; }
      { ipornet = "127.0.0.1/32"; description = "funnel proxy backstop"; type = 3; mode = 1; protocols = 0; }
    ];
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${storage} 0750 sftpgo sftpgo -"
  ];

  # loaddata defaults to mode 1, which skips objects that already exist
  # (internal/cmd/root.go defaultLoadDataMode, honoured in RestoreEventRules and
  # RestoreIPListEntries). That makes loadDataFile write-once: editing the
  # retention window would apply on a fresh database and nowhere else. Mode 0
  # updates in place. It also adds and updates users, which is safe here only
  # because loadDataFile declares none — keep it that way.
  systemd.services.sftpgo.environment.SFTPGO_LOADDATA_MODE = "0";

  services.sftpgo = {
    enable = true;
    extraReadWriteDirs = [ storage ];
    loadDataFile = initialData;

    settings = {
      common = {
        # Ignore client-requested timestamp and permission changes. Retention
        # expires files on their modification time, so a client that preserves
        # timestamps (sftp -p, rsync -t, WinSCP) would upload a file already
        # older than the retention window and lose it at the next nightly run.
        # Ignoring setstat makes mtime mean "when it arrived", which is what
        # expiry should measure.
        setstat_mode = 1;

        # Web asset bursts blow through the default 20 concurrent requests per
        # host; the rate limiter and defender are the layers that tell load
        # apart from attack.
        max_per_host_connections = 50;

        # Bans after 10 failed logins (default 15). The increment compounds on
        # every attempt made while already banned, so a browser that retries
        # turns a short ban into a day-long one — measured: 13 attempts at a
        # 100% increment produced a 7-hour ban. Generated passwords are 24
        # random alphanumerics, so brute force is hopeless regardless; this
        # exists to stop noise, not as the primary defence. Hence the stock
        # increment and a lockout a locked-out friend can wait out.
        defender = {
          enabled = true;
          driver = "memory";
          threshold = 10;
          ban_time = 30;
          ban_time_increment = 50;
          observation_time = 60;
          login_delay.password_failed = 1000;
        };

        rate_limiters = [{
          average = 60;
          period = 1000;
          burst = 20;
          type = 2; # per IP
          protocols = [ "HTTP" ];
          generate_defender_events = true;
        }];
      };

      data_provider = {
        users_base_dir = storage;
        # Every new admin or user is created deliberately, via the tailnet-only
        # setup page or `sftpgo-user`.
        create_default_admin = false;
      };

      httpd = {
        # signing_passphrase is deliberately absent: `settings` renders into the
        # world-readable /nix/store, and a known passphrase lets anyone forge a
        # full-admin token offline, bypassing TOTP. Empty means SFTPGo derives a
        # random key at startup — the cost is re-logging in after each nswitch.
        bindings = [
          {
            address = "127.0.0.1";
            port = publicPort;
            enable_web_client = true;
            enable_web_admin = false;
            enable_rest_api = false;
            render_openapi = false;
            hide_login_url = 3;

            # tailscaled sets X-Forwarded-For with Set(), not Add(), so a
            # client-supplied value is overwritten by the true source address and
            # depth 0 (rightmost) is the only correct reading. Both halves
            # matter: without proxy_allowed the header is ignored and every
            # request collapses to 127.0.0.1.
            proxy_allowed = [ "127.0.0.1" ];
            client_ip_proxy_header = "X-Forwarded-For";
            client_ip_header_depth = 0;

            security = securityHeaders // {
              https_proxy_headers = [{ key = "X-Forwarded-Proto"; value = "https"; }];
              sts_seconds = 31536000;
              sts_include_subdomains = true;
            };
          }
          {
            address = "";
            port = adminPort;
            enable_web_client = true;
            enable_web_admin = true;
            enable_rest_api = true;
            # Plain HTTP inside WireGuard, so no HSTS: it would pin a scheme
            # this binding never serves.
            security = securityHeaders;
          }
        ];
      };

      sftpd.bindings = [{ address = ""; port = sftpPort; }];
    };
  };

  # Publish the public binding to the internet.
  #
  # tailscaled keeps its own address -> local port table. It is not in this repo
  # and it survives reboots, so this unit wipes it and rewrites it on every boot.
  # That only works while a single unit owns the table: a second unit that also
  # wipes would erase this line, and the funnel would go down with no error.
  # To publish another service later, add its line here.
  systemd.services.sftpgo-tailscale-funnel = {
    description = "Tailscale Funnel forward to the SFTPGo web client";
    after = [ "tailscaled.service" "network-online.target" ];
    requires = [ "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure"; # tailscaled may not be logged in yet at boot
      RestartSec = 10;
      ExecStartPre = "${pkgs.tailscale}/bin/tailscale serve reset";
      ExecStart = "${pkgs.tailscale}/bin/tailscale funnel --bg --yes --https=443 http://127.0.0.1:${toString publicPort}";
    };
  };

  security.sudo.extraRules = [{
    users = [ "max" ];
    commands = [
      { command = "/run/current-system/sw/bin/systemctl start sftpgo.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl stop sftpgo.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl restart sftpgo.service"; options = [ "NOPASSWD" ]; }
    ];
  }];
}
