# shellcheck shell=bash

set -euo pipefail

if (( $# != 1 )) || [[ ! $1 =~ ^[0-9]+$ ]] || (( $1 > 100 )); then
  echo "Usage: fos-internal-battery-low <percentage>" >&2
  exit 2
fi
fos-internal-notification-send \
  --urgency critical \
  --icon battery-caution \
  --expire-time 30000 \
  "Time to recharge!" \
  "Battery is down to $1%"
