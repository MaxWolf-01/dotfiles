{ pkgs, ... }:

{
  # pc's tailscaled has no operator, so signing runs as root. That is the point:
  # the tailnet-lock key admits nodes to the tailnet, and granting the operator
  # role would hand that to every process running as max.
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
