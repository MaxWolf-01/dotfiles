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
    after = [ "network-online.target" "ssh-agent.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "default.target" ];
    path = [ pkgs.uv pkgs.git pkgs.openssh ];
    # The vault SSH key has a passphrase; reach github.com via the user's
    # ssh-agent (which holds the unlocked key). If the agent ever loses the
    # key (e.g. fresh boot with no auto-unlock), `git pull` will fail until
    # `ssh-add` is run interactively.
    environment.SSH_AUTH_SOCK = "/run/user/%U/ssh-agent";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.uv}/bin/uv tool install --upgrade mdsr";
      ExecStart = "%h/.local/bin/sr --vault ${vault} --host 127.0.0.1 --port ${toString port} --root-path ${urlPath}";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # Forward the whole tailnet hostname to mdsr (no `--set-path`): tailscale's
  # `--set-path` strips the prefix, which conflicts with mdsr's `--root-path`.
  # mdsr only answers at /sr/... so other paths just 404 at the app layer.
  # `serve reset` wipes any prior mounts so this is deterministic — if you
  # later add other services on this host, do them via additional units that
  # run after this one, or merge them into this oneshot.
  systemd.services.mdsr-tailscale-serve = {
    description = "Tailscale serve forward to mdsr";
    after = [ "tailscaled.service" "network-online.target" ];
    requires = [ "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.tailscale}/bin/tailscale serve reset";
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --http=80 http://127.0.0.1:${toString port}";
    };
  };
}
