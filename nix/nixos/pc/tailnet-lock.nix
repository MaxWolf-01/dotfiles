{ pkgs, ... }:

{
  # A system unit, not a user one: fewest moving parts on a headless host (no
  # user-manager lingering, no ordering against tailscaled-set). Running as root
  # is not a trust boundary here — max is in wheel and docker.
  systemd.services.tailnet-lock-sign = {
    description = "Sign Mullvad exit nodes locked out by Tailnet Lock";
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.tailscale pkgs.jq pkgs.bash pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/home/max/.dotfiles/bin/tailnet-lock-sign";
    };
  };

  systemd.timers.tailnet-lock-sign = {
    description = "Periodic Tailnet Lock signing of Mullvad exit nodes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "15m";
      RandomizedDelaySec = "1m";
    };
  };
}
