# The hosts that run max's sessions, by the name the hub tab shows each under,
# with the ssh destination that reaches it as max and how far it is trusted.
# Each host's hub relays every other host trusted as much as it or less
# (nix/home/container-hub.nix), since relaying one means holding max's ssh
# login to it; a host is never handed a login to one it trusts more.
#
# For the hubs, a new host is an entry here and nothing else. A VPS, say,
# would be `vps = { ssh = "vps"; trust = 1; };`: pc's and the laptop's hubs
# relay it, and its own relays neither. The session copies are the one thing
# this list does not reach: their timers name their sources themselves
# (timers.nix, pc-timers.nix).
{
  pc = { ssh = "pc"; trust = 2; };
  zephylux = { ssh = "zephylux"; trust = 2; };
}
