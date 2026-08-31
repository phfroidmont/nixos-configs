#!/usr/bin/env bash

set -euo pipefail

: "${FOS_BIN:?set FOS_BIN to the packaged fos executable}"

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
flake="$test_root/flake"
nh_log="$test_root/nh.log"
auth_log="$test_root/auth.log"
vpn_log="$test_root/vpn.log"
mkdir -p "$fake_bin" "$flake"
touch "$flake/flake.nix" "$nh_log" "$auth_log" "$vpn_log"

printf '#!%s\n' "$BASH" >"$fake_bin/nix"
cat >>"$fake_bin/nix" <<'EOF'
set -euo pipefail
printf '%s\n' aegis nixos-desktop stellaris wsl
EOF

printf '#!%s\n' "$BASH" >"$fake_bin/hostname"
cat >>"$fake_bin/hostname" <<'EOF'
set -euo pipefail
printf '%s\n' stellaris
EOF

printf '#!%s\n' "$BASH" >"$fake_bin/nh"
cat >>"$fake_bin/nh" <<'EOF'
set -euo pipefail
printf '%s\n' "$*" >>"$NH_LOG"
EOF

printf '#!%s\n' "$BASH" >"$fake_bin/auth"
cat >>"$fake_bin/auth" <<'EOF'
set -euo pipefail
printf '%s\n' "$*" >>"$AUTH_LOG"
EOF

printf '#!%s\n' "$BASH" >"$fake_bin/vpn"
cat >>"$fake_bin/vpn" <<'EOF'
set -euo pipefail
printf '%s\n' "$*" >>"$VPN_LOG"
if [[ ${1:-} == list ]]; then
  printf '%s\n' '  nl-ams-wg-001' '* be-bru-wg-001'
fi
EOF

chmod +x "$fake_bin"/*

unset NH_OS_FLAKE
export NH_FLAKE="$flake"
export NH_LOG="$nh_log"
export AUTH_LOG="$auth_log"
export VPN_LOG="$vpn_log"
export FOS_NIX="$fake_bin/nix"
export FOS_HOSTNAME="$fake_bin/hostname"
export FOS_NH="$fake_bin/nh"
export FOS_AUTH_COMMAND="$fake_bin/auth"
export FOS_VPN_COMMAND="$fake_bin/vpn"

reset_logs() {
  : >"$nh_log"
  : >"$auth_log"
  : >"$vpn_log"
}

assert_nh_log() {
  local expected=$1
  [[ $(<"$nh_log") == "$expected" ]]
}

assert_failure() {
  if "$FOS_BIN" "$@" >/dev/null 2>&1; then
    printf 'Expected fos command to fail: %s\n' "$*" >&2
    exit 1
  fi
}

help_output=$("$FOS_BIN")
grep -Fq 'Froidmont Operating System command center' <<<"$help_output"
grep -Fq 'update [INPUT...]' <<<"$help_output"

reset_logs
"$FOS_BIN" switch --help >/dev/null
assert_nh_log ''

hosts=$("$FOS_BIN" hosts)
[[ $hosts == $'aegis\nnixos-desktop\nstellaris\nwsl' ]]

reset_logs
"$FOS_BIN" build >/dev/null 2>&1
assert_nh_log "os build $flake -H stellaris"

reset_logs
"$FOS_BIN" build aegis >/dev/null 2>&1
assert_nh_log "os build $flake -H aegis"

reset_logs
assert_failure build aegis-installer
assert_nh_log ''

for action in test switch boot; do
  reset_logs
  "$FOS_BIN" "$action" >/dev/null 2>&1
  assert_nh_log "os $action $flake -H stellaris --ask"

  reset_logs
  assert_failure "$action" aegis
  assert_nh_log ''
done

reset_logs
"$FOS_BIN" update >/dev/null 2>&1
assert_nh_log "os build $flake -H stellaris --update"

reset_logs
"$FOS_BIN" update nixpkgs home-manager >/dev/null 2>&1
assert_nh_log "os build $flake -H stellaris --update-input nixpkgs --update-input home-manager"

reset_logs
assert_failure update --all
assert_nh_log ''

reset_logs
"$FOS_BIN" generations >/dev/null 2>&1
assert_nh_log 'os info'

reset_logs
"$FOS_BIN" rollback >/dev/null 2>&1
assert_nh_log 'os rollback --ask'

reset_logs
"$FOS_BIN" rollback 12 >/dev/null 2>&1
assert_nh_log 'os rollback --to 12 --ask'

reset_logs
assert_failure rollback latest
assert_nh_log ''

reset_logs
"$FOS_BIN" auth refresh >/dev/null 2>&1
[[ $(<"$auth_log") == '' ]]

reset_logs
"$FOS_BIN" auth refresh gitlab.example.com >/dev/null 2>&1
[[ $(<"$auth_log") == 'gitlab.example.com' ]]

reset_logs
"$FOS_BIN" vpn status >/dev/null 2>&1
[[ $(<"$vpn_log") == status ]]

reset_logs
"$FOS_BIN" vpn switch nl-ams-wg-001 >/dev/null 2>&1
[[ $(<"$vpn_log") == 'switch nl-ams-wg-001' ]]

reset_logs
assert_failure vpn switch
[[ $(<"$vpn_log") == '' ]]

reset_logs
assert_failure unknown
assert_nh_log ''

saved_flake=$NH_FLAKE
unset NH_FLAKE
assert_failure build
reset_logs
"$FOS_BIN" generations >/dev/null 2>&1
assert_nh_log 'os info'
export NH_FLAKE=$saved_flake

printf '%s\n' 'fos tests passed'
