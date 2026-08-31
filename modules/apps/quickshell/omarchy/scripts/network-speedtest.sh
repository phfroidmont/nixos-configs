set -euo pipefail

if (( $# != 1 )) || [[ $1 != down && $1 != up ]]; then
  echo "Usage: network-speedtest <down|up>" >&2
  exit 2
fi
iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit} }')
[[ -n $iface ]] || { echo "No active network interface" >&2; exit 1; }
url=$(curl -fsS --max-time 8 'https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=1' | jq -er '.targets[0].url')
if [[ $1 == down ]]; then
  bytes=$(curl -fsS --max-time 15 -o /dev/null -w '%{size_download} %{time_total}' "$url")
else
  bytes=$(dd if=/dev/zero bs=1M count=16 2>/dev/null | curl -fsS --max-time 15 -o /dev/null -w '%{size_upload} %{time_total}' -X POST --data-binary @- "$url")
fi
awk '{ if ($2 > 0) printf "%.1f\n", $1 * 8 / $2 / 1000000; else print "0.0" }' <<<"$bytes"
