#!/usr/bin/env bash
set -euo pipefail

script=${1:?routing script required}
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

call_line() {
  local needle=$1 line number=0
  while IFS= read -r line; do
    (( number += 1 ))
    if [[ $line == *"$needle"* ]]; then
      printf '%s\n' "$number"
      return 0
    fi
  done < "$test_dir/calls"
  return 1
}

export MOCK_DIR="$test_dir"
export IP="$test_dir/ip"
export NM_RESOLVCONF="$test_dir/resolv.conf"
printf '#!%s\n' "$BASH" > "$IP"
cat >> "$IP" <<'EOF'
set -eu
printf '%s\n' "$*" >> "$MOCK_DIR/calls"
case "$*" in
  '-4 rule show priority 9999')
    [[ ! -e "$MOCK_DIR/dns-show-fails" ]] || exit 1
    [[ ! -e "$MOCK_DIR/unrelated-rule" ]] || printf '9999: from 192.0.2.0/24 lookup 12345\n'
    if [[ -e "$MOCK_DIR/dns-rules" ]]; then
      while IFS= read -r address; do
        [[ -z $address ]] || printf '9999: from all to %s lookup main\n' "$address"
      done < "$MOCK_DIR/dns-rules"
    fi
    ;;
  '-4 rule add priority 9999 to '*'/32 table main')
    address=${7%/32}
    printf '%s\n' "$address" >> "$MOCK_DIR/dns-rules"
    ;;
  '-4 rule del priority 9999 to '*'/32 table main')
    address=${7%/32}
    tmp="$MOCK_DIR/dns-rules.new"
    : > "$tmp"
    while IFS= read -r existing; do
      [[ $existing == "$address" ]] || printf '%s\n' "$existing" >> "$tmp"
    done < "$MOCK_DIR/dns-rules"
    mv "$tmp" "$MOCK_DIR/dns-rules"
    ;;
  '-4 rule show priority 10003')
    [[ ! -e "$MOCK_DIR/show-fails" ]] || exit 1
    if [[ -e "$MOCK_DIR/rule" ]]; then printf '%s\n' "$(<"$MOCK_DIR/rule")"; fi
    ;;
  '-4 rule add priority 10003 not fwmark 51871 table 51871')
    printf '10003: from all not fwmark 51871 lookup 51871\n' > "$MOCK_DIR/rule"
    ;;
  '-4 rule del priority 10003 not fwmark 51871 table 51871')
    [[ ! -e "$MOCK_DIR/delete-fails" ]] || exit 1
    rm -f "$MOCK_DIR/rule"
    ;;
esac
EOF
chmod +x "$IP"

cat > "$NM_RESOLVCONF" <<'EOF'
# Supplied by NetworkManager
nameserver 194.154.192.101
nameserver 194.154.192.102 # trailing comment is valid
nameserver 194.154.192.101
nameserver 2001:db8::53
nameserver 100.96.128.1
nameserver 100.96.128.11
nameserver 100.90.0.1
nameserver 999.1.1.1
nameserver 127.0.0.53
nameserver 010.1.1.1
search example.test
EOF
printf '194.154.192.101\n192.168.215.193\n' > "$test_dir/dns-rules"
touch "$test_dir/unrelated-rule"
: > "$test_dir/calls"
bash "$script" refresh-dns
[[ $(<"$test_dir/dns-rules") == $'194.154.192.101\n194.154.192.102' ]]
calls=$(<"$test_dir/calls")
[[ $calls == *'-4 rule add priority 9999 to 194.154.192.102/32 table main'* ]]
[[ $calls == *'-4 rule del priority 9999 to 192.168.215.193/32 table main'* ]]
[[ $calls != *'2001:db8'* && $calls != *'100.96.128.1'* && $calls != *'100.96.128.11'* ]]
[[ $calls != *'100.90.0.1'* && $calls != *'999.1.1.1'* ]]
[[ $calls != *'127.0.0.53'* && $calls != *'010.1.1.1'* ]]
[[ $calls != *'192.0.2.0/24'* ]]
add_line=$(call_line 'rule add priority 9999')
delete_line=$(call_line 'rule del priority 9999')
(( add_line < delete_line ))

