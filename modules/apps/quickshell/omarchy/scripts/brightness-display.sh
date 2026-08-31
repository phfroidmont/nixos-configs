set -euo pipefail

monitor=""
while (( $# )); do
  case "$1" in
    --no-osd) shift ;;
    --monitor) (( $# >= 2 )) || exit 2; monitor=$2; shift 2 ;;
    --*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
(( $# <= 1 )) || { echo "Usage: brightness-display [--no-osd] [--monitor name] [value]" >&2; exit 2; }
if [[ -z $monitor ]]; then
  monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | awk 'NR == 1')
fi
[[ $monitor =~ ^(eDP|LVDS|DSI)- ]] || { echo "External monitor brightness is unsupported" >&2; exit 1; }
device=$(brightnessctl -c backlight -m | awk -F, 'NR == 1 { print $1 }')
[[ -n $device ]] || { echo "No backlight device" >&2; exit 1; }
if (( $# == 0 )); then
  brightnessctl -d "$device" -m | awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }'
else
  [[ $1 =~ ^([0-9]+%|\+[0-9]+%|[0-9]+%-)$ ]] || { echo "Invalid brightness value: $1" >&2; exit 2; }
  brightnessctl -d "$device" set "$1" >/dev/null
  brightnessctl -d "$device" -m | awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }'
fi
