set -euo pipefail

usage() { echo "Usage: network-band [auto|2.4|5|6]" >&2; exit 2; }
(( $# <= 1 )) || usage
nm_get() { LC_ALL=C nmcli -e no -g "$@" 2>/dev/null; }
device=$(nm_get DEVICE,TYPE,STATE device status | awk -F: '$2 == "wifi" && $3 ~ /^connected/ { print $1; exit }')
[[ -n $device ]] || { [[ $# == 0 ]] && exit 0; echo "No connected Wi-Fi device" >&2; exit 1; }
profile=$(nm_get GENERAL.CONNECTION device show "$device")
[[ -n $profile && $profile != -- ]] || { echo "No active Wi-Fi profile" >&2; exit 1; }

if (( $# == 0 )); then
  link=$(iw dev "$device" link 2>/dev/null || true)
  freq=$(awk '/freq:/ { print $2; exit }' <<<"$link")
  ssid=$(awk '/SSID:/ { sub(/.*SSID: /, ""); print; exit }' <<<"$link")
  if (( ${freq:-0} >= 5925 )); then band=6; elif (( ${freq:-0} >= 4900 )); then band=5; elif (( ${freq:-0} >= 2400 )); then band=2.4; else band=""; fi
  available=$({
    [[ -z $band ]] || printf '%s\n' "$band"
    nm_get FREQ,SSID device wifi list ifname "$device" --rescan no |
      wanted="$ssid" awk -F: '
        BEGIN { wanted=ENVIRON["wanted"] }
        { name=$2; for(i=3;i<=NF;i++) name=name ":" $i; if(name==wanted) print $1 }
      ' | while IFS= read -r scan_freq; do
        scan_freq=${scan_freq%%[!0-9]*}
        if (( ${scan_freq:-0} >= 5925 )); then echo 6
        elif (( ${scan_freq:-0} >= 4900 )); then echo 5
        elif (( ${scan_freq:-0} >= 2400 )); then echo 2.4
        fi
      done
  } | sort -ug | tr '\n' ' ')
  available=${available% }
  selected=$(nm_get 802-11-wireless.band connection show "$profile")
  case "$selected" in bg) selected=2.4;; a) selected=5;; 6GHz) selected=6;; *) selected=auto;; esac
  printf 'band\t%s\navailable\t%s\nselected\t%s\n' "$band" "$available" "$selected"
  exit
fi
case "$1" in auto) wanted="";; 2.4) wanted="bg";; 5) wanted="a";; 6) wanted="6GHz";; *) usage;; esac
previous=$(nm_get 802-11-wireless.band connection show "$profile")
[[ $previous == "$wanted" ]] && exit 0
nmcli connection modify "$profile" 802-11-wireless.band "$wanted" >/dev/null
if ! nmcli connection up "$profile" >/dev/null 2>&1; then
  nmcli connection modify "$profile" 802-11-wireless.band "$previous" >/dev/null
  nmcli connection up "$profile" >/dev/null 2>&1 || true
  echo "Could not reconnect on requested band; reverted" >&2
  exit 1
fi
