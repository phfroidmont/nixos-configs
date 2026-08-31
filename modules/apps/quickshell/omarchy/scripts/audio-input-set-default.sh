set -euo pipefail

if (( $# != 2 )) || [[ -z $1 || -z $2 ]]; then
  echo "Usage: audio-input-set-default <node-id> <source-name>" >&2
  exit 2
fi

wpctl set-default "$1" 2>/dev/null || true
pactl set-default-source "$2"
pactl list source-outputs | awk '
  /^Source Output #/ { id = substr($3, 2); real = 0 }
  /application\.name = / { real = 1 }
  real && /^$/ { print id; real = 0 }
  END { if (real) print id }
' | while IFS= read -r stream; do
  [[ -n $stream ]] && pactl move-source-output "$stream" "$2" 2>/dev/null || true
done
