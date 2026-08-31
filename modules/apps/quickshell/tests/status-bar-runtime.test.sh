#!/usr/bin/env bash

set -euo pipefail

: "${QUICKSHELL_BIN:?set QUICKSHELL_BIN to the quickshell executable}"
: "${BUSCTL_BIN:?set BUSCTL_BIN to the busctl executable}"
: "${NOTIFICATION_SEND_BIN:?set NOTIFICATION_SEND_BIN to omarchy-notification-send}"
: "${PYTHON_BIN:?set PYTHON_BIN to the Python executable}"
: "${QS_BIN:?set QS_BIN to the qs executable}"
: "${SHELL_PATH:?set SHELL_PATH to the derived shell directory}"

test_root=$(mktemp -d)
log="$test_root/quickshell.log"
module_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shell_root=$(dirname "$SHELL_PATH")
pid=""

mkdir -p \
  "$test_root/home/.config/omarchy" \
  "$test_root/home/.local/share/opencode"
jq '
  .disabledPlugins += ["omarchy.indicators", "omarchy.notifications"]
  | .bar.layout.center |= map(select(.id != "omarchy.indicators"))
' "$module_root/omarchy/shell.json" \
  >"$test_root/home/.config/omarchy/shell.json"
HOME="$test_root/home" bash "$module_root/scripts/sync-shell-config.sh"
jq -e '
  (.disabledPlugins | index("omarchy.notifications") | not)
  and any(.bar.layout.center[];
    .id == "omarchy.indicators" and .items == ["Dnd"])
' "$test_root/home/.config/omarchy/shell.json" >/dev/null

"$PYTHON_BIN" - "$test_root/home/.local/share/opencode/opencode.db" <<'PYTHON'
import json
import sqlite3
import sys
import time

connection = sqlite3.connect(sys.argv[1])
connection.execute("CREATE TABLE message (session_id TEXT, data TEXT)")
connection.execute(
    "INSERT INTO message VALUES (?, ?)",
    (
        "fixture-session",
        json.dumps(
            {
                "role": "assistant",
                "providerID": "openai",
                "modelID": "gpt-fixture",
                "time": {"created": int(time.time() * 1000)},
                "tokens": {
                    "input": 50,
                    "output": 40,
                    "reasoning": 10,
                    "cache": {"read": 0, "write": 0},
                },
            }
        ),
    ),
)
connection.commit()
connection.close()
PYTHON

grep -Fq 'root.bar.run(Quickshell.env("AGENTS_LAUNCH"))' \
  "$SHELL_PATH/plugins/agents/Panel.qml"
grep -Fq 'Border.localOrSurfaceSpec("notifications", "border", effectiveBorderColor' \
  "$SHELL_PATH/plugins/notifications/components/NotificationCard.qml"
test -x "$shell_root/bin/omarchy-hyprland-focus-app"

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
AGENTS_LAUNCH=true \
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
[[ $("$QS_BIN" -p "$SHELL_PATH" ipc call -- notifications ping) == ok ]]
[[ $("$QS_BIN" -p "$SHELL_PATH" ipc call -- notifications dndState) == off ]]
[[ $("$QS_BIN" -p "$SHELL_PATH" ipc call -- notifications toggleDnd) == on ]]
[[ $("$QS_BIN" -p "$SHELL_PATH" ipc call -- notifications toggleDnd) == off ]]
"$BUSCTL_BIN" --user status org.freedesktop.Notifications >/dev/null

HOME="$test_root/home" "$NOTIFICATION_SEND_BIN" \
  --app-name runtime-test \
  --urgency normal \
  --expire-time 30000 \
  "Runtime notification" \
  "Delivered over D-Bus"

notification_record=""
for _ in {1..100}; do
  for candidate in "$test_root/home/.local/state/omarchy/notifications/"*.json; do
    [[ -f $candidate ]] || continue
    if jq -e '
      .app == "runtime-test"
      and .summary == "Runtime notification"
      and .body == "Delivered over D-Bus"
    ' "$candidate" >/dev/null; then
      notification_record=$candidate
      break 2
    fi
  done
  sleep 0.1
done
[[ -n $notification_record ]]

usage_record="$test_root/home/.local/state/omarchy/agents/usage/codex.json"
geometry=""
for _ in {1..400}; do
  if [[ -f $usage_record ]] \
    && jq -e '.id == "codex" and .totalPrompts == 1 and .modelUsage["gpt-fixture"]' "$usage_record" >/dev/null; then
    geometry=$("$QS_BIN" -p "$SHELL_PATH" ipc call -- shell debugBarGeometry)
    if jq -e 'any(.[]; .id == "omarchy.agents" and .visible and .itemVisible)' <<<"$geometry" >/dev/null; then
      break
    fi
  fi
  kill -0 "$pid" 2>/dev/null || {
    cat "$log" >&2
    exit 1
  }
  sleep 0.1
done

jq -e '.id == "codex" and .totalPrompts == 1 and .modelUsage["gpt-fixture"]' "$usage_record" >/dev/null
jq -e 'any(.[]; .id == "omarchy.agents" and .visible and .itemVisible)' <<<"$geometry" >/dev/null

jq -e '
  map(.id) as $ids
  | all([
      "omarchy.menu",
      "omarchy.workspaces",
      "omarchy.indicators",
      "omarchy.clock",
      "omarchy.weather",
      "omarchy.tray",
      "omarchy.agents",
      "phfroidmont.nextcloud",
      "omarchy.bluetooth",
      "omarchy.network",
      "omarchy.audio",
      "omarchy.monitor",
      "omarchy.power"
    ][]; $ids | index(.))
' <<<"$geometry" >/dev/null

for panel in omarchy.agents omarchy.audio omarchy.bluetooth omarchy.clock omarchy.monitor omarchy.network omarchy.power; do
  "$QS_BIN" -p "$SHELL_PATH" ipc call -- shell summon "$panel" '{}' >/dev/null
  "$QS_BIN" -p "$SHELL_PATH" ipc call -- shell hide "$panel" >/dev/null
done

if grep -Eq 'failed to load|ReferenceError|TypeError' "$log"; then
  cat "$log" >&2
  exit 1
fi

printf 'status bar runtime test passed\n'
