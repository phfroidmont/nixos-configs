set -euo pipefail

powered() { timeout 2 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; }
power_on() {
  rfkill unblock bluetooth
  timeout 5 bluetoothctl power on >/dev/null 2>&1 || true
  for _ in {1..10}; do powered && return; sleep 0.2; done
  echo "Bluetooth adapter did not power on" >&2
  return 1
}
case "${1:-}" in
  on) power_on ;;
  off) rfkill block bluetooth ;;
  toggle) if powered; then rfkill block bluetooth; else power_on; fi ;;
  is-on) powered ;;
  *) echo "Usage: fos-internal-bluetooth-power <on|off|toggle|is-on>" >&2; exit 2 ;;
esac
