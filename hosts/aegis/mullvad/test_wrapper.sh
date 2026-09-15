#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
  echo "usage: test_wrapper.sh /path/to/mullvad-gw" >&2
  exit 2
fi

wrapper="$1"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export TEST_LOG="$root/systemctl.log"
export TEST_ACTIVE="$root/active"
export TEST_IPTABLES_STATE="$root/iptables-state"
export TEST_METADATA="$root/metadata.json"

cat > "$root/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_LOG"
if [[ "$1" == "is-active" ]]; then
  [[ -e "$TEST_ACTIVE" ]]
fi
EOF
cat > "$root/iptables" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state="$TEST_IPTABLES_STATE"
if [[ "$*" == *"-t mangle"* ]]; then
  if [[ "$3" != -[CID] || "$4" != FORWARD || "$*" != *"-p tcp --tcp-flags SYN,RST SYN -j TCPMSS"* ]]; then
    echo "unexpected MSS match or chain: $*" >&2
    exit 2
  fi
fi
if [[ "$*" == *"-t mangle"* && "$*" == *"-i br-lan -o mullvad"* ]]; then
  [[ "$*" == *"--clamp-mss-to-pmtu"* ]]
  state="$state.mss.out"
elif [[ "$*" == *"-t mangle"* && "$*" == *"-i mullvad -o br-lan"* ]]; then
  [[ "$*" == *"--set-mss 1240"* ]]
  state="$state.mss.in"
fi
count=0
[[ -e "$state" ]] && read -r count < "$state"
if [[ "$*" == *" -C "* || "$1" == "-C" ]]; then
  (( count > 0 ))
elif [[ "$*" == *" -D "* || "$1" == "-D" ]]; then
  if (( count > 1 )); then
    printf '%s\n' "$((count - 1))" > "$state"
  else
    rm -f "$state"
  fi
else
  printf '%s\n' "$((count + 1))" > "$state"
fi
EOF
cat > "$root/fetch.py" <<'EOF'
import os
import sys
sys.stdout.buffer.write(open(os.environ["TEST_METADATA"], "rb").read())
EOF
printf '#!/usr/bin/env bash\nexit 1\n' > "$root/unhealthy"
sed -i "1c#!$BASH" "$root/systemctl" "$root/iptables" "$root/unhealthy"
chmod +x "$root/systemctl" "$root/iptables" "$root/unhealthy"

key='AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8='
base="$root/mullvad"
mkdir -m 700 "$base"
cat > "$base/identity.conf" <<EOF
[Interface]
PrivateKey = $key
Address = 10.1.2.3/32
EOF
chmod 600 "$base/identity.conf"

write_metadata() {
  endpoint="$1"
  cat > "$TEST_METADATA" <<EOF
{"locations":{"ch-zrh":{"country":"Switzerland"}},"wireguard":{"ipv4_gateway":"10.64.0.1","port_ranges":[[4000,60000]],"relays":[{"hostname":"ch-zrh-wg-001","location":"ch-zrh","active":true,"public_key":"$key","ipv4_addr_in":"$endpoint"}]}}
EOF
}

run_wrapper() {
  MULLVAD_BASE_DIR="$base" \
  MULLVAD_LOCK_FILE="$root/refresh.lock" \
  MULLVAD_LOCK_TIMEOUT=1 \
  MULLVAD_SYSTEMCTL="$root/systemctl" \
  MULLVAD_IPTABLES="$root/iptables" \
  MULLVAD_FETCH_METADATA="$root/fetch.py" \
  MULLVAD_FILE_OWNER="$(id -un)" \
  MULLVAD_FILE_GROUP="$(id -gn)" \
  "$wrapper" "$@"
}

# Publishing while inactive must never start the tunnel.
write_metadata 192.0.2.1
run_wrapper refresh >/dev/null
[[ -f "$base/current-ipv4.conf" ]]
[[ -f "$TEST_LOG" ]]
if grep -q '^restart ' "$TEST_LOG"; then
  echo "refresh started an inactive tunnel" >&2
  exit 1
fi

# Legacy spelling and dual-stack DNS are normalized in the runtime config.
selected="$base/servers/ch-zrh-wg-001.conf"
cat > "$selected" <<EOF
   [interface]$(printf '   ')
PrivateKey = $key
address = 10.1.2.3/32,fc00::1/128
dns = fc00::2,10.64.0.1
mTu = 1400
 MTU = 1300
