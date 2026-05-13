{ pkgs, ... }:

# mdsr — spaced repetition over Obsidian callouts
# https://github.com/MaxWolf-01/mdsr
#
# Exposed on the tailnet at  http://pc.<tailnet>.ts.net/sr/
#
# To switch to HTTPS later:
#   1. admin.tailscale.com → DNS → enable "HTTPS Certificates"
#   2. swap `--http=80` for `--https=443` below
let
  vault = "git@github.com:MaxWolf-01/knowledge-base.git";

  port = 8765;
  urlPath = "/sr";
in
{
  systemd.user.services.mdsr = {
    description = "mdsr — spaced repetition server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "default.target" ];
    path = [ pkgs.uv pkgs.git ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.uv}/bin/uv tool install --upgrade mdsr";
      ExecStart = "%h/.local/bin/sr --vault ${vault} --host 127.0.0.1 --port ${toString port} --root-path ${urlPath}";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # `tailscale serve` persists config in /var/lib/tailscale, so this is effectively
  # a boot-time reconciler — re-running is idempotent. Additive: doesn't clobber
  # other serve paths set imperatively.
  systemd.services.mdsr-tailscale-serve = {
    description = "Tailscale serve mount for mdsr at ${urlPath}";
    after = [ "tailscaled.service" "network-online.target" ];
    requires = [ "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --http=80 --set-path=${urlPath} http://127.0.0.1:${toString port}";
    };
  };
}
