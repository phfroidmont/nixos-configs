set -euo pipefail

(( $# == 0 )) || { echo "Usage: audio-output-sink" >&2; exit 2; }
pactl get-default-sink
