#!/usr/bin/env bash

set -euo pipefail

root=${QUICKSHELL_MODULE_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

fake_bin="$temporary/bin"
args="$temporary/notification-args"
mkdir -p "$fake_bin"

printf '#!%s\n' "$BASH" >"$fake_bin/fos-internal-notification-send"
cat >>"$fake_bin/fos-internal-notification-send" <<'EOF'
printf '%s\n' "$@" >"$NOTIFICATION_ARGS"
EOF
chmod +x "$fake_bin/fos-internal-notification-send"

NOTIFICATION_ARGS="$args" PATH="$fake_bin:$PATH" \
  bash "$root/omarchy/scripts/battery-low.sh" 10

mapfile -t actual <"$args"
expected=(
  --urgency critical
  --icon battery-caution
  --expire-time 30000
  "Time to recharge!"
  "Battery is down to 10%"
)
[[ ${#actual[@]} -eq ${#expected[@]} ]]
for index in "${!expected[@]}"; do
  [[ ${actual[$index]} == "${expected[$index]}" ]]
done

if PATH="$fake_bin:$PATH" bash "$root/omarchy/scripts/battery-low.sh" invalid 2>/dev/null; then
  exit 1
fi
if PATH="$fake_bin:$PATH" bash "$root/omarchy/scripts/battery-low.sh" 101 2>/dev/null; then
  exit 1
fi

jq -e '
  (.disabledPlugins | index("omarchy.notifications") | not)
  and (.disabledPlugins | index("omarchy.indicators") | not)
  and (.disabledPlugins | index("omarchy.microphone") | not)
  and (.disabledPlugins | index("omarchy.reminders") | not)
  and (.disabledPlugins | index("omarchy.tailscale") | not)
  and any(.bar.layout.center[];
    .id == "omarchy.indicators"
    and .items == ["ScreenRecording", "Dictation", "Reminder", "Dnd", "StayAwake"])
  and any(.bar.layout.center[]; .id == "omarchy.media")
  and any(.bar.layout.right[]; .id == "omarchy.tailscale")
  and any(.bar.layout.right[]; .id == "omarchy.microphone")
  and ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
    | map(.id) | index("omarchy.menu") | not)
' "$root/omarchy/shell.json" >/dev/null

sync_home="$temporary/sync-home"
sync_config="$sync_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$sync_config")"
cat >"$sync_config" <<'EOF'
{
  "version": 1,
  "bar": {
    "position": "bottom",
    "layout": {
      "left": [
        {"id": "omarchy.menu"}
      ],
      "center": [
        {"id": "omarchy.indicators", "items": "Dnd", "alwaysShow": true},
        {"id": "omarchy.clock", "birthYear": 1984},
        {"id": "omarchy.weather"}
      ],
      "right": [
        {"id": "omarchy.indicators", "items": ["NightLight"]},
        {"id": "omarchy.agents", "providers": {"codex": {"enabled": true}}}
      ]
    }
  },
  "disabledPlugins": [
    "omarchy.idle",
    "omarchy.indicators",
    "omarchy.notifications"
  ]
}
EOF

chmod 640 "$sync_config"
HOME="$sync_home" bash "$root/scripts/sync-shell-config.sh"
[[ $(stat -c %a "$sync_config") == 640 ]]
jq -e '
  .disabledPlugins == ["omarchy.idle"]
  and .nixosConfigMigrations.notifications == 1
  and .nixosConfigMigrations.menuWidget == 1
  and .nixosConfigMigrations.statusFeatures == 2
  and .bar.layout.left == []
' "$sync_config" >/dev/null
jq -e '
  .bar.layout.center[0] == {"id": "omarchy.media"}
  and .bar.layout.center[1] == {
    "id": "omarchy.indicators",
    "items": ["ScreenRecording", "Dictation", "Reminder", "Dnd", "StayAwake"],
    "alwaysShow": true
  }
  and .bar.layout.center[1].alwaysShow
  and .bar.layout.center[2].birthYear == 1984
  and ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
    | map(.id) | index("omarchy.menu") | not)
  and .bar.layout.right[0] == {
    "id": "omarchy.indicators",
    "items": ["NightLight"]
  }
  and .bar.layout.right[1].providers.codex.enabled
  and .bar.layout.right[2] == {"id": "omarchy.tailscale"}
  and .bar.layout.right[3] == {"id": "omarchy.microphone"}
' "$sync_config" >/dev/null

jq '
  .disabledPlugins += ["omarchy.notifications"]
  | .bar.layout.center |= map(select(.id != "omarchy.indicators"))
' "$sync_config" >"$temporary/user-edited.json"
mv "$temporary/user-edited.json" "$sync_config"
cp "$sync_config" "$temporary/after-user-edit.json"
HOME="$sync_home" bash "$root/scripts/sync-shell-config.sh"
cmp "$temporary/after-user-edit.json" "$sync_config"

version_one_home="$temporary/version-one-home"
version_one_config="$version_one_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$version_one_config")"
cat >"$version_one_config" <<'EOF'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [],
      "center": [
        {"id": "omarchy.indicators", "items": ["ScreenRecording", "Reminder", "Dnd", "StayAwake"]},
        {"id": "omarchy.clock"}
      ],
      "right": []
    }
  },
  "disabledPlugins": [],
  "nixosConfigMigrations": {"notifications": 1, "menuWidget": 1, "statusFeatures": 1}
}
EOF
HOME="$version_one_home" bash "$root/scripts/sync-shell-config.sh"
jq -e '
  any(.bar.layout.center[];
    .id == "omarchy.indicators"
    and .items == ["ScreenRecording", "Dictation", "Reminder", "Dnd", "StayAwake"])
  and ([.bar.layout.center[] | select(.id == "omarchy.indicators")] | length) == 1
  and .nixosConfigMigrations.statusFeatures == 2
