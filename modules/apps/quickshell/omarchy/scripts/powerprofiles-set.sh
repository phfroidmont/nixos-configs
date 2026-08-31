set -euo pipefail

(( $# <= 2 )) || { echo "Usage: powerprofiles-set [autodetect|ac|battery] [profile]" >&2; exit 2; }
mode=${1:-autodetect}; requested=${2:-}
if [[ $mode == autodetect ]]; then
  if [[ $(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null || true) == 'b true' ]]; then mode=battery; else mode=ac; fi
fi
[[ $mode == ac || $mode == battery ]] || { echo "Invalid power mode: $mode" >&2; exit 2; }
mapfile -t profiles < <(omarchy-powerprofiles-list)
available() { [[ " ${profiles[*]} " == *" $1 "* ]]; }
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/powerprofiles"; state_file="$state_dir/$mode"
if [[ -n $requested ]]; then available "$requested" || { echo "Power profile is not available: $requested" >&2; exit 1; }; profile=$requested
elif [[ -r $state_file ]]; then profile=$(<"$state_file")
elif [[ $mode == ac ]] && available performance; then profile=performance
else profile=balanced; fi
available "$profile" || profile=balanced
powerprofilesctl set "$profile"
if [[ -n $requested ]]; then mkdir -p "$state_dir"; chmod 700 "$state_dir"; printf '%s\n' "$requested" >"$state_file"; fi
