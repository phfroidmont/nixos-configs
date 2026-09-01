set -euo pipefail

if (( $# != 1 )) || [[ $1 != down && $1 != up ]]; then
  echo "Usage: fos-internal-network-speedtest <down|up>" >&2
  exit 2
fi

direction=$1
parallel=8
iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

if [[ -z $iface || ! -r /sys/class/net/$iface/statistics/rx_bytes || ! -r /sys/class/net/$iface/statistics/tx_bytes ]]; then
  echo "No active network interface" >&2
  exit 1
fi

mapfile -t fast_urls < <(
  curl -fsS --max-time 3 \
    'https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=3' \
    | jq -r '.targets[]?.url // empty'
)

if (( ${#fast_urls[@]} == 0 )); then
  echo "Failed to fetch speed test endpoints" >&2
  exit 1
fi

traffic_pids=()

cleanup() {
  local pid
  for pid in "${traffic_pids[@]}"; do
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  done
  wait "${traffic_pids[@]}" 2>/dev/null || true
}
trap cleanup EXIT

traffic_worker() {
  local idx=$RANDOM
  local url

  while true; do
    url=${fast_urls[$((idx % ${#fast_urls[@]}))]}
    if [[ $direction == down ]]; then
      curl -fsS -o /dev/null "$url" 2>/dev/null || return
    else
      dd if=/dev/zero bs=1M count=64 2>/dev/null \
        | curl -fsS -o /dev/null -X POST --data-binary @- "$url" 2>/dev/null \
        || return
    fi
    ((idx += 1))
  done
}

for ((i = 0; i < parallel; i++)); do
  traffic_worker &
  traffic_pids+=("$!")
done

rx_before=$(<"/sys/class/net/$iface/statistics/rx_bytes")
tx_before=$(<"/sys/class/net/$iface/statistics/tx_bytes")

any_worker_alive() {
  local pid
  for pid in "${traffic_pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

while any_worker_alive; do
  sleep 1
  rx_after=$(<"/sys/class/net/$iface/statistics/rx_bytes")
  tx_after=$(<"/sys/class/net/$iface/statistics/tx_bytes")

  if [[ $direction == down ]]; then
    before=$rx_before
    after=$rx_after
  else
    before=$tx_before
    after=$tx_after
  fi

  awk -v before="$before" -v after="$after" 'BEGIN {
    if (after < before) print "0.0"
    else printf "%.1f\n", (after - before) * 8 / 1000000
  }'
  rx_before=$rx_after
  tx_before=$tx_after
done
