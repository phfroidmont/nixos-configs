#!/usr/bin/env bash

set -euo pipefail

: "${QUICKSHELL_BIN:?set QUICKSHELL_BIN to the quickshell executable}"
: "${QS_BIN:?set QS_BIN to the qs executable}"
: "${SHELL_PATH:?set SHELL_PATH to the derived shell directory}"

test_root=$(mktemp -d)
log="$test_root/quickshell.log"
shell_root=$(dirname "$SHELL_PATH")
pid=""

cleanup() {
  if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT

HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/home/.config" \
XDG_STATE_HOME="$test_root/home/.local/state" \
OMARCHY_PATH="$shell_root" \
QUICKSHELL_THEME_PATH="$shell_root/theme" \
CLIPBOARD_ACTION=true \
CLIPBOARD_CAPTURE=true \
CLIPBOARD_PKILL=true \
CLIPBOARD_SETPRIV=true \
CLIPBOARD_WL_PASTE=true \
LAUNCHER_ENV=env \
LAUNCHER_ICON_INDEX=true \
LAUNCHER_TERMINAL=true \
NEXTCLOUD_OPEN=true \
NEXTCLOUD_OPEN_FOLDER=true \
NEXTCLOUD_STATUS=nextcloud-status \
  "$QUICKSHELL_BIN" -p "$SHELL_PATH" --no-color >"$log" 2>&1 &
pid=$!

for _ in {1..100}; do
  if [[ $("$QS_BIN" -p "$SHELL_PATH" ipc call -- shell ping 2>/dev/null || true) == ok ]]; then
    break
  fi
  kill -0 "$pid" 2>/dev/null || {
    cat "$log" >&2
    exit 1
  }
  sleep 0.1
done

[[ $("$QS_BIN" -p "$SHELL_PATH" ipc call -- shell ping) == ok ]]

geometry=$("$QS_BIN" -p "$SHELL_PATH" ipc call -- shell debugBarGeometry)
jq -e '
  map(.id) as $ids
  | all([
      "omarchy.menu",
      "omarchy.workspaces",
      "omarchy.clock",
      "omarchy.weather",
      "omarchy.tray",
      "phfroidmont.nextcloud",
      "omarchy.bluetooth",
      "omarchy.network",
      "omarchy.audio",
      "omarchy.monitor",
      "omarchy.power"
    ][]; $ids | index(.))
' <<<"$geometry" >/dev/null

for panel in omarchy.audio omarchy.bluetooth omarchy.clock omarchy.monitor omarchy.network omarchy.power; do
  "$QS_BIN" -p "$SHELL_PATH" ipc call -- shell summon "$panel" '{}' >/dev/null
  "$QS_BIN" -p "$SHELL_PATH" ipc call -- shell hide "$panel" >/dev/null
done

if grep -Eq 'failed to load|ReferenceError|TypeError' "$log"; then
  cat "$log" >&2
  exit 1
fi

printf 'status bar runtime test passed\n'
