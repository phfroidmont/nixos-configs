set -euo pipefail

verbose=false
link_only=false
case "${1:-}" in
  "") ;;
  --verbose) verbose=true ;;
  --link) link_only=true ;;
  *) echo "Usage: fos-internal-network-status [--link|--verbose]" >&2; exit 2 ;;
esac

route=$(ip route get 1.1.1.1 2>/dev/null || true)
iface=$(awk '{ for (i=1; i<=NF; i++) if ($i == "dev") { print $(i+1); exit } }' <<<"$route")
if [[ $link_only == true ]]; then
  if [[ -z $iface ]]; then printf 'type\tdisconnected\n'; exit; fi
  if [[ -d /sys/class/net/$iface/wireless ]]; then type=wifi; else type=ethernet; fi
  printf 'iface\t%s\ntype\t%s\n' "$iface" "$type"
  exit
fi
if [[ $verbose == false ]]; then
  if [[ -z $iface ]]; then printf 'disconnected\t\t\t\n'; exit; fi
  if [[ ! -d /sys/class/net/$iface/wireless ]]; then printf 'ethernet\t%s\t\t\n' "$iface"; exit; fi
  ssid=""; signal=""; freq=""
  if command -v nmcli >/dev/null; then
    ssid=$(LC_ALL=C nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)
    signal=$(LC_ALL=C nmcli -t -f IN-USE,SIGNAL device wifi list ifname "$iface" --rescan no 2>/dev/null | awk -F: '$1 == "*" { print $2; exit }')
  fi
  if command -v iw >/dev/null; then
    link=$(iw dev "$iface" link 2>/dev/null || true)
    [[ -n $ssid ]] || ssid=$(awk '/SSID:/ { sub(/.*SSID: /, ""); print; exit }' <<<"$link")
    freq=$(awk '/freq:/ { print $2; exit }' <<<"$link")
  fi
  printf 'wifi\t%s\t%s\t%s\n' "${ssid:-$iface}" "$signal" "$freq"
  exit
fi

[[ -n $iface ]] || exit 0
gateway=$(awk '{ for (i=1; i<=NF; i++) if ($i == "via") { print $(i+1); exit } }' <<<"$route")
source_ip=$(awk '{ for (i=1; i<=NF; i++) if ($i == "src") { print $(i+1); exit } }' <<<"$route")
prefix=$(ip -j address show "$iface" | jq -r '.[0].addr_info[]? | select(.family == "inet") | .prefixlen' | awk 'NR == 1')
printf 'iface\t%s\nip\t%s\nprefix\t%s\ngateway\t%s\n' "$iface" "$source_ip" "$prefix" "$gateway"
[[ -r /sys/class/net/$iface/statistics/rx_bytes ]] && printf 'rx_bytes\t%s\n' "$(<"/sys/class/net/$iface/statistics/rx_bytes")"
[[ -r /sys/class/net/$iface/statistics/tx_bytes ]] && printf 'tx_bytes\t%s\n' "$(<"/sys/class/net/$iface/statistics/tx_bytes")"
if [[ -d /sys/class/net/$iface/wireless ]]; then
  printf 'type\twifi\n'
  if command -v iw >/dev/null; then
    link=$(iw dev "$iface" link 2>/dev/null || true)
    printf 'ssid\t%s\n' "$(awk '/SSID:/ { sub(/.*SSID: /, ""); print; exit }' <<<"$link")"
    printf 'signal_dbm\t%s\n' "$(awk '/signal:/ { print $2; exit }' <<<"$link")"
    printf 'freq\t%s\n' "$(awk '/freq:/ { print $2; exit }' <<<"$link")"
  fi
else
  printf 'type\tethernet\n'
  [[ -r /sys/class/net/$iface/speed ]] && printf 'speed\t%s\n' "$(<"/sys/class/net/$iface/speed")"
  [[ -r /sys/class/net/$iface/duplex ]] && printf 'duplex\t%s\n' "$(<"/sys/class/net/$iface/duplex")"
fi
if command -v ping >/dev/null; then
  [[ -z $gateway ]] || printf 'router_ping_ms\t%s\n' "$(LC_ALL=C ping -n -c1 -W1 "$gateway" 2>/dev/null | awk -F'time[=<]' '/time[=<]/ { split($2,a," "); print a[1]; exit }')"
  printf 'internet_ping_ms\t%s\n' "$(LC_ALL=C ping -n -c1 -W1 1.1.1.1 2>/dev/null | awk -F'time[=<]' '/time[=<]/ { split($2,a," "); print a[1]; exit }')"
fi
