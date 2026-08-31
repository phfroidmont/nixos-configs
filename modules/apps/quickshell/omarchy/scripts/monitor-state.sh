set -euo pipefail

(( $# == 0 )) || { echo "Usage: monitor-state" >&2; exit 2; }
monitors=$(hyprctl monitors all -j)
focused=$(jq -r '[.[] | select(.focused == true)][0].name // ""' <<<"$monitors")
omarchy-brightness-display --monitor "$focused" 2>/dev/null || printf '\n'
jq -r '
  def internal: test("^(eDP|LVDS|DSI)-");
  ([.[] | select(.name | internal)][0].name // ""),
  ([.[] | select((.name | internal) | not)][0].name // ""),
  ([.[] | select((.name | internal) and .disabled != true)][0].name // ""),
  ([.[] | select(.mirrorOf != "none") | if (.name | internal) then .mirrorOf else .name end][0] // "")
' <<<"$monitors"
printf '%s\n' "$focused"
omarchy-hyprland-monitor-scaling 2>/dev/null || printf '\n'
jq -c '[.[] | {name, enabled:(.disabled != true), focused:(.focused == true), width, height}]' <<<"$monitors"
