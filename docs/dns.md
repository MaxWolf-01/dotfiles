# DNS

Filtered hosts resolve through Mullvad's public filtering resolver
`base.dns.mullvad.net`, which drops ads, trackers and malware domains. Two
mechanisms deliver it:

| Host | Path |
| --- | --- |
| zephylux | local failover chain, `bin/dns-failover-install` |
| phone | tailnet DNS: tailscaled forwards to Mullvad over DoH |
| xmg19 | tailnet DNS; offline, and planned to opt out as a server (`agent/tasks/xmg19-offsite-server-planning.md`) |
| pc | unfiltered: the LAN router, via dhcpcd + resolvconf |
| jarvis, yapit-prod | unfiltered: each VPS's own resolver |

Mullvad publishes several list flavours, one IP each:
<https://mullvad.net/en/help/dns-over-https-and-dns-over-tls>. The tailnet
config lives in `secrets/tailscale/dns.json`, pushed with `bin/tailscale-dns`;
the failover chain names the same resolver in `bin/dns-failover-install`.

## zephylux: the failover chain

systemd-resolved hands every name to a local dnsproxy front
(`127.0.0.1:5300`), which forwards over a strict three-tier chain — Mullvad
DoT through the exit node, Mullvad DoT past the tunnel, plain DNS to Mullvad's
IP — each tier tried per query only after the one before fails. Mechanics and
rationale: the comments in `bin/dns-failover-install`.

What follows from the shape:

- A dead tunnel costs ~2 s per uncached lookup instead of an outage. The chain
  exists because tailnet DNS died three times in one day of tunnel trouble:
  `agent/tasks/dns-fails-closed-on-flaky-link.md`.
- No failure path reaches a non-Mullvad resolver. Plain 53 is used only on
  networks that block both DoT paths.
- Queries carry the real source IP only while the tunnel path is failing.
- `journalctl -u dnsproxy-direct` shows exactly the queries the tunnel path
  failed — it is the tunnel-outage log.
- tailscaled runs `--accept-dns=false` (a stored preference, survives
  reboots). MagicDNS still works: the front routes `ts.net` to tailscaled's
  internal resolver, which answers regardless of that preference.

## Tailnet DNS (phone, xmg19 until repurposed)

tailscaled claims all DNS on a device that accepts tailnet DNS: applications
talk to the local stub, the stub hands everything to `100.100.100.100`, and
tailscaled forwards to Mullvad over DoH — the plain IPs in `dns.json` are
upgraded via its table of well-known DoH endpoints
(`net/dns/publicdns/publicdns.go`). On Android the same config arrives through
the Tailscale app; nothing is set in the phone's own Private DNS.

The nameserver is tailnet-wide because per-host does not work under a Mullvad
exit node. Every Mullvad exit node advertises the *unfiltered* resolver
`194.242.2.2` in the netmap:

```
tailscale debug netmap | jq '.Peers[] | select(.Name|test("mullvad")) | {Name, ExitNodeDNSResolvers}'
```

and tailscaled prefers that over host-local config. Tailnet resolvers arrive
as `nm.DNS.Resolvers` in `ipn/ipnlocal/node_backend.go`, where
`if len(nm.DNS.Resolvers) > 0 { addDefault(...) }` runs unconditionally — which
also means `fallbackResolvers` never apply, and DNS on these hosts fails
closed when the resolver is unreachable (the incident record in
`agent/tasks/dns-fails-closed-on-flaky-link.md` is the full analysis, source
references included).

Two consequences:

- Filtering cannot be scoped to the exit node; setting tailnet resolvers means
  tailscaled owns DNS on every network.
- It reaches every device that accepts tailnet DNS, servers included — on a
  server the blocklists are a liability: no browser to protect, and a blocked
  domain is a silent `NXDOMAIN`.

The servers are therefore opted out with `--accept-dns=false`. pc stores it in
`services.tailscale.extraSetFlags`; the VPSes do not run NixOS, so there it is
imperative state — re-apply with `ssh <host> tailscale set --accept-dns=false`
after any reinstall.

When DoH is unreachable, tailscaled falls back to plain port 53
(`net/dns/resolver/forwarder.go`), and Mullvad's port 53 listener answers
*without* the blocklists — so on these hosts filtering fails open silently
under DNS trouble, and resolved caches the unfiltered answer for the TTL.

### No global `Domains=~.` beside tailscaled

On a host where tailscaled owns DNS, do not add a global `Domains=~.` resolver
in resolved. From `man systemd-resolved`: the best-matching routing domain
sends the query "to **all** DNS servers of any links or the globally
configured DNS servers associated with this best matching routing domain" — a
global `~.` and `tailscale0`'s `~.` both match, both are queried in parallel,
and an unfiltered answer beats Mullvad's NXDOMAIN. Filtering then looks
completely broken while `dig @100.100.100.100 doubleclick.net` still returns
`NXDOMAIN`. (zephylux sets a global `~.` deliberately — there tailscaled is
out of the DNS path entirely.)

## Captive portals

Run `portal`. It drops the exit node (pre-login the portal blocks the tunnel,
so all traffic routed into it dies), opens the login page — by name when the
portal answers DNS, by gateway IP when it does not — and restores the VPN by
itself once real internet is detected.

On the phone: toggle Tailscale off in quick settings, log in, toggle it back.

## Is this domain blocked?

A block is indistinguishable from a typo: the resolver says the name does not
exist. `dns-blocked <domain>...` asks Mullvad directly over DoT and reports
which list refused the name; the resolver it asks comes from
`secrets/tailscale/dns.json`.

For the other direction — what started being refused lately, and which of it
something on this machine keeps retrying — read
`~/Documents/dashboards/dns-vpn.html`. A newly blocked domain notifies nobody;
it waits on that page, alongside the exit-node rotations `vpn-pick` made.
`docs/monitoring.md` covers how that page is built and kept fresh.

## Verify

```
resolvectl query doubleclick.net       # blocked: "Name 'doubleclick.net' not found"
resolvectl query github.com            # resolves
dig @127.0.0.1 -p 5300 doubleclick.net # zephylux: what the front alone says
dig @127.0.0.1 -p 5301 github.com      # zephylux: the bypass path alone
resolvectl query pc                    # MagicDNS
tailscale dns status                   # resolvers the control plane handed this device
tailscale-dns diff                     # live tailnet config vs the versioned file
```
