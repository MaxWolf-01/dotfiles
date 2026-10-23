# The hosts that run max's sessions, by the name the hub tab shows each under,
# with the ssh destination that reaches it as max and how far it is trusted.
# Each host's hub relays every other host trusted as much as it or less
# (nix/home/container-hub.nix), since relaying one means holding max's ssh
# login to it; a host is never handed a login to one it trusts more.
#
# The session copies follow the same rule (session-copies.nix): each host
# pulls max's sessions from every host its hub relays.
#
# hub.mwolf.dev (bin/container-hub-address) tries each host's hub in this
# order and opens the first that answers, so a host that is up the most comes
# first. The name is also the host's tailnet name: the page finds its hub at
# https://<name>.tail710178.ts.net:8377/.
#
# A new host is an entry here and nothing else. A VPS, say, would be
# `{ name = "vps"; ssh = "vps"; trust = 1; }`: pc and the laptop relay it and
# pull its sessions, it relays and pulls neither, and the page tries its hub.
[
  { name = "pc"; ssh = "pc"; trust = 2; }
  { name = "zephylux"; ssh = "zephylux"; trust = 2; }
]
