# tailscaled's serve table: what pc serves on the tailnet, and through Funnel
# on the internet.
#
# tailscaled keeps its own address -> local port table. It is not in this repo
# and it survives reboots, so this unit wipes it and rewrites it on every boot.
# That only works while a single unit owns the table: a second unit that also
# wipes would erase the others' lines, and what they serve would go down with
# no error. So each service adds its line to this unit's ExecStart, from its
# own module (sftpgo.nix, container-hub.nix), and nothing else runs
# `tailscale serve reset`.
{ pkgs, ... }:
{
  systemd.services.tailscale-serve = {
    description = "tailscaled's serve table: the SFTPGo funnel and the container hub";
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
    };
  };
}
