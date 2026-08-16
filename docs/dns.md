# DNS

Every device in the tailnet resolves names through Mullvad's public filtering
resolver, which drops ads, trackers and malware domains. Config:
`secrets/tailscale/dns.json`, pushed with `bin/tailscale-dns`.

## What resolves what

`tailscaled` claims all DNS on every device that accepts tailnet DNS (the
default). Applications talk to the local stub, the stub hands everything to
`100.100.100.100`, and `tailscaled` forwards it to Mullvad over DNS-over-HTTPS.

| Resolver | Role |
| --- | --- |
| `194.242.2.4`, `2a07:e340::4` | `base.dns.mullvad.net` — ads + trackers + malware |
| `9.9.9.9`, `149.112.112.112` | Quad9 over TLS, in `/etc/systemd/resolved.conf.d/10-dot.conf`. Only reached when `tailscaled` is not claiming DNS |
| DHCP resolver | The local network's own. Reached on the same terms as Quad9 |

Those two IPs are not dialled as plain DNS. `tailscaled` ships a table of
well-known DoH endpoints (`net/dns/publicdns/publicdns.go`) that maps each
Mullvad address to its `https://` URL, so it upgrades them automatically.

Mullvad publish six flavours, from unfiltered to also blocking adult content,
gambling and social media, one IP each. `base` is the third. To change flavour,
change the address in `secrets/tailscale/dns.json`:
<https://mullvad.net/en/help/dns-over-https-and-dns-over-tls>.

## Why tailnet-wide, and not per host

Because per host does not work while a Mullvad exit node is up, and the exit
node is always up.

Mullvad's exit nodes advertise their own resolver in the netmap — every one of
them advertises `194.242.2.2`, the *unfiltered* flavour:

```
tailscale debug netmap | jq '.Peers[] | select(.Name|test("mullvad")) | {Name, ExitNodeDNSResolvers}'
```

`tailscaled` prefers that over anything the host configures locally, so the only
way to filter is to give the tailnet a resolver of its own. In
`ipn/ipnlocal/node_backend.go`, tailnet resolvers arrive as `nm.DNS.Resolvers`
and `if len(nm.DNS.Resolvers) > 0 { addDefault(...) }` runs unconditionally.

Two consequences follow, and neither is optional:

- **Filtering cannot be scoped to the exit node.** The `useWithExitNode` flag
  does not restrict a resolver to exit-node use, despite the name — it only
  stops the exit node's own resolver from displacing it. Setting tailnet
  resolvers at all means `tailscaled` owns DNS on every network.
- **It reaches every device that accepts tailnet DNS**, servers included. On a
  server the blocklists are a liability rather than a feature: no browser to
  protect, and a blocked domain is a silent `NXDOMAIN`.

## Which hosts are filtered

| Host | Filtered | Resolver in use |
| --- | --- | --- |
| zephylux, xmg19, phone | yes | Mullvad `base` over DoH, via tailscaled |
| pc | no | the LAN router, via dhcpcd + resolvconf |
| jarvis, yapit-prod | no | each VPS's own resolver |

The servers are opted out with `--accept-dns=false`. That costs MagicDNS on
those hosts and nothing else: every tailnet host in `programs.ssh.matchBlocks`
is addressed by IP, so nothing there resolves tailnet names.

`--accept-dns` is a stored preference, not config, so it needs a home. pc has
one — `services.tailscale.extraSetFlags`. The VPSes do not run NixOS, so on
those it is imperative state that a rebuild will not restore. Re-apply with
`ssh <host> tailscale set --accept-dns=false` if either is ever reinstalled.

Opting a host out leaves it on whatever its network hands out, in clear text.
pc talks plain DNS to the LAN router today.

## No global `Domains=~.`

`10-dot.conf` deliberately does not set `Domains=~.`, and neither does
`services.resolved` on xmg19. It looks like it would force lookups to Quad9
instead of the DHCP resolver. It does not, and it breaks filtering.

From `man systemd-resolved`: for a name, resolved picks the best-matching
routing domain, then sends the query "to **all** DNS servers of any links or the
globally configured DNS servers associated with this best matching routing
domain". A global `~.` and `tailscale0`'s `~.` both match with zero labels, so
both are queried in parallel and the first reply wins. Mullvad answering
"doubleclick.net does not exist" loses to Quad9 answering with an address.

The symptom is subtle: filtering appears completely broken, while
`dig @100.100.100.100 doubleclick.net` returns `NXDOMAIN` and proves the tailnet
resolver is doing its job.

## Captive portals

`tailscaled` holds the only claim on DNS, and `fallbackResolvers` do not rescue
this — they apply only when there is no default resolver at all. So on a portal
that permits DNS only to its own resolver, nothing resolves and no login page
appears: getting redirected to a portal requires resolving a hostname first.
Wifi shows connected; every site fails with a name-resolution error; GNOME says
"no internet" instead of offering to sign in, because NetworkManager's
connectivity check is itself a DNS lookup.

Confirm with `resolvectl query example.com`. Then:

```
vpn-dns-off     # tailscale set --accept-dns=false — hand DNS back to the network
                # log in to the portal
vpn-on          # restores exit node and DNS together
```

`vpn-on` passes `--accept-dns=true` precisely so a forgotten `vpn-dns-off` cannot
persist silently. `--accept-dns` is a stored preference and survives reboots.

Many portals intercept all port 53 traffic and answer for it themselves. Those
keep working: `tailscaled` races DoH against plain port 53 with a 500 ms head
start for DoH, so the hijacked reply arrives and wins.

That same race is why filtering fails open rather than closed. Mullvad's port 53
listener answers ordinary queries *without* applying the blocklists, so if DoH
is ever unreachable you silently keep working and silently stop blocking.

## Is this domain blocked?

A block is invisible by design. The resolver says the name does not exist, which
is what a typo says too, so a broken application looks like a broken application
and nothing points at DNS. `dns-blocked` settles it — it asks Mullvad directly
over DoT and reads back which list refused the name:

```
$ dns-blocked doubleclick.net nonexistent-zzz.invalid github.com
doubleclick.net         BLOCKED (ads)
nonexistent-zzz.invalid does not exist (not a block)
github.com              resolves
```

The resolver it asks comes from `secrets/tailscale/dns.json`, so it always
matches the flavour the tailnet is on.

## Verify

```
resolvectl query doubleclick.net     # blocked: "Name 'doubleclick.net' not found"
resolvectl query github.com          # resolves
resolvectl query pc                  # MagicDNS still works
dig @100.100.100.100 doubleclick.net # what the tailnet resolver alone says
tailscale dns status                 # resolvers the control plane handed this device
tailscale-dns diff                   # live tailnet config vs the versioned file
```

On Android the same config arrives through the Tailscale app; nothing is set in
the phone's own Private DNS. Turning Tailscale off in the quick settings tile is
the phone's equivalent of `vpn-dns-off`.
