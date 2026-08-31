set -euo pipefail

(( $# == 1 )) || { echo "Usage: fos-internal-network-password <interface>" >&2; exit 2; }
uuid=$(nmcli -g GENERAL.CON-UUID device show "$1" | awk 'NR == 1')
[[ -n $uuid && $uuid != -- ]] || { echo "No active Wi-Fi connection" >&2; exit 1; }
mapfile -t fields < <(nmcli --show-secrets --escape no -g 802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless-security.wep-key0 connection show uuid "$uuid")
management=${fields[0]:-}; password=${fields[1]:-}; wep=${fields[2]:-}
[[ $management != *eap* && $management != *ieee8021x* ]] || { echo "Enterprise Wi-Fi has no shareable password" >&2; exit 1; }
[[ -n $management && $management != none ]] || password=$wep
[[ -n $password ]] || { echo "This network has no password" >&2; exit 1; }
printf '%s\n' "$password"
