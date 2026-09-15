# Pangolin fallback on restricted networks

Stellaris uses native Pangolin by default. When Pangolin is running and
NetworkManager's **primary** connection is `WifiGuest 1` (UUID
`2bcb55f5-c6ac-4ad8-bd08-cc07fdf68460`), a timer starts a separate
WireGuard-over-WebSocket transport. It checks every five seconds and stops the
extra transport when another connection becomes primary or Pangolin stops.
The phone becoming primary therefore disables fallback even if Wi-Fi remains
connected. Other hosts are not opted in.

Starting the transport does not immediately change ordinary Internet routing.
A bounded HTTPS probe to `https://1.1.1.1/`, bound to the WireGuard source
address, must succeed first. Later failed probes withdraw the fallback default
route while keeping the transport available for retries. Initial transport
failure therefore leaves native Internet routing intact; failures after a
successful takeover can interrupt traffic until the next probe completes
(normally under ten seconds). This is an external health-check dependency.

This is connection-profile selection, not UDP failure detection. Recreating the
saved Wi-Fi profile changes its UUID; update `hosts/stellaris/default.nix` in
that case. It is also not a kill switch: native connectivity remains the
default when fallback is disabled or its key is missing.

## Routing

- `pg-fallback` uses `10.250.251.2/32`, MTU 1280, and table `51871`, not the
  physical main table. WireGuard's automatic route capture is disabled.
- More-specific main-table routes, including LAN and Pangolin resource routes,
  remain in use. Other IPv4 traffic exits through `relay1` while fallback runs.
- IPv6 is not carried by this fallback and remains on the physical network.
- Wstunnel connects to `195.201.112.227:443` without relying on tunneled DNS,
  while verifying the certificate for `ws.banditlair.com` and using that Host.
- A relay-address rule uses the physical main table for both outgoing WSS and
  unmarked reverse lookups of its replies. Socket marking alone is insufficient
  with strict reverse-path filtering: wg-quick's automatic connection marking
  handles UDP, not the outer TCP transport.
- Source-address routing lets probes and their replies use WireGuard before
  default takeover. Only a successful probe installs the catch-all rule.
- NetworkManager's current native IPv4 DNS servers stay on the main routing
  table, including their reverse-path checks. These exceptions are read from
  `/run/NetworkManager/resolv.conf` before takeover and refreshed while active.
  `/etc/resolv.conf` is deliberately not used because it points at Pangolin's
  own proxy. Pangolin DNS addresses are excluded from the native exceptions.
- Mark/table `51871` and rule priorities `9999` through `10003` are owned by
  this fallback. Do not reuse them for another VPN.
- The public relay accepts WSS and forwards only to its existing loopback
  WireGuard listener. The new peer is separate from WSL. Server forwarding is
  limited to public IPv4 egress, not direct Foyer/private-network access.

The gateway address and WireGuard public key are explicit module options. If
the relay is replaced, update them from an independently verified source.
TCP head-of-line blocking can reduce performance on lossy networks. Switching
transports changes the public source address and can interrupt existing TCP
connections; this is automatic recovery, not seamless session migration.

## Provisioning and deployment

The matching server changes are in `../self-hosting/profiles/relay1.nix`, with
details in that repository's `docs/pangolin-fallback.md`. Deploy the relay first
over a working network such as 5G, preserving deploy-rs rollback protection.
Do not activate the workstation fallback before the server peer is installed.

The workstation private key is a runtime secret, not part of the Nix store or
either repository. Generate it directly at its persistent root-owned path;
do not use temporary storage for the deployment identity. This preserves any
existing key and prints only its public half:

```sh
wg_bin="$(nix build --no-link --print-out-paths 'nixpkgs#wireguard-tools^out')/bin/wg"
sudo /run/current-system/sw/bin/bash -c '
  set -eu
  umask 077
  install -d -m 0700 /etc/secrets
  key=/etc/secrets/wg-stellaris-fallback.key
  if [ ! -e "$key" ]; then "$1" genkey > "$key"; fi
  "$1" pubkey < "$key"
' bash "$wg_bin"
```

The peer for `10.250.251.2/32` currently uses the persistent key's public half,
`vi85E2q83PMXW6o9ffB+cKiFHqx0wZf8fqqf6hznDGM=`. If the key is regenerated,
update the relay peer before deploying.
Never commit the private key or pass it through a Nix expression.

Then activate Stellaris normally:

```sh
sudo nixos-rebuild switch --flake path:/home/phfroidmont/Projects/nixos-configs#stellaris
```

## Verification

```sh
nix build path:/home/phfroidmont/Projects/nixos-configs#checks.x86_64-linux.pangolin-fallback
systemctl status pangolin-fallback-reconcile.timer wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service
journalctl -u pangolin-fallback-reconcile -u wstunnel-pangolin-fallback --since '5 minutes ago'
sudo wg show pg-fallback
ip -4 rule show
pangolin status --json
```

On the guest profile, verify a recent outer WireGuard handshake, connected
Pangolin sites, and working private DNS/resources. On 5G or another primary
profile, verify both fallback services stop and table `51871` and rules `9999`
through `10003`
are removed. Stopping Pangolin must also stop the fallback. No manual changes
to application proxy settings are required.

Pangolin 0.15.1 polls physical DNS changes approximately every 30 seconds.
Allow about 45 seconds after a network change for its DNS proxy to adopt the
new resolvers. The native DNS exceptions prevent ISP-specific resolvers from
being queried through the remote relay, where they can reject off-network
clients. No restart of Pangolin is needed for a successful DNS update.

The `path:` flake reference includes newly created, not-yet-tracked files during
development. No commit is required for these commands.

### Isolated routing and firewall test

The following test uses disposable user, mount, and network namespaces. It
does not alter the host's routes or firewall and does not need sudo. The test
uses the server's actual evaluated firewall rules; its public IP target exists
only on a simulated network, with no packets sent to the Internet.

```sh
export HOST_NETNS="$(readlink /proc/self/ns/net)"
export FIREWALL_START="$(nix eval --no-write-lock-file --raw path:/home/phfroidmont/Projects/self-hosting#nixosConfigurations.relay1.config.networking.firewall.extraCommands)"
export FIREWALL_STOP="$(nix eval --no-write-lock-file --raw path:/home/phfroidmont/Projects/self-hosting#nixosConfigurations.relay1.config.networking.firewall.extraStopCommands)"
nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#gawk nixpkgs#gnused nixpkgs#gnugrep nixpkgs#wireguard-tools nixpkgs#iproute2 nixpkgs#iptables nixpkgs#nftables nixpkgs#iputils nixpkgs#util-linux nixpkgs#procps nixpkgs#python3 \
  -c unshare -Urnm bash tests/pangolin-fallback-network.sh
```

This checks a real marked TCP exchange under strict reverse-path filtering,
a real source-bound probe through WireGuard before takeover, default-route
promotion/withdrawal, more-specific Pangolin/LAN routes, teardown, NAT,
private/metadata destination isolation, WSL-source isolation, unsolicited
inbound filtering, and firewall reload. It also tests UDP DNS replies under
strict reverse-path filtering against a simulated resolver that accepts only
native-network clients, including DNS-server changes and exception cleanup.
