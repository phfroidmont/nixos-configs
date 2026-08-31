set -euo pipefail

urgency=normal
timeout=-1
while (( $# > 0 )); do
  case "$1" in
    -u|--urgency) urgency=$2; shift 2 ;;
    -t|--expire-time) timeout=$2; shift 2 ;;
    -g|--glyph|-i|--icon|-r|--replace-id) shift 2 ;;
    -p|--print-id) shift ;;
    --*) shift ;;
    *) break ;;
  esac
done

(( $# >= 1 )) || exit 2
summary=$1
body=${2:-}
notify-send --urgency="$urgency" --expire-time="$timeout" "$summary" "$body"
