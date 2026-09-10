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
  and (.disabledPlugins | index("phfroidmont.pangolin") | not)
  and any(.bar.layout.center[];
    .id == "omarchy.indicators"
    and .items == ["ScreenRecording", "Dictation", "Reminder", "Dnd", "StayAwake"])
  and any(.bar.layout.center[]; .id == "omarchy.media")
  and any(.bar.layout.right[]; .id == "phfroidmont.pangolin")
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
  and .bar.layout.right[2] == {"id": "phfroidmont.pangolin"}
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

tailscale_disabled_home="$temporary/tailscale-disabled-home"
tailscale_disabled_config="$tailscale_disabled_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$tailscale_disabled_config")"
cat >"$tailscale_disabled_config" <<'EOF'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": ["custom.left", "omarchy.tailscale"],
      "center": [{"id": "custom.center"}],
      "right": [{"id": "omarchy.tailscale"}, {"id": "custom.right"}]
    }
  },
  "disabledPlugins": ["custom.disabled"],
  "nixosConfigMigrations": {
    "notifications": 1,
    "menuWidget": 1,
    "statusFeatures": 2,
    "claudeAgent": 1
  }
}
EOF
FOS_TAILSCALE_ENABLED=0 HOME="$tailscale_disabled_home" \
  bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .disabledPlugins == ["custom.disabled", "omarchy.tailscale"]
  and .bar.layout.left == ["custom.left", "phfroidmont.pangolin"]
  and .bar.layout.center == [{"id": "custom.center"}]
  and .bar.layout.right == [{"id": "custom.right"}]
  and .nixosConfigMigrations == {
    "notifications": 1,
    "menuWidget": 1,
    "statusFeatures": 2,
    "claudeAgent": 1,
    "pangolinStatus": 1
  }
' "$tailscale_disabled_config" >/dev/null
cp "$tailscale_disabled_config" "$temporary/tailscale-disabled-after-sync.json"
FOS_TAILSCALE_ENABLED=0 HOME="$tailscale_disabled_home" \
  bash "$root/scripts/sync-shell-config.sh"
cmp "$temporary/tailscale-disabled-after-sync.json" "$tailscale_disabled_config"

object_home="$temporary/object-home"
object_config="$object_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$object_config")"
cat >"$object_config" <<'EOF'
{
  "version": 1,
  "bar": {"layout": {
    "left": [{"id": "custom.left"}],
    "center": [{"id": "omarchy.tailscale", "compact": true}, {"id": "custom.center"}],
    "right": [{"id": "custom.right"}]
  }},
  "disabledPlugins": [],
  "nixosConfigMigrations": {
    "notifications": 1, "menuWidget": 1, "statusFeatures": 2, "claudeAgent": 1
  }
}
EOF
HOME="$object_home" bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .bar.layout.left == [{"id": "custom.left"}]
  and .bar.layout.center == [
    {"id": "phfroidmont.pangolin", "compact": true},
    {"id": "custom.center"}
  ]
  and .bar.layout.right == [{"id": "custom.right"}]
  and .nixosConfigMigrations.pangolinStatus == 1
' "$object_config" >/dev/null

user_disabled_home="$temporary/user-disabled-home"
user_disabled_config="$user_disabled_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$user_disabled_config")"
cat >"$user_disabled_config" <<'EOF'
{
  "version": 1,
  "bar": {"layout": {"left": [], "center": [], "right": [{"id": "custom.right"}]}},
  "disabledPlugins": ["custom.first", "omarchy.tailscale", "custom.last"],
  "nixosConfigMigrations": {
    "notifications": 1, "menuWidget": 1, "statusFeatures": 2, "claudeAgent": 1
  }
}
EOF
HOME="$user_disabled_home" bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .disabledPlugins == [
    "custom.first", "omarchy.tailscale", "custom.last", "phfroidmont.pangolin"
  ]
  and .bar.layout.right == [{"id": "custom.right"}]
  and .nixosConfigMigrations.pangolinStatus == 1
' "$user_disabled_config" >/dev/null

