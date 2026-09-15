#!/usr/bin/env bash
set -euo pipefail

# Run only inside a disposable user/network/mount namespace (see the deployment guide).
[[ $(readlink /proc/self/ns/net) != "${HOST_NETNS:?}" ]]
mount --make-rprivate /
mount -t tmpfs tmpfs /run
work=$(mktemp -d)
export NM_RESOLVCONF="$work/resolv.conf"
printf 'nameserver 194.154.192.101\n' > "$NM_RESOLVCONF"
server_pid=
trap 'if [[ -n $server_pid ]]; then kill "$server_pid" 2>/dev/null || true; fi; rm -rf "$work"' EXIT
ip link set lo up

# Check real wg-quick policy routing, not mocked ip commands.
ip netns add underlay
ip link add eth0 type veth peer name uplink0
ip link set uplink0 netns underlay
ip address add 198.19.0.1/24 dev eth0
ip link set eth0 up
ip route add default via 198.19.0.2
ip -n underlay link set lo up
ip -n underlay address add 198.19.0.2/24 dev uplink0
ip -n underlay address add 195.201.112.227/32 dev lo
ip -n underlay address add 1.1.1.1/32 dev lo
ip -n underlay address add 194.154.192.101/32 dev lo
ip -n underlay address add 194.154.192.102/32 dev lo
ip -n underlay link set uplink0 up
ip netns exec underlay python3 -u -c '
import socket
import threading
def dns_echo(address):
    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp.bind((address, 53))
    while True:
        payload, peer = udp.recvfrom(512)
        if peer[0] == "198.19.0.1":
            udp.sendto(payload, peer)
for address in ("194.154.192.101", "194.154.192.102"):
    threading.Thread(target=dns_echo, args=(address,), daemon=True).start()
s = socket.socket()
s.bind(("0.0.0.0", 443))
s.listen()
while True:
    c, _ = s.accept()
    c.sendall(b"ok")
    c.close()
' >"$work/tcp-server.log" 2>&1 &
server_pid=$!
sleep 0.2
marked_tcp_probe() {
  python3 -c '
import socket
s = socket.socket()
s.settimeout(2)
s.setsockopt(socket.SOL_SOCKET, socket.SO_MARK, 51871)
s.connect(("195.201.112.227", 443))
assert s.recv(2) == b"ok"
'
}
marked_tcp_probe
# Match NixOS's strict raw-table reverse-path check, including TCP replies.
iptables -t raw -N fallback-rpfilter
iptables -t raw -A PREROUTING -j fallback-rpfilter
iptables -t raw -A fallback-rpfilter -m rpfilter --validmark -j RETURN
iptables -t raw -A fallback-rpfilter -j DROP
sysctl -qw net.ipv4.conf.all.rp_filter=1
ip link add pangolin type dummy
ip link set pangolin up
ip route add 100.96.128.0/20 dev pangolin
private_key=$(wg genkey)
server_key=$(wg genkey)
public_key=$(printf '%s\n' "$server_key" | wg pubkey)
client_public_key=$(printf '%s\n' "$private_key" | wg pubkey)
umask 077
printf '%s\n' "$server_key" > "$work/server.key"
ip -n underlay link add wg-test type wireguard
ip netns exec underlay wg set wg-test private-key "$work/server.key" listen-port 51820 peer "$client_public_key" allowed-ips 10.250.251.2/32
ip -n underlay address add 10.250.251.1/24 dev wg-test
ip -n underlay link set wg-test up
printf '[Interface]\nPrivateKey = %s\nAddress = 10.250.251.2/32\nFwMark = 51871\nMTU = 1280\nTable = off\n[Peer]\nPublicKey = %s\nEndpoint = 198.19.0.2:51820\nAllowedIPs = 0.0.0.0/0\n' "$private_key" "$public_key" > "$work/pg-fallback.conf"
wg-quick up "$work/pg-fallback.conf"
routing_script=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../modules/services/pangolin-fallback-routing.sh")
bash "$routing_script" setup
[[ $(ip -4 route get 2.28.75.245) == *'dev eth0'* ]]
marked_tcp_probe
# A real probe and its replies traverse WireGuard with strict filtering enabled,
# before any catch-all route is promoted. Both remote IPs exist only in this test.
python3 -c '
import socket
s = socket.socket()
s.settimeout(3)
s.bind(("10.250.251.2", 0))
s.connect(("1.1.1.1", 443))
assert s.recv(2) == b"ok"
'
bash "$routing_script" promote
bash "$routing_script" promote
[[ $(ip -4 route get 2.28.75.245) == *'dev pg-fallback'* ]]
[[ $(ip -4 route get 195.201.112.227 mark 51871) == *'dev eth0'* ]]
[[ $(ip -4 route get 100.96.128.11) == *'dev pangolin'* ]]
[[ $(ip -4 route get 198.19.0.2) == *'dev eth0'* ]]
marked_tcp_probe
# The simulated ISP resolver accepts only native-network source addresses.
native_dns_probe() {
  python3 - "$1" <<'PY'
import socket
import sys
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(2)
s.sendto(b"probe", (sys.argv[1], 53))
assert s.recvfrom(512)[0] == b"probe"
PY
}
native_dns_probe 194.154.192.101
printf 'nameserver 194.154.192.102\n' > "$NM_RESOLVCONF"
bash "$routing_script" refresh-dns
[[ $(ip -4 route get 194.154.192.101) == *'dev pg-fallback'* ]]
[[ $(ip -4 route get 194.154.192.102) == *'dev eth0'* ]]
native_dns_probe 194.154.192.102
bash "$routing_script" withdraw
[[ $(ip -4 route get 2.28.75.245) == *'dev eth0'* ]]
bash "$routing_script" cleanup
bash "$routing_script" cleanup
wg-quick down "$work/pg-fallback.conf"
[[ $(ip -4 route get 2.28.75.245) == *'dev eth0'* ]]
[[ $(ip -4 rule show) != *51871* ]]
[[ $(ip -4 rule show) != *10000* ]]
[[ $(ip -4 rule show) != *suppress_prefixlength* ]]
[[ -z $(ip -4 rule show priority 9999) ]]
ip link delete eth0
ip link delete pangolin
kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
ip netns delete underlay
iptables -t raw -D PREROUTING -j fallback-rpfilter
iptables -t raw -F fallback-rpfilter
iptables -t raw -X fallback-rpfilter
printf 'WireGuard routing, marked WSS bypass, and cleanup passed\n'

