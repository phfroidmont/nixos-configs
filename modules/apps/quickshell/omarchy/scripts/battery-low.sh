set -euo pipefail

if (( $# != 1 )) || [[ ! $1 =~ ^[0-9]+$ ]] || (( $1 > 100 )); then
  echo "Usage: battery-low <percentage>" >&2
  exit 2
fi
notify-send --urgency=critical --expire-time=30000 --icon=battery-caution "Time to recharge!" "Battery is down to $1%"