enabled_hidden_home="$temporary/enabled-hidden-home"
enabled_hidden_config="$enabled_hidden_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$enabled_hidden_config")"
cat >"$enabled_hidden_config" <<'EOF'
{
  "version": 1,
  "bar": {"layout": {
    "left": ["custom.left"], "center": [], "right": [{"id": "custom.right"}]
  }},
  "disabledPlugins": ["custom.disabled"],
  "nixosConfigMigrations": {
    "notifications": 1, "menuWidget": 1, "statusFeatures": 2, "claudeAgent": 1
  }
}
EOF
HOME="$enabled_hidden_home" bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .bar.layout == {
    "left": ["custom.left"], "center": [], "right": [{"id": "custom.right"}]
  }
  and .disabledPlugins == ["custom.disabled"]
  and .nixosConfigMigrations.pangolinStatus == 1
' "$enabled_hidden_config" >/dev/null

policy_migrated_home="$temporary/policy-migrated-home"
policy_migrated_config="$policy_migrated_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$policy_migrated_config")"
cat >"$policy_migrated_config" <<'EOF'
{
  "version": 1,
  "bar": {"layout": {
    "left": [],
    "center": [],
    "right": ["custom.network", {"id": "omarchy.microphone"}, {"id": "omarchy.audio"}]
  }},
  "disabledPlugins": ["omarchy.tailscale"],
  "nixosConfigMigrations": {
    "notifications": 1, "menuWidget": 1, "statusFeatures": 2, "claudeAgent": 1
  }
}
EOF
FOS_TAILSCALE_ENABLED=0 HOME="$policy_migrated_home" \
  bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .disabledPlugins == ["omarchy.tailscale"]
  and .bar.layout.right == [
    "custom.network",
    {"id": "phfroidmont.pangolin"},
    {"id": "omarchy.microphone"},
    {"id": "omarchy.audio"}
  ]
  and .nixosConfigMigrations.pangolinStatus == 1
' "$policy_migrated_config" >/dev/null

host_user_disabled_home="$temporary/host-user-disabled-home"
host_user_disabled_config="$host_user_disabled_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$host_user_disabled_config")"
cat >"$host_user_disabled_config" <<'EOF'
{
  "version": 1,
  "bar": {"layout": {
    "left": [], "center": [],
    "right": [{"id": "omarchy.tailscale"}, {"id": "omarchy.microphone"}]
  }},
  "disabledPlugins": ["omarchy.tailscale"],
  "nixosConfigMigrations": {
    "notifications": 1, "menuWidget": 1, "statusFeatures": 2, "claudeAgent": 1
  }
}
EOF
FOS_TAILSCALE_ENABLED=0 HOME="$host_user_disabled_home" \
  bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .disabledPlugins == ["omarchy.tailscale", "phfroidmont.pangolin"]
  and .bar.layout.right == [
    {"id": "phfroidmont.pangolin"},
    {"id": "omarchy.microphone"}
  ]
  and .nixosConfigMigrations.pangolinStatus == 1
' "$host_user_disabled_config" >/dev/null

duplicate_home="$temporary/duplicate-home"
duplicate_config="$duplicate_home/.config/omarchy/shell.json"
mkdir -p "$(dirname "$duplicate_config")"
cat >"$duplicate_config" <<'EOF'
{
  "version": 1,
  "bar": {"layout": {
    "left": [{"id": "phfroidmont.pangolin", "label": "keep"}],
    "center": ["omarchy.tailscale"],
    "right": [{"id": "omarchy.tailscale", "label": "remove"}]
  }},
  "disabledPlugins": [],
  "nixosConfigMigrations": {
    "notifications": 1, "menuWidget": 1, "statusFeatures": 2, "claudeAgent": 1
  }
}
EOF
HOME="$duplicate_home" bash "$root/scripts/sync-shell-config.sh"
jq -e '
  .bar.layout.left == [{"id": "phfroidmont.pangolin", "label": "keep"}]
  and .bar.layout.center == []
  and .bar.layout.right == []
  and ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
    | map(if type == "string" then . else .id end)
    | map(select(. == "phfroidmont.pangolin")) | length) == 1
' "$duplicate_config" >/dev/null
cp "$duplicate_config" "$temporary/duplicate-after-sync.json"
HOME="$duplicate_home" bash "$root/scripts/sync-shell-config.sh"
cmp "$temporary/duplicate-after-sync.json" "$duplicate_config"

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
    {"id": "phfroidmont.pangolin"},
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
