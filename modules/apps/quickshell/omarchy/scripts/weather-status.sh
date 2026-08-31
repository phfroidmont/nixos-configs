set -euo pipefail

(( $# == 0 )) || { echo "Usage: fos-internal-weather-status" >&2; exit 2; }
place=$(fos-internal-weather-location 2>/dev/null || true)
[[ -n $place ]] || { echo "Weather unavailable"; exit 1; }
query=$(jq -rn --arg value "$place" '$value|@uri')
weather=$(curl -fsS --max-time 4 "https://wttr.in/$query?format=%t|%w" 2>/dev/null | tr -d '\n' || true)
[[ -n $weather ]] || { echo "Weather unavailable"; exit 1; }
IFS='|' read -r temperature wind <<<"$weather"; temperature=${temperature#+}
printf '%s - Temp %s - Wind %s\n' "$place" "$temperature" "$wind"
