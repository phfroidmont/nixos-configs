#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT=${1:-$ROOT/modules/services/pangolin-fallback.sh}
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

export MOCK_DIR="$TEST_DIR/state"
mkdir -p "$MOCK_DIR"

printf '#!%s\n' "$BASH" >"$TEST_DIR/systemctl"
cat >>"$TEST_DIR/systemctl" <<'EOF'
set -eu
command=$1
shift
case "$command" in
  is-active)
    if [[ ${1:-} == --quiet ]]; then shift; fi
    unit=$1
    [[ -e "$MOCK_DIR/$unit" ]]
    ;;
  start)
    printf 'start %s\n' "$*" >>"$MOCK_DIR/calls"
    printf 'systemctl start %s\n' "$*" >>"$MOCK_DIR/events"
    if [[ -e "$MOCK_DIR/start-fails" ]]; then
      touch "$MOCK_DIR/wstunnel-pangolin-fallback.service"
      exit 1
    fi
    touch "$MOCK_DIR/$1" "$MOCK_DIR/wstunnel-pangolin-fallback.service"
    ;;
  stop)
    printf 'stop %s\n' "$*" >>"$MOCK_DIR/calls"
    printf 'systemctl stop %s\n' "$*" >>"$MOCK_DIR/events"
    for unit in "$@"; do rm -f "$MOCK_DIR/$unit"; done
    ;;
  *) exit 2 ;;
esac
EOF

printf '#!%s\n' "$BASH" >"$TEST_DIR/curl"
cat >>"$TEST_DIR/curl" <<'EOF'
set -eu
printf '%s\n' "$*" >>"$MOCK_DIR/curl-calls"
if [[ -e "$MOCK_DIR/probe-removes-pangolin" ]]; then
  rm -f "$MOCK_DIR/pangolin.service"
fi
if [[ -e "$MOCK_DIR/probe-changes-primary" ]]; then
  printf 'other\n' >"$MOCK_DIR/primary-uuid"
fi
[[ ! -e "$MOCK_DIR/probe-fails" ]]
EOF

printf '#!%s\n' "$BASH" >"$TEST_DIR/routing"
cat >>"$TEST_DIR/routing" <<'EOF'
set -eu
printf '%s\n' "$*" >>"$MOCK_DIR/routing-calls"
printf 'routing %s\n' "$*" >>"$MOCK_DIR/events"
if [[ $1 == promote && -e "$MOCK_DIR/promote-fails" ]]; then exit 1; fi
if [[ $1 == refresh-dns && -e "$MOCK_DIR/dns-refresh-fails" ]]; then exit 1; fi
EOF

printf '#!%s\n' "$BASH" >"$TEST_DIR/busctl"
cat >>"$TEST_DIR/busctl" <<'EOF'
set -eu
if [[ $(<"$MOCK_DIR/nm-mode") == failure ]]; then exit 1; fi
if [[ ${*: -1} == PrimaryConnection ]]; then
  if [[ $(<"$MOCK_DIR/nm-mode") == offline ]]; then
    printf 'o "/"\n'
  else
    printf 'o "/org/freedesktop/NetworkManager/ActiveConnection/1"\n'
  fi
else
  printf 's "%s"\n' "$(<"$MOCK_DIR/primary-uuid")"
fi
EOF
chmod +x "$TEST_DIR/systemctl" "$TEST_DIR/busctl" "$TEST_DIR/curl" "$TEST_DIR/routing"

export SYSTEMCTL="$TEST_DIR/systemctl"
export BUSCTL="$TEST_DIR/busctl"
export CURL="$TEST_DIR/curl"
export ROUTING="$TEST_DIR/routing"
export KEY_FILE="$TEST_DIR/private-key"
touch "$KEY_FILE" "$MOCK_DIR/pangolin.service"
printf 'online\n' >"$MOCK_DIR/nm-mode"
printf 'selected\n' >"$MOCK_DIR/primary-uuid"

reconcile() {
  bash "$SCRIPT" selected
}

clear_calls() {
  : >"$MOCK_DIR/calls"
  : >"$MOCK_DIR/curl-calls"
  : >"$MOCK_DIR/routing-calls"
  : >"$MOCK_DIR/events"
}

assert_calls() {
  local expected=$1
  local actual
  actual=$(<"$MOCK_DIR/calls")
  [[ $actual == "$expected" ]] || {
    printf 'expected calls: %q\nactual calls:   %q\n' "$expected" "$actual" >&2
    exit 1
  }
}

assert_file() {
  local file=$1
  local expected=$2
  local actual
  actual=$(<"$MOCK_DIR/$file")
  [[ $actual == "$expected" ]] || {
    printf '%s: expected: %q\nactual:   %q\n' "$file" "$expected" "$actual" >&2
    exit 1
  }
}

# A selected primary starts the base units, proves source-address egress, and promotes routing.
clear_calls
reconcile
assert_calls 'start wg-quick-pg-fallback.service'
assert_file routing-calls $'withdraw\nrefresh-dns\npromote'
assert_file curl-calls "--noproxy * --ipv4 --interface 10.250.251.2 --connect-timeout 2 --max-time 3 --fail --silent --show-error --output /dev/null https://1.1.1.1/"