FWMARK = 7
fwmark=8
[Peer]
PublicKey = $key
allowedips = 0.0.0.0/0,::/0
Endpoint = 192.0.2.1:51820
EOF
rm -f "$TEST_ACTIVE"
: > "$TEST_LOG"
run_wrapper switch ch-zrh-wg-001 >/dev/null
runtime="$base/current-ipv4.conf"
grep -q '^\[Interface\]$' "$runtime"
grep -q '^FwMark = 51820$' "$runtime"
grep -q '^MTU = 1280$' "$runtime"
[[ "$(grep -c '^FwMark = ' "$runtime")" == 1 ]]
[[ "$(grep -c '^MTU = ' "$runtime")" == 1 ]]
grep -q '^DNS = 10.64.0.1$' "$runtime"
grep -q '^Address = 10.1.2.3/32$' "$runtime"
grep -q '^AllowedIPs = 0.0.0.0/0$' "$runtime"
if grep -Eqi 'fc00::|::/0|^[[:space:]]*(mtu|fwmark)[[:space:]]*=[[:space:]]*(1400|7)' "$runtime"; then
  echo "runtime config retained an IPv6 or unpinned directive" >&2
  exit 1
fi
if grep -q '^restart ' "$TEST_LOG"; then
  echo "switch started an inactive tunnel" >&2
  exit 1
fi

# A source without an Interface section must not replace the runtime config.
cp "$runtime" "$root/runtime.before"
printf '[Peer]\nPublicKey = %s\n' "$key" > "$selected"
if run_wrapper switch ch-zrh-wg-001 >/dev/null 2>&1; then
  echo "config without an Interface section unexpectedly rendered" >&2
  exit 1
fi
cmp -s "$runtime" "$root/runtime.before"

# Refresh restores the generated profile while inactive and renders it without starting.
write_metadata 192.0.2.9
: > "$TEST_LOG"
run_wrapper refresh >/dev/null
if grep -q '^restart ' "$TEST_LOG"; then
  echo "changed refresh started an inactive tunnel" >&2
  exit 1
fi
grep -q '^Endpoint = 192.0.2.9:' "$runtime"

# An unchanged selected profile must reassert firewall rules without restarting.
: > "$TEST_ACTIVE"
: > "$TEST_LOG"
rm -f "$TEST_IPTABLES_STATE" "$TEST_IPTABLES_STATE.mss.out" "$TEST_IPTABLES_STATE.mss.in"
printf '1\n' > "$TEST_IPTABLES_STATE.mss.out"
MULLVAD_HEALTH_COMMAND="$root/unhealthy" run_wrapper status > "$root/partial-status.out"
grep -q '^mss-clamp: disabled$' "$root/partial-status.out"
run_wrapper refresh >/dev/null
if grep -q '^restart ' "$TEST_LOG"; then
  echo "refresh restarted an unchanged tunnel" >&2
  exit 1
fi
[[ -e "$TEST_IPTABLES_STATE" ]]
[[ "$(<"$TEST_IPTABLES_STATE.mss.out")" == 1 ]]
[[ "$(<"$TEST_IPTABLES_STATE.mss.in")" == 1 ]]

# Reassertion is idempotent, and down removes duplicate rules in both directions.
run_wrapper refresh >/dev/null
[[ "$(<"$TEST_IPTABLES_STATE.mss.out")" == 1 ]]
[[ "$(<"$TEST_IPTABLES_STATE.mss.in")" == 1 ]]
printf '2\n' > "$TEST_IPTABLES_STATE.mss.out"
printf '2\n' > "$TEST_IPTABLES_STATE.mss.in"
run_wrapper down >/dev/null
[[ ! -e "$TEST_IPTABLES_STATE.mss.out" ]]
[[ ! -e "$TEST_IPTABLES_STATE.mss.in" ]]

# A changed active profile restarts, reports failed health, and leaves the kill switch set.
write_metadata 192.0.2.2
set +e
MULLVAD_HEALTH_COMMAND="$root/unhealthy" run_wrapper refresh >"$root/failed.out" 2>&1
status=$?
set -e
[[ $status == 2 ]]
grep -q '^restart ' "$TEST_LOG"
grep -q 'health check failed' "$root/failed.out"
[[ -e "$TEST_IPTABLES_STATE" ]]

# Malformed metadata must preserve the previously published generation.
before="$(readlink -f "$base/servers")"
printf '{not-json' > "$TEST_METADATA"
if run_wrapper refresh >/dev/null 2>&1; then
  echo "malformed metadata unexpectedly succeeded" >&2
  exit 1
fi
[[ "$(readlink -f "$base/servers")" == "$before" ]]

# Lock contention is bounded and diagnosed.
( flock 8; sleep 3 ) 8>"$root/refresh.lock" &
holder=$!
sleep 0.2
set +e
run_wrapper refresh >"$root/locked.out" 2>&1
status=$?
set -e
wait "$holder"
[[ $status == 75 ]]
grep -q 'Timed out after 1 seconds' "$root/locked.out"

echo "wrapper harness: OK"