# Refresh is idempotent and leaves unrelated rules at the shared priority alone.
: > "$test_dir/calls"
bash "$script" refresh-dns
[[ $(<"$test_dir/calls") == '-4 rule show priority 9999' ]]

# Setup installs the current physical-DNS exceptions before configuring fallback.
: > "$test_dir/calls"
bash "$script" setup
dns_query_line=$(call_line 'rule show priority 9999')
fallback_route_line=$(call_line 'route replace default dev pg-fallback')
(( dns_query_line < fallback_route_line ))

# Read and kernel-query failures preserve the currently installed exceptions.
mv "$NM_RESOLVCONF" "$NM_RESOLVCONF.saved"
: > "$test_dir/calls"
if bash "$script" refresh-dns; then
  printf 'refresh accepted an unreadable resolver file\n' >&2
  exit 1
fi
[[ ! -s "$test_dir/calls" ]]
mv "$NM_RESOLVCONF.saved" "$NM_RESOLVCONF"
touch "$test_dir/dns-show-fails"
: > "$test_dir/calls"
if bash "$script" refresh-dns; then
  printf 'refresh hid a failed DNS-rule query\n' >&2
  exit 1
fi
[[ $(<"$test_dir/dns-rules") == $'194.154.192.101\n194.154.192.102' ]]
[[ $(<"$test_dir/calls") == '-4 rule show priority 9999' ]]
rm "$test_dir/dns-show-fails"

# A temporary empty/stub-only DNS configuration must not erase valid exceptions.
mv "$NM_RESOLVCONF" "$NM_RESOLVCONF.saved"
printf 'nameserver 127.0.0.53\nnameserver 100.96.128.1\n' > "$NM_RESOLVCONF"
: > "$test_dir/calls"
if bash "$script" refresh-dns; then
  printf 'refresh accepted a stub-only resolver configuration\n' >&2
  exit 1
fi
[[ ! -s "$test_dir/calls" ]]
[[ $(<"$test_dir/dns-rules") == $'194.154.192.101\n194.154.192.102' ]]
mv "$NM_RESOLVCONF.saved" "$NM_RESOLVCONF"

bash "$script" withdraw
bash "$script" promote
[[ -e "$test_dir/rule" ]]
: > "$test_dir/calls"
bash "$script" promote
[[ $(<"$test_dir/calls") == '-4 rule show priority 10003' ]]
bash "$script" withdraw
[[ ! -e "$test_dir/rule" ]]

# A failed rules query is an error, not evidence that capture is absent.
touch "$test_dir/show-fails"
if bash "$script" withdraw; then
  printf 'withdraw hid a failed rules query\n' >&2
  exit 1
fi
rm "$test_dir/show-fails"

# Teardown attempts all other cleanup even when capture withdrawal fails.
bash "$script" promote
touch "$test_dir/delete-fails"
: > "$test_dir/calls"
if bash "$script" cleanup; then
  printf 'cleanup hid a failed capture-rule deletion\n' >&2
  exit 1
fi
calls=$(<"$test_dir/calls")
[[ $calls == *'-4 rule del priority 9999 to 194.154.192.101/32 table main'* ]]
[[ $calls == *'-4 rule del priority 9999 to 194.154.192.102/32 table main'* ]]
[[ $calls == *'-4 rule del priority 10002 from 10.250.251.2/32 table 51871'* ]]
[[ $calls == *'-4 rule del priority 10001 table main suppress_prefixlength 0'* ]]
[[ $calls == *'-4 rule del priority 10000 to 195.201.112.227/32 table main'* ]]
[[ $calls == *'-4 route flush table 51871'* ]]
rm "$test_dir/delete-fails"
bash "$script" cleanup

# Never replace another user's rule at the reserved capture priority.
printf '10003: from all lookup 12345\n' > "$test_dir/rule"
if bash "$script" promote; then
  printf 'promotion ignored a conflicting rule\n' >&2
  exit 1
fi
[[ $(<"$test_dir/rule") == '10003: from all lookup 12345' ]]
printf 'pangolin-fallback routing tests passed\n'
