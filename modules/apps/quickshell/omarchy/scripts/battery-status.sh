set -euo pipefail

shell=false
case "${1:-}" in "") ;; --shell) shell=true;; *) echo "Usage: battery-status [--shell]" >&2; exit 2;; esac
base=${OMARCHY_POWER_SUPPLY_PATH:-/sys/class/power_supply}
battery=""
for candidate in "$base"/BAT*; do [[ -r $candidate/capacity ]] && { battery=$candidate; break; }; done
[[ -n $battery ]] || exit 0
percentage=$(<"$battery/capacity")
state=$(tr '[:upper:]' '[:lower:]' <"$battery/status")
case "$state" in full) state=fully-charged;; not\ charging) state=pending-charge;; esac
rate=0
if [[ -r $battery/power_now ]]; then rate=$(awk -v n="$(<"$battery/power_now")" 'BEGIN{printf "%.1f",n/1000000}')
elif [[ -r $battery/current_now && -r $battery/voltage_now ]]; then rate=$(awk -v a="$(<"$battery/current_now")" -v v="$(<"$battery/voltage_now")" 'BEGIN{printf "%.1f",a*v/1000000000000}'); fi
size=""
[[ -r $battery/energy_full ]] && size=$(awk -v n="$(<"$battery/energy_full")" 'BEGIN{printf "%.0f",n/1000000}')
[[ -z $size && -r $battery/charge_full && -r $battery/voltage_now ]] && size=$(awk -v a="$(<"$battery/charge_full")" -v v="$(<"$battery/voltage_now")" 'BEGIN{printf "%.0f",a*v/1000000000000}')
if [[ $shell == true ]]; then
  printf 'percentage\t%s%%\nstate\t%s\nrate\t%sW\nsize\t%sWh\ntime\t\n' "$percentage" "$state" "$rate" "$size"
  [[ -r $battery/cycle_count ]] && printf 'cycles\t%s\n' "$(<"$battery/cycle_count")"
  [[ -r $battery/charge_control_end_threshold ]] && printf 'threshold\t%s%%\n' "$(<"$battery/charge_control_end_threshold")"
else
  printf 'Battery %s%% - %s - %sW / %sWh\n' "$percentage" "$state" "$rate" "$size"
fi
