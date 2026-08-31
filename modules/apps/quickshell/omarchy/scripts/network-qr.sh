set -euo pipefail

interface=""; meta=false
while (( $# )); do case "$1" in --meta) meta=true;; --*) echo "Usage: network-qr [--meta] [interface]" >&2; exit 2;; *) [[ -z $interface ]] || exit 2; interface=$1;; esac; shift; done
if [[ -z $interface ]]; then
  interface=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2 == "wifi" && $3 ~ /^connected/ { print $1; exit }')
fi
[[ -n $interface ]] || { echo "No active Wi-Fi connection" >&2; exit 1; }
uuid=$(nmcli -g GENERAL.CON-UUID device show "$interface" | awk 'NR == 1')
mapfile -t fields < <(nmcli --show-secrets --escape no -g 802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless.hidden,802-11-wireless-security.wep-key0 connection show uuid "$uuid")
ssid=${fields[0]:-}; management=${fields[1]:-}; password=${fields[2]:-}; hidden=${fields[3]:-no}; wep=${fields[4]:-}
[[ -n $ssid ]] || { echo "Could not read Wi-Fi name" >&2; exit 1; }
[[ $management != *eap* && $management != *ieee8021x* ]] || { echo "Enterprise Wi-Fi cannot be shared" >&2; exit 1; }
if [[ -n $management && $management != none ]]; then security=WPA
elif [[ -n $wep ]]; then security=WEP; password=$wep
else security=nopass; password=""; fi
escape() { local v=$1; v=${v//\\/\\\\}; v=${v//;/\\;}; v=${v//,/\\,}; v=${v//:/\\:}; printf '%s' "$v"; }
payload="WIFI:T:$security;S:$(escape "$ssid");P:$(escape "$password");"
[[ $hidden != yes ]] || payload+="H:true;"
payload+=";"
[[ $meta == false ]] || printf 'meta\t%s\t%s\t%s\n' "$interface" "$security" "$ssid"
qrencode --type ASCII --margin 4 --output - <<<"$payload" | while IFS= read -r line; do
  row=""; for (( i=0; i<${#line}; i+=2 )); do [[ ${line:i:2} == *#* ]] && row+="1" || row+="0"; done; printf '%s\n' "$row"
done
