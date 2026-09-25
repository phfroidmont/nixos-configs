#!/usr/bin/env bash
set -euo pipefail

IP=${IP:-ip}
RELAY_IPV4=${RELAY_IPV4:-195.201.112.227}
NM_RESOLVCONF=${NM_RESOLVCONF:-/run/NetworkManager/resolv.conf}

valid_ipv4() {
  local address=$1 octet
  local -a octets
  IFS=. read -r -a octets <<< "$address"
  [[ ${#octets[@]} -eq 4 ]] || return 1
  for octet in "${octets[@]}"; do
    [[ $octet =~ ^(0|[1-9][0-9]{0,2})$ ]] || return 1
    (( 10#$octet <= 255 )) || return 1
  done
}

list_dns_rules() {
  local output line address
  output=$("$IP" -4 rule show priority 9999) || return 1
  while IFS= read -r line; do
    if [[ $line =~ ^9999:[[:space:]]+from[[:space:]]+all[[:space:]]+to[[:space:]]+([0-9.]+)(/32)?[[:space:]]+lookup[[:space:]]+main[[:space:]]*$ ]]; then
      address=${BASH_REMATCH[1]}
      valid_ipv4 "$address" && printf '%s\n' "$address"
    fi
  done <<< "$output"
  return 0
}

refresh_dns() {
  local line keyword address extra current_output
  local -A desired=() current=()

  if [[ ! -r $NM_RESOLVCONF ]]; then
    printf 'pangolin-fallback: cannot read NetworkManager resolver file %s\n' "$NM_RESOLVCONF" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line%%;*}
    read -r keyword address extra <<< "$line"
    if [[ $keyword == nameserver && -n $address && -z $extra ]]; then
      if valid_ipv4 "$address" && [[ $address != 127.* && $address != 100.90.* && $address != 100.96.* ]]; then
        desired["$address"]=1
      fi
    fi
  done < "$NM_RESOLVCONF"

  if [[ ${#desired[@]} -eq 0 ]]; then
    printf 'pangolin-fallback: no usable native IPv4 DNS servers; keeping native default routing\n' >&2
    return 1
  fi

  current_output=$(list_dns_rules) || {
    printf 'pangolin-fallback: failed to query DNS routing exceptions\n' >&2
    return 1
  }
  while IFS= read -r address; do
    [[ -z $address ]] || current["$address"]=1
  done <<< "$current_output"

  # Keep old exceptions until every new one is installed.
  for address in "${!desired[@]}"; do
    if [[ ! -v current["$address"] ]]; then
      "$IP" -4 rule add priority 9999 to "$address/32" table main || return 1
    fi
  done
  for address in "${!current[@]}"; do
    if [[ ! -v desired["$address"] ]]; then
      "$IP" -4 rule del priority 9999 to "$address/32" table main || return 1
    fi
  done
}

cleanup_dns() {
  local output address status=0
  output=$(list_dns_rules) || return 1
  while IFS= read -r address; do
    if [[ -n $address ]] && ! "$IP" -4 rule del priority 9999 to "$address/32" table main 2>/dev/null; then
      status=1
    fi
  done <<< "$output"
  return "$status"
}

withdraw() {
  local rule
  rule=$("$IP" -4 rule show priority 10003) || return 1
  if [[ $rule == *'lookup 51871'* ]]; then
    "$IP" -4 rule del priority 10003 not fwmark 51871 table 51871 || return 1
    printf 'pangolin-fallback: restored native default routing\n' >&2
  fi
}

cleanup() {
  local status=0
  withdraw || status=1
  cleanup_dns || status=1
  "$IP" -4 rule del priority 10002 from 10.250.251.2/32 table 51871 2>/dev/null || true
  "$IP" -4 rule del priority 10001 table main suppress_prefixlength 0 2>/dev/null || true
  "$IP" -4 rule del priority 10000 fwmark 51871 table main 2>/dev/null || true
  # Remove the pre-marking relay exception when upgrading an active setup.
  "$IP" -4 rule del priority 10000 to "$RELAY_IPV4/32" table main 2>/dev/null || true
  "$IP" -4 route flush table 51871 2>/dev/null || true
  return "$status"
}

case "${1:-}" in
  setup)
    trap cleanup ERR
    refresh_dns
    "$IP" -4 route replace default dev pg-fallback table 51871
    # Explicit priority beats the probe's source rule for marked WSS replies.
    "$IP" -4 rule add priority 10000 fwmark 51871 table main
    "$IP" -4 rule del priority 10000 to "$RELAY_IPV4/32" table main 2>/dev/null || true
    "$IP" -4 rule add priority 10001 table main suppress_prefixlength 0
    # Probe traffic and its reverse-path checks work before default takeover.
    "$IP" -4 rule add priority 10002 from 10.250.251.2/32 table 51871
    ;;
  promote)
    rule=$("$IP" -4 rule show priority 10003)
    if [[ -z $rule ]]; then
      "$IP" -4 rule add priority 10003 not fwmark 51871 table 51871
      printf 'pangolin-fallback: enabling verified fallback default route\n' >&2
    elif [[ $rule != *'lookup 51871'* ]]; then
      printf 'pangolin-fallback: routing priority 10003 is already in use\n' >&2
      exit 1
    fi
    ;;
  refresh-dns) refresh_dns ;;
  withdraw) withdraw ;;
  cleanup) cleanup ;;
  *) printf 'usage: %s setup|refresh-dns|promote|withdraw|cleanup\n' "$0" >&2; exit 2 ;;
esac
