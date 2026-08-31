set -euo pipefail

file="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/settings/weather.json"
case "${1:-}" in
  "")
    name=""; [[ ! -f $file ]] || name=$(jq -r '.name // empty | select(type == "string")' "$file")
    [[ -n $name ]] || { name=$(curl -fsS --max-time 4 'https://wttr.in/?format=%l' 2>/dev/null || true); name=${name%%,*}; }
    [[ -z $name ]] || printf '%s\n' "$name" ;;
  --set)
    (( $# == 2 || $# == 3 )) && [[ -n $2 ]] || { echo "Usage: weather-location --set <name> [lat,lon]" >&2; exit 2; }
    if (( $# == 3 )); then
      [[ $3 =~ ^-?[0-9]+([.][0-9]+)?,-?[0-9]+([.][0-9]+)?$ ]] || { echo "Invalid coordinates" >&2; exit 2; }
      json=$(jq -n --arg name "$2" --argjson latitude "${3%,*}" --argjson longitude "${3#*,}" '{name:$name,latitude:$latitude,longitude:$longitude}')
    else json=$(jq -n --arg name "$2" '{name:$name}'); fi
    mkdir -p "$(dirname "$file")"; umask 077; printf '%s\n' "$json" >"$file" ;;
  --clear) (( $# == 1 )) || exit 2; rm -f "$file" ;;
  *) echo "Usage: weather-location [--set <name> [lat,lon]|--clear]" >&2; exit 2 ;;
esac
