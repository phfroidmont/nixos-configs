#!/usr/bin/env bash

set -u

SYSTEMCTL=${SYSTEMCTL:-systemctl}
BUSCTL=${BUSCTL:-busctl}
KEY_FILE=${KEY_FILE:-/etc/secrets/wg-stellaris-fallback.key}
WG_UNIT=${WG_UNIT:-wg-quick-pg-fallback.service}
WSTUNNEL_UNIT=${WSTUNNEL_UNIT:-wstunnel-pangolin-fallback.service}
PANGOLIN_UNIT=${PANGOLIN_UNIT:-pangolin.service}
CURL=${CURL:-curl}
ROUTING=${ROUTING:-pangolin-fallback-routing}

log() {
  printf 'pangolin-fallback: %s\n' "$*" >&2
}

stop_fallback() {
  local failed=false

  if ! "$ROUTING" withdraw; then
    log "failed to withdraw fallback routing"
    failed=true
  fi

  if "$SYSTEMCTL" is-active --quiet "$WG_UNIT" ||
    "$SYSTEMCTL" is-active --quiet "$WSTUNNEL_UNIT"; then
    log "stopping fallback"
    if ! "$SYSTEMCTL" stop "$WG_UNIT" "$WSTUNNEL_UNIT"; then
      failed=true
    fi
  fi

  [[ $failed == false ]]
}

quoted_value() {
  local value=$1

  case "$value" in
    *\"*\")
      value=${value#*\"}
      printf '%s\n' "${value%%\"*}"
      ;;
    *) return 1 ;;
  esac
}

primary_connection_uuid() {
  local property path

  property=$("$BUSCTL" get-property \
    org.freedesktop.NetworkManager \
    /org/freedesktop/NetworkManager \
    org.freedesktop.NetworkManager \
    PrimaryConnection) || return 1
  path=$(quoted_value "$property") || return 1
  [[ $path == /org/freedesktop/NetworkManager/ActiveConnection/* ]] || return 1

  property=$("$BUSCTL" get-property \
    org.freedesktop.NetworkManager \
    "$path" \
    org.freedesktop.NetworkManager.Connection.Active \
    Uuid) || return 1
  quoted_value "$property"
}

is_selected() {
  local primary_uuid=$1
  local connection_uuid
  shift

  for connection_uuid in "$@"; do
    if [[ $primary_uuid == "$connection_uuid" ]]; then
      return 0
    fi
  done
  return 1
}

probe_fallback() {
  "$CURL" \
    --noproxy '*' \
    --ipv4 \
    --interface 10.250.251.2 \
    --connect-timeout 2 \
    --max-time 3 \
    --fail \
    --silent \
    --show-error \
    --output /dev/null \
    https://1.1.1.1/
}

if ! "$SYSTEMCTL" is-active --quiet "$PANGOLIN_UNIT"; then
  stop_fallback || true
  exit 0
fi

if ! primary_uuid=$(primary_connection_uuid); then
  log "cannot read NetworkManager primary connection; failing closed"
  stop_fallback || true
  exit 0
fi

if ! is_selected "$primary_uuid" "$@"; then
  stop_fallback || true
  exit 0
fi

if [[ ! -r $KEY_FILE ]]; then
  log "private key is not readable: $KEY_FILE; failing closed"
  stop_fallback || true
  exit 0
fi

if ! "$SYSTEMCTL" is-active --quiet "$WG_UNIT" ||
  ! "$SYSTEMCTL" is-active --quiet "$WSTUNNEL_UNIT"; then
  # Clear a partial previous start before asking systemd to start both units in order.
  stop_fallback || true
  log "starting fallback for primary connection '$primary_uuid'"
  if ! "$SYSTEMCTL" start "$WG_UNIT"; then
    log "failed to start $WG_UNIT"
    stop_fallback || true
    exit 1
  fi

  if ! "$SYSTEMCTL" is-active --quiet "$WG_UNIT" ||
    ! "$SYSTEMCTL" is-active --quiet "$WSTUNNEL_UNIT"; then
    log "fallback units did not become active"
    stop_fallback || true
    exit 1
  fi
fi

if ! "$ROUTING" refresh-dns; then
  log "failed to refresh native DNS routes"
  "$ROUTING" withdraw || log "failed to withdraw fallback routing after DNS refresh error"
  exit 1
fi

if ! probe_fallback; then
  "$ROUTING" withdraw
  exit $?
fi

# The probe takes long enough for the selected connection or Pangolin to change.
if ! current_primary_uuid=$(primary_connection_uuid) ||
  ! is_selected "$current_primary_uuid" "$@" ||
  [[ $current_primary_uuid != "$primary_uuid" ]] ||
  ! "$SYSTEMCTL" is-active --quiet "$PANGOLIN_UNIT"; then
  stop_fallback || true
  exit 0
fi

if ! "$ROUTING" promote; then
  log "failed to promote fallback routing"
  "$ROUTING" withdraw || log "failed to withdraw fallback routing after promotion error"
  exit 1
fi
