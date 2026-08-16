{ pkgs, ... }:

{
  # Runs as root rather than as max. Not a trust boundary — max is in wheel and
  # docker here — just one less thing to depend on: a user unit would break if
  # the tailscale operator grant ever went away.
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