' "$version_one_config" >/dev/null

legacy_home="$temporary/legacy-home"
legacy_config="$legacy_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$legacy_config")"
cat >"$legacy_config" <<'EOF'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [{"id": "omarchy.menu"}],
      "center": [{"id": "omarchy.clock"}],
      "right": [{"id": "omarchy.power"}]
    }
  },
  "disabledPlugins": ["omarchy.indicators", "omarchy.notifications"],
  "nixosConfigMigrations": {"notifications": "pending"}
}
EOF
HOME="$legacy_home" bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .disabledPlugins == []
  and .bar.layout.center[0] == {"id": "omarchy.media"}
  and .bar.layout.center[1] == {
    "id": "omarchy.indicators",
    "items": ["ScreenRecording", "Dictation", "Reminder", "Dnd", "StayAwake"]
  }
  and (.bar.layout.center[1] | has("alwaysShow") | not)
  and .bar.layout.center[2].id == "omarchy.clock"
  and .bar.layout.right == [
    {"id": "omarchy.power"},
    {"id": "omarchy.tailscale"},
    {"id": "omarchy.microphone"}
  ]
  and .nixosConfigMigrations.notifications == 1
  and .nixosConfigMigrations.menuWidget == 1
  and .nixosConfigMigrations.statusFeatures == 2
  and .bar.layout.left == []
' "$legacy_config" >/dev/null

menu_home="$temporary/menu-home"
menu_config="$menu_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$menu_config")"
cat >"$menu_config" <<'EOF'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [{"id": "omarchy.menu"}, {"id": "omarchy.workspaces"}],
      "center": ["omarchy.menu", {"id": "omarchy.clock"}],
      "right": ["omarchy.menu"]
    }
  },
  "disabledPlugins": ["omarchy.notifications", "omarchy.indicators"],
  "nixosConfigMigrations": {"notifications": 1, "statusFeatures": 1}
}
EOF
HOME="$menu_home" bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .disabledPlugins == ["omarchy.notifications", "omarchy.indicators"]
  and .bar.layout.left == [{"id": "omarchy.workspaces"}]
  and .bar.layout.center == [{"id": "omarchy.clock"}]
  and .bar.layout.right == []
  and .nixosConfigMigrations.notifications == 1
  and .nixosConfigMigrations.menuWidget == 1
  and .nixosConfigMigrations.statusFeatures == 2
' "$menu_config" >/dev/null

missing_home="$temporary/missing-home"
HOME="$missing_home" bash "$root/scripts/sync-shell-config.sh"
[[ ! -e $missing_home/.config/omarchy/shell.json ]]

invalid_home="$temporary/invalid-home"
invalid_config="$invalid_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$invalid_config")"
printf '{ invalid json\n' >"$invalid_config"
cp "$invalid_config" "$temporary/invalid-before.json"
HOME="$invalid_home" bash "$root/scripts/sync-shell-config.sh" 2>/dev/null
cmp "$temporary/invalid-before.json" "$invalid_config"

multiple_home="$temporary/multiple-home"
multiple_config="$multiple_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$multiple_config")"
printf '%s\n%s\n' '{"version":1}' '{"version":1}' >"$multiple_config"
cp "$multiple_config" "$temporary/multiple-before.json"
HOME="$multiple_home" bash "$root/scripts/sync-shell-config.sh" 2>/dev/null
cmp "$temporary/multiple-before.json" "$multiple_config"

symlink_home="$temporary/symlink-home"
symlink_config="$symlink_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$symlink_config")"
printf '%s\n' '{"version":1}' >"$temporary/managed-shell.json"
ln -s "$temporary/managed-shell.json" "$symlink_config"
HOME="$symlink_home" bash "$root/scripts/sync-shell-config.sh" 2>/dev/null
[[ -L $symlink_config ]]

readonly_home="$temporary/readonly-home"
readonly_directory="$readonly_home/.config/omarchy"
readonly_config="$readonly_directory/shell.json"
mkdir -p "$readonly_directory"
printf '%s\n' '{"version":1}' >"$readonly_config"
cp "$readonly_config" "$temporary/readonly-before.json"
chmod 500 "$readonly_directory"
HOME="$readonly_home" bash "$root/scripts/sync-shell-config.sh" 2>/dev/null
chmod 700 "$readonly_directory"
cmp "$temporary/readonly-before.json" "$readonly_config"

nonfinite_home="$temporary/nonfinite-home"
nonfinite_config="$nonfinite_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$nonfinite_config")"
printf '%s\n' '{"version":1,"value":NaN}' >"$nonfinite_config"
cp "$nonfinite_config" "$temporary/nonfinite-before.json"
HOME="$nonfinite_home" bash "$root/scripts/sync-shell-config.sh" 2>/dev/null
cmp "$temporary/nonfinite-before.json" "$nonfinite_config"

printf 'notification tools test passed\n'
