set -euo pipefail

usage() { echo "Usage: fos-internal-bluetooth-device <pair|connect|disconnect|forget> <address>" >&2; exit 2; }
(( $# == 2 )) || usage
[[ $2 =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || usage

case "$1" in
  pair|connect)
    fos-internal-bluetooth-power on
    [[ $1 != pair ]] || timeout 20 bluetoothctl pair "$2" >/dev/null
    bluetoothctl trust "$2" >/dev/null 2>&1 || true
    timeout 20 bluetoothctl connect "$2" >/dev/null
    ;;
  disconnect) timeout 10 bluetoothctl disconnect "$2" >/dev/null ;;
  forget)
    bluetoothctl disconnect "$2" >/dev/null 2>&1 || true
    timeout 10 bluetoothctl remove "$2" >/dev/null
    ;;
  *) usage ;;
esac