# Exercise the exact evaluated relay firewall with isolated veth clients.
ip netns add client
ip netns add internet
ip link add wg-relay type veth peer name client0
ip link set client0 netns client
ip address add 10.250.251.1/24 dev wg-relay
ip link set wg-relay up
ip route add 10.250.250.2/32 dev wg-relay
ip -n client link set lo up
ip -n client address add 10.250.251.2/24 dev client0
ip -n client address add 10.250.250.2/32 dev client0
ip -n client link set client0 up
ip -n client route add default via 10.250.251.1
ip link add eth0 type veth peer name internet0
ip link set internet0 netns internet
ip address add 198.19.0.1/24 dev eth0
ip link set eth0 up
ip route add default via 198.19.0.2
ip -n internet link set lo up
ip -n internet address add 198.19.0.2/24 dev internet0
ip -n internet address add 8.8.8.8/32 dev lo
ip -n internet address add 10.33.0.1/32 dev lo
ip -n internet address add 169.254.169.254/32 dev lo
ip -n internet link set internet0 up
ip -n internet route add default via 198.19.0.1
sysctl -qw net.ipv4.ip_forward=1
bash -euc "${FIREWALL_START:?}"
bash -euc "$FIREWALL_START"
ip netns exec client ping -I 10.250.251.2 -c 1 -W 1 8.8.8.8
if ip netns exec client ping -I 10.250.251.2 -c 1 -W 1 10.33.0.1; then exit 1; fi
if ip netns exec client ping -I 10.250.251.2 -c 1 -W 1 169.254.169.254; then exit 1; fi
if ip netns exec client ping -I 10.250.250.2 -c 1 -W 1 8.8.8.8; then exit 1; fi
if ip netns exec internet ping -c 1 -W 1 10.250.251.2; then exit 1; fi
bash -euc "${FIREWALL_STOP:?}"
if ip netns exec client ping -I 10.250.251.2 -c 1 -W 1 8.8.8.8; then exit 1; fi
bash -euc "$FIREWALL_START"
ip netns exec client ping -I 10.250.251.2 -c 1 -W 1 8.8.8.8
printf 'Relay NAT, private/metadata/WSL isolation, inbound filtering, and firewall reload passed\n'