# Healthy active units are not restarted; routing promotion remains idempotent in the helper.
clear_calls
reconcile
assert_calls ''
assert_file routing-calls $'refresh-dns\npromote'

# A failed health probe withdraws capture but leaves both base units up for the next retry.
touch "$MOCK_DIR/probe-fails"
clear_calls
reconcile
assert_calls ''
assert_file routing-calls $'refresh-dns\nwithdraw'
[[ -e "$MOCK_DIR/wg-quick-pg-fallback.service" ]]
[[ -e "$MOCK_DIR/wstunnel-pangolin-fallback.service" ]]
rm "$MOCK_DIR/probe-fails"

# An unselected primary stops the fallback.
printf 'other\n' >"$MOCK_DIR/primary-uuid"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file routing-calls 'withdraw'

# An idle unselected connection only asks the idempotent helper to withdraw.
clear_calls
reconcile
assert_calls ''
assert_file routing-calls 'withdraw'
assert_file curl-calls ''

# A simultaneous selected secondary does not matter when the actual primary is unselected.
touch "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service"
printf 'phone-primary\n' >"$MOCK_DIR/primary-uuid"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file routing-calls 'withdraw'

# Offline NetworkManager state fails closed.
touch "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service"
printf 'offline\n' >"$MOCK_DIR/nm-mode"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file routing-calls 'withdraw'

# Manually stopping Pangolin also causes the fallback to stop.
touch "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service"
rm "$MOCK_DIR/pangolin.service"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file events $'routing withdraw\nsystemctl stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'

# A D-Bus read failure fails closed.
touch "$MOCK_DIR/pangolin.service" "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service"
printf 'failure\n' >"$MOCK_DIR/nm-mode"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file routing-calls 'withdraw'

# A missing runtime key fails closed without attempting to generate one.
touch "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service"
printf 'online\n' >"$MOCK_DIR/nm-mode"
printf 'selected\n' >"$MOCK_DIR/primary-uuid"
rm "$KEY_FILE"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file routing-calls 'withdraw'

# A fresh network connection after an earlier stop starts fallback again.
touch "$KEY_FILE"
clear_calls
reconcile
assert_calls 'start wg-quick-pg-fallback.service'
assert_file routing-calls $'withdraw\nrefresh-dns\npromote'

# A partial transport failure is cleaned up before retrying.
rm "$MOCK_DIR/wstunnel-pangolin-fallback.service"
clear_calls
reconcile
assert_calls $'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service\nstart wg-quick-pg-fallback.service'
assert_file routing-calls $'withdraw\nrefresh-dns\npromote'

# Losing the selected primary after a successful probe tears down instead of promoting.
touch "$MOCK_DIR/probe-changes-primary"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file routing-calls $'refresh-dns\nwithdraw'
rm "$MOCK_DIR/probe-changes-primary"
printf 'selected\n' >"$MOCK_DIR/primary-uuid"

# Pangolin stopping during the probe likewise tears down and never promotes.
touch "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service" "$MOCK_DIR/probe-removes-pangolin"
clear_calls
reconcile
assert_calls 'stop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
assert_file routing-calls $'refresh-dns\nwithdraw'
rm "$MOCK_DIR/probe-removes-pangolin"
touch "$MOCK_DIR/pangolin.service"

# Failed WireGuard startup must not leave the WebSocket service running.
rm -f "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service"
touch "$MOCK_DIR/start-fails"
clear_calls
if reconcile; then
  printf 'expected WireGuard startup failure\n' >&2
  exit 1
fi
assert_calls $'start wg-quick-pg-fallback.service\nstop wg-quick-pg-fallback.service wstunnel-pangolin-fallback.service'
[[ ! -e "$MOCK_DIR/wstunnel-pangolin-fallback.service" ]]
assert_file routing-calls $'withdraw\nwithdraw'

# Promotion errors fail open: report failure, withdraw capture, and keep retryable base units.
rm "$MOCK_DIR/start-fails"
touch "$MOCK_DIR/wg-quick-pg-fallback.service" "$MOCK_DIR/wstunnel-pangolin-fallback.service" "$MOCK_DIR/promote-fails"
clear_calls
if reconcile; then
  printf 'expected routing promotion failure\n' >&2
  exit 1
fi
assert_calls ''
assert_file routing-calls $'refresh-dns\npromote\nwithdraw'
[[ -e "$MOCK_DIR/wg-quick-pg-fallback.service" ]]
[[ -e "$MOCK_DIR/wstunnel-pangolin-fallback.service" ]]

# If native DNS routes cannot be refreshed, withdraw capture without probing.
rm "$MOCK_DIR/promote-fails"
touch "$MOCK_DIR/dns-refresh-fails"
clear_calls
if reconcile; then
  printf 'expected native DNS refresh failure\n' >&2
  exit 1
fi
assert_file routing-calls $'refresh-dns\nwithdraw'
assert_file curl-calls ''

printf 'pangolin-fallback tests passed\n'
