set -euo pipefail

usage() { echo "Usage: monitor-scaling [up|down|SCALE]" >&2; exit 2; }
(( $# <= 1 )) || usage
info=$(hyprctl monitors -j | jq -ec '.[] | select(.focused == true)')
name=$(jq -r '.name' <<<"$info")
current=$(jq -r '.scale' <<<"$info")
mode=$(jq -r '"\(.width)x\(.height)@\(.refreshRate)"' <<<"$info")
position=$(jq -r '"\(.x)x\(.y)"' <<<"$info")
[[ $name =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Unsafe monitor name" >&2; exit 1; }
[[ $mode =~ ^[0-9]+x[0-9]+@[0-9]+([.][0-9]+)?$ ]] || { echo "Unsafe monitor mode" >&2; exit 1; }
[[ $position =~ ^-?[0-9]+x-?[0-9]+$ ]] || { echo "Unsafe monitor position" >&2; exit 1; }
[[ -n ${1:-} ]] || { awk -v n="$current" 'BEGIN { printf "%g\n", n }'; exit; }
case "$1" in
  up) scale=$(awk -v n="$current" 'BEGIN { if(n<1.25)print 1.25;else if(n<1.6)print 1.6;else if(n<2)print 2;else if(n<3)print 3;else print 4 }') ;;
  down) scale=$(awk -v n="$current" 'BEGIN { if(n>3)print 3;else if(n>2)print 2;else if(n>1.6)print 1.6;else if(n>1.25)print 1.25;else print 1 }') ;;
  *) scale=$1 ;;
esac
if [[ ! $scale =~ ^[0-9]+([.][0-9]+)?$ ]] || ! awk -v n="$scale" 'BEGIN { exit !(n >= 1 && n <= 4) }'; then
  usage
fi
hyprctl keyword monitor "$name,$mode,$position,$scale" >/dev/null
