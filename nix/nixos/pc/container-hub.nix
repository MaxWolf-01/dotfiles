# max's container hub on the tailnet. The hub itself is his user service
# (nix/home/container-hub.nix), listening on a socket only he can open; this
# puts that socket on the tailnet at https://pc.tail710178.ts.net:8377/, the
# address the phone opens, and keeps every other user of pc off it.
#
# tailscaled also listens on pc's own tailnet addresses, for connections from
# pc itself, and those never meet the tailnet policy: without the rule below,
# a dispatch worker (agent-user.nix) reaches max's hub through that address
# and acts in his sessions. max's own processes reach it on the socket, or
# through this address as the rule lets them.
{ pkgs, lib, ... }:
let
  port = 8377;
  socket = "/home/max/.local/state/container-hub/hub.sock";
  # Locally sent, to an address of pc's own, from any user but max. tcp-reset:
  # the connection is refused at once rather than left to time out. The
  # firewall's reload re-runs extraCommands, so the delete has the exact shape.
  rule = "OUTPUT -p tcp --dport ${toString port} -m addrtype --dst-type LOCAL -m owner ! --uid-owner max -j REJECT --reject-with tcp-reset";
in
{
  # tailscale serve does not check the socket exists, so the line holds from
  # boot, before max's user service makes it.
  systemd.services.tailscale-serve.serviceConfig.ExecStart = [
    "${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=${toString port} unix:${socket}"
  ];

  networking.firewall = {
    extraCommands = "ip46tables -A ${rule}";
    extraStopCommands = "ip46tables -D ${rule} || true";
  };
}
