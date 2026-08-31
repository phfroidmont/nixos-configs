#!/usr/bin/env bash

set -euo pipefail
: "${FOS_BIN:?set FOS_BIN to the packaged fos executable}"

root=$(mktemp -d)
trap 'jobs -p | xargs -r kill 2>/dev/null || true; rm -rf "$root"' EXIT
bin=$root/bin; flake=$root/flake; log=$root/calls.log; runtime=$root/runtime
export HOME=$root/home
mkdir -p "$bin" "$flake" "$runtime" "$root/Videos" "$HOME"
touch "$flake/flake.nix" "$log"

printf '#!%s\n' "$BASH" >"$bin/backend"
cat >>"$bin/backend" <<'EOF'
set -euo pipefail
name=${0##*/}
printf '%s|%s\n' "$name" "$*" >>"$FOS_TEST_LOG"
case $name in
  nix) printf '%s\n' desktop laptop ;;
  hostname) printf '%s\n' desktop ;;
  playerctl) [[ ${1:-} == -l ]] && printf '%s\n' spotify firefox || printf '%s\n' Playing ;;
  bluetoothctl) [[ ${1:-} == devices ]] && printf '%s\n' 'Device AA:BB:CC:DD:EE:FF Headphones' || printf '%s\n' 'Powered: yes' ;;
  hyprctl) if [[ $* == '-j clients' ]]; then printf '%s\n' '[{"at":[10,20],"size":[800,600]}]'; fi ;;
  nmcli)
    if [[ $* == *'fields SSID device wifi list'* ]]; then printf '%s\n' Cafe 'Cafe [guest] $pecial' Office
    elif [[ $* == *'fields DEVICE,TYPE device status'* ]]; then printf '%s\n' 'wlan0:wifi' 'eth0:ethernet'
    fi
    ;;
  systemctl) if [[ $* == *'list-unit-files'* ]]; then printf '%s\n' 'test.service enabled'; fi ;;
  lsblk) if [[ $* == *'NAME,TYPE'* ]]; then printf '%s\n' '/dev/nvme0n1 disk' '/dev/nvme0n1p1 part'; fi ;;
  vpn) if [[ ${1:-} == list ]]; then printf '%s\n' '  nl-ams-001' '* be-bru-001'; fi ;;
  virsh) if [[ $* == *'--name'* ]]; then printf '%s\n' test-vm; fi ;;
  glab) printf '%s\n' 'Logged in to gitlab.example' ;;
  slurp) [[ ${FOS_TEST_EMPTY_SLURP:-false} == true ]] || printf '%s\n' '0,0 10x10' ;;
  grim) printf '%s' image ;;
  satty|wl-copy) dd of=/dev/null 2>/dev/null ;;
  tesseract) dd of=/dev/null 2>/dev/null; printf '%s\n' words ;;
  wf-recorder) [[ ${FOS_TEST_WF_FAIL:-false} == true ]] && exit 9; trap 'exit 0' INT; while :; do sleep 1; done ;;
  kill) builtin kill -TERM "${2:?missing PID}" ;;
  fos-internal-network-status) printf '%s\n' 'wifi Cafe 90 5180' ;;
  powerprofilesctl) [[ ${1:-} == get ]] && printf '%s\n' balanced ;;
  fos-internal-powerprofiles-list) printf '%s\n' balanced performance power-saver ;;
  launch-terminal) [[ -z ${FOS_TEST_LAUNCH_PATH_FILE:-} ]] || printf '%s\n' "$PATH" >"$FOS_TEST_LAUNCH_PATH_FILE" ;;
  uptime) printf '%s\n' 'up 2 hours' ;;
  uname) printf '%s\n' 'test-kernel' ;;
esac
EOF
chmod +x "$bin/backend"

backends=(nh nix hostname glab auth qs wpctl pulsemixer playerctl hyprctl hyprlock wdisplays nmcli bluetoothctl powerprofilesctl upower systemctl notify-send btop grim slurp satty tesseract wl-copy wf-recorder kill vpn tailscale virsh lshw lscpu free lspci lsusb lsblk sensors fwupdmgr smartctl ip launch-browser launch-terminal launch-editor launch-file-manager show-keybindings uptime uname journalctl fos-internal-audio-output-set-default fos-internal-audio-input-set-default fos-internal-monitor-state fos-internal-brightness-display fos-internal-hyprland-monitor-scaling fos-internal-network-status fos-internal-network-speedtest fos-internal-network-band fos-internal-network-qr fos-internal-battery-status fos-internal-powerprofiles-list fos-internal-powerprofiles-set fos-internal-system-stats)
for backend in "${backends[@]}"; do ln -s backend "$bin/$backend"; done

export FOS_TEST_LOG=$log NH_FLAKE=$flake XDG_RUNTIME_DIR=$runtime XDG_VIDEOS_DIR=$root/Videos
export FOS_NH=$bin/nh FOS_NIX=$bin/nix FOS_HOSTNAME=$bin/hostname FOS_GLAB=$bin/glab FOS_AUTH_COMMAND=$bin/auth
export FOS_QUICKSHELL=$bin/qs FOS_WPCTL=$bin/wpctl FOS_PULSEMIXER=$bin/pulsemixer
export FOS_PLAYERCTL=$bin/playerctl FOS_HYPRCTL=$bin/hyprctl FOS_HYPRLOCK=$bin/hyprlock FOS_WDISPLAYS=$bin/wdisplays
export FOS_NMCLI=$bin/nmcli FOS_BLUETOOTHCTL=$bin/bluetoothctl
export FOS_POWERPROFILESCTL=$bin/powerprofilesctl
export FOS_UPOWER=$bin/upower FOS_SYSTEMCTL=$bin/systemctl FOS_NOTIFY_SEND=$bin/notify-send
export FOS_JOURNALCTL=$bin/journalctl
export FOS_BTOP=$bin/btop FOS_GRIM=$bin/grim FOS_SLURP=$bin/slurp FOS_SATTY=$bin/satty FOS_TESSERACT=$bin/tesseract
export FOS_WL_COPY=$bin/wl-copy FOS_WF_RECORDER=$bin/wf-recorder FOS_VPN_COMMAND=$bin/vpn FOS_TAILSCALE=$bin/tailscale
export FOS_KILL=$bin/kill
export FOS_VIRSH=$bin/virsh FOS_LSHW=$bin/lshw FOS_LSCPU=$bin/lscpu FOS_FREE=$bin/free FOS_LSPCI=$bin/lspci
export FOS_LSUSB=$bin/lsusb FOS_LSBLK=$bin/lsblk FOS_SENSORS=$bin/sensors FOS_FWUPDMGR=$bin/fwupdmgr
export FOS_SMARTCTL=$bin/smartctl FOS_IP=$bin/ip FOS_UPTIME=$bin/uptime FOS_UNAME=$bin/uname
export FOS_LAUNCH_BROWSER=$bin/launch-browser FOS_LAUNCH_TERMINAL=$bin/launch-terminal FOS_LAUNCH_EDITOR=$bin/launch-editor
export FOS_LAUNCH_FILES=$bin/launch-file-manager FOS_KEYBINDINGS=$bin/show-keybindings
export FOS_AUDIO_OUTPUT_SET=$bin/fos-internal-audio-output-set-default FOS_AUDIO_INPUT_SET=$bin/fos-internal-audio-input-set-default
export FOS_MONITOR_STATE=$bin/fos-internal-monitor-state FOS_BRIGHTNESS_DISPLAY=$bin/fos-internal-brightness-display
export FOS_MONITOR_SCALING=$bin/fos-internal-hyprland-monitor-scaling FOS_NETWORK_STATUS=$bin/fos-internal-network-status
export FOS_NETWORK_SPEEDTEST=$bin/fos-internal-network-speedtest FOS_NETWORK_BAND=$bin/fos-internal-network-band
export FOS_NETWORK_QR=$bin/fos-internal-network-qr FOS_BATTERY_STATUS=$bin/fos-internal-battery-status
export FOS_POWERPROFILES_LIST=$bin/fos-internal-powerprofiles-list FOS_POWERPROFILES_SET=$bin/fos-internal-powerprofiles-set
export FOS_SYSTEM_STATS=$bin/fos-internal-system-stats

reset_log() { : >"$log"; }
assert_failure() { if "$FOS_BIN" "$@" >/dev/null 2>&1; then printf 'expected failure: fos %s\n' "$*" >&2; exit 1; fi; }
assert_log() { [[ $(<"$log") == "$1" ]] || { printf 'unexpected log:\n%s\n' "$(<"$log")" >&2; exit 1; }; }
state_value() { local wanted=$1 key value; while IFS=$'\t' read -r key value; do [[ $key == "$wanted" ]] && { printf '%s\n' "$value"; return; }; done <"$runtime/fos/recording.state"; return 1; }
replace_state_value() { local wanted=$1 replacement=$2 key value temporary=$runtime/fos/state.test; : >"$temporary"; while IFS=$'\t' read -r key value; do [[ $key == "$wanted" ]] && value=$replacement; printf '%s\t%s\n' "$key" "$value" >>"$temporary"; done <"$runtime/fos/recording.state"; mv "$temporary" "$runtime/fos/recording.state"; }

# Registry, help, JSON, and the absence of the removed surface.
help=$($FOS_BIN)
grep -Fq 'nixos build [HOST]' <<<"$help"
grep -Fq 'capture record start region' <<<"$help"
commands=$($FOS_BIN commands)
grep -Fq 'network wifi connect SSID' <<<"$commands"
commands_json=$($FOS_BIN commands --json)
jq -e 'length > 80 and any(.[]; .command == "hardware disk")' <<<"$commands_json" >/dev/null
if grep -Eiq 'docker' <<<"$help" || jq -e 'any(.[]; .command | test("docker"; "i"))' <<<"$commands_json" >/dev/null; then exit 1; fi
legacy_backend_prefix='omar''chy-'
if grep -Fq "$legacy_backend_prefix" <<<"$commands_json"; then exit 1; fi
if [[ -n ${FOS_SOURCE:-} ]] && grep -Fq "$legacy_backend_prefix" "$FOS_SOURCE"; then exit 1; fi
assert_failure commands --yaml
[[ $($FOS_BIN version) == 'fos 2.0.0' ]]
assert_failure build
help=$($FOS_BIN help nixos build)
grep -Fq 'Usage: fos nixos build [HOST]' <<<"$help"
help=$($FOS_BIN network wifi --help)
grep -Fq 'Usage: fos network wifi list' <<<"$help"
assert_failure help no-such-command

# Grouped NixOS migration and strict validation.
[[ $($FOS_BIN nixos hosts) == $'desktop\nlaptop' ]]
reset_log; $FOS_BIN nixos build laptop >/dev/null 2>&1; grep -Fq "nh|os build $flake -H laptop" "$log"
reset_log; $FOS_BIN nixos switch >/dev/null 2>&1; grep -Fq "nh|os switch $flake -H desktop --ask" "$log"
reset_log; assert_failure nixos update --all; assert_log ''
reset_log; assert_failure nixos rollback latest

# Safe status/auth output contains no environment secret.
export GITLAB_TOKEN='super-secret-test-token'
status_json=$($FOS_BIN status --json)
if grep -Fq "$GITLAB_TOKEN" <<<"$status_json"; then exit 1; fi
jq -e '.host == "desktop" and .memory and .network and .power_profile == "balanced" and .recording' <<<"$status_json" >/dev/null
doctor_json=$($FOS_BIN doctor --json)
if grep -Fq "$GITLAB_TOKEN" <<<"$doctor_json"; then exit 1; fi
jq -e 'any(.[]; .check == "session:hyprland") and any(.[]; .check | startswith("backend:"))' <<<"$doctor_json" >/dev/null
default_doctor=$(env -u FOS_KEYBINDINGS XDG_DATA_HOME="$root/private-data" "$FOS_BIN" doctor --json)
jq -e 'any(.[]; .check == "backend:menu-keybindings" and .status == "missing")' <<<"$default_doctor" >/dev/null
if $FOS_BIN auth status 2>/dev/null | grep -Fq "$GITLAB_TOKEN"; then exit 1; fi
reset_log; $FOS_BIN auth refresh gitlab.example >/dev/null 2>&1; assert_log 'auth|gitlab.example'

# Every command domain has dispatch or validation coverage.
reset_log; $FOS_BIN menu apps >/dev/null 2>&1; assert_log 'qs|-c desktop ipc call -- launcher toggle'
mkdir -p "$root/private-data/fos/bin"; cp "$bin/backend" "$root/private-data/fos/bin/menu-keybindings"
reset_log; env -u FOS_KEYBINDINGS XDG_DATA_HOME="$root/private-data" "$FOS_BIN" menu keybindings >/dev/null 2>&1; assert_log 'menu-keybindings|'
reset_log; $FOS_BIN launch files >/dev/null 2>&1; assert_log 'launch-file-manager|'
mkdir -p "$root/hash-fos-internal-test/bin" "$root/hash-quickshell-desktop-config/bin" "$root/hash-quickshell-panel-tools/bin"
launch_path_file=$root/launch-path
reset_log
PATH="$root/hash-fos-internal-test/bin:$root/hash-quickshell-desktop-config/bin:$root/hash-quickshell-panel-tools/bin:$PATH" \
  FOS_TEST_LAUNCH_PATH_FILE=$launch_path_file "$FOS_BIN" launch terminal >/dev/null 2>&1
if grep -Eq 'fos-internal|quickshell-(desktop-config|panel-tools)' "$launch_path_file"; then exit 1; fi
reset_log; $FOS_BIN audio volume 101 >/dev/null 2>&1 && exit 1 || true; assert_log ''
reset_log; $FOS_BIN audio volume +5 >/dev/null 2>&1; assert_log 'wpctl|set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+'
reset_log; $FOS_BIN audio output set 42 sink.name >/dev/null 2>&1; assert_log 'fos-internal-audio-output-set-default|42 sink.name'
reset_log; $FOS_BIN audio input set 7 source.name >/dev/null 2>&1; assert_log 'fos-internal-audio-input-set-default|7 source.name'
reset_log; $FOS_BIN media next spotify >/dev/null 2>&1; assert_log 'playerctl|-p spotify next'
reset_log; assert_failure display scale nope; $FOS_BIN display status >/dev/null 2>&1; assert_log 'fos-internal-monitor-state|'
reset_log; $FOS_BIN display brightness -5 >/dev/null 2>&1; assert_log 'fos-internal-brightness-display|5%-'
reset_log; $FOS_BIN display scale up >/dev/null 2>&1; assert_log 'fos-internal-hyprland-monitor-scaling|up'
reset_log; $FOS_BIN network status --verbose >/dev/null 2>&1; assert_log 'fos-internal-network-status|--verbose'
reset_log; $FOS_BIN network speedtest down >/dev/null 2>&1; assert_log 'fos-internal-network-speedtest|down'
reset_log; $FOS_BIN network wifi band 6 >/dev/null 2>&1; assert_log 'fos-internal-network-band|6'
reset_log; $FOS_BIN network wifi connect Cafe >/dev/null 2>&1; assert_log 'nmcli|--ask device wifi connect Cafe'
reset_log; assert_failure network wifi share; assert_log ''
reset_log; $FOS_BIN network wifi share --reveal >/dev/null 2>&1; assert_log 'fos-internal-network-qr|'
reset_log; assert_failure bluetooth pair invalid; $FOS_BIN bluetooth connect AA:BB:CC:DD:EE:FF >/dev/null 2>&1; assert_log 'bluetoothctl|connect AA:BB:CC:DD:EE:FF'
reset_log; $FOS_BIN power profiles >/dev/null 2>&1; assert_log 'fos-internal-powerprofiles-list|'
reset_log; $FOS_BIN power battery >/dev/null 2>&1; assert_log 'fos-internal-battery-status|'
reset_log; $FOS_BIN power profile battery power-saver >/dev/null 2>&1; assert_log 'fos-internal-powerprofiles-set|battery power-saver'
reset_log; $FOS_BIN system stats >/dev/null 2>&1; assert_log 'fos-internal-system-stats|'
reset_log; $FOS_BIN system lock >/dev/null 2>&1; assert_log 'hyprlock|'
reset_log; $FOS_BIN notifications send Title Body >/dev/null 2>&1; assert_log 'notify-send|Title Body'
reset_log; $FOS_BIN notifications status >/dev/null 2>&1; assert_log 'qs|-c desktop ipc call -- notifications dndState'
reset_log; $FOS_BIN clipboard open >/dev/null 2>&1; assert_log 'qs|-c desktop ipc call -- clipboard toggle'
reset_log; $FOS_BIN capture screenshot screen >/dev/null 2>&1; grep -Fxq 'grim|-' "$log"; grep -Fxq 'satty|-f -' "$log"
reset_log; $FOS_BIN capture screenshot window >/dev/null 2>&1
grep -Fq 'hyprctl|-j clients' "$log"; grep -Fq 'slurp|-r' "$log"; grep -Fq 'grim|-g 0,0 10x10 -' "$log"
reset_log; $FOS_BIN capture ocr region >/dev/null 2>&1; grep -Fq 'tesseract|stdin stdout -l eng+fre' "$log"
reset_log; FOS_TEST_EMPTY_SLURP=true assert_failure capture screenshot region; assert_log 'slurp|'
reset_log; $FOS_BIN vpn status >/dev/null 2>&1; assert_log 'vpn|status'
reset_log; $FOS_BIN tailscale status >/dev/null 2>&1; assert_log 'tailscale|status'
reset_log; $FOS_BIN service status --user test.service >/dev/null 2>&1; assert_log 'systemctl|--user status test.service'
reset_log; assert_failure service status '../bad'; assert_log ''
reset_log; $FOS_BIN vm status test-vm >/dev/null 2>&1; assert_log 'virsh|-c qemu:///system dominfo test-vm'
reset_log; $FOS_BIN hardware disk /dev/nvme0n1 >/dev/null 2>&1; assert_log 'smartctl|--info --health /dev/nvme0n1'
reset_log; assert_failure hardware disk /dev/../secret; assert_log ''

# Disruptive operations never dispatch without confirmation.
for invocation in \
  'system reboot' 'network wifi disconnect wlan0' 'bluetooth forget AA:BB:CC:DD:EE:FF' \
  'clipboard clear' 'vpn down' 'tailscale up' 'service restart test.service' 'vm shutdown test-vm'; do
  reset_log
  read -r -a args <<<"$invocation"
  assert_failure "${args[@]}"
  assert_log ''
done
reset_log; $FOS_BIN system reboot --yes >/dev/null 2>&1; assert_log 'systemctl|reboot'
reset_log; $FOS_BIN system logout --yes >/dev/null 2>&1; assert_log 'hyprctl|dispatch exit'
reset_log; $FOS_BIN vpn switch nl-ams-001 --yes >/dev/null 2>&1; assert_log 'vpn|switch nl-ams-001'
reset_log; $FOS_BIN clipboard clear --yes >/dev/null 2>&1; assert_log 'qs|-c desktop ipc call -- clipboard clear'

# Recording uses a private atomic lock, unique output reservation, and strong process identity.
reset_log
FOS_RECORDING_STARTUP_WAIT=0.5 $FOS_BIN capture record start screen >"$root/first-output" 2>/dev/null &
starter=$!
for _ in {1..100}; do
  if [[ -f $runtime/fos/recording.lock ]] && grep -Fq 'wf-recorder|--overwrite -f' "$log"; then break; fi
  sleep 0.01
done
[[ -f $runtime/fos/recording.lock ]]
grep -Fq 'wf-recorder|--overwrite -f' "$log"
assert_failure capture record start screen
assert_failure capture record stop
wait "$starter"
first_output=$(<"$root/first-output")
pid=$(state_value pid)
[[ $pid =~ ^[0-9]+$ && -d /proc/$pid && -f $first_output ]]
grep -Fq 'wf-recorder|--overwrite -f' "$log"
[[ $(stat -c %a "$runtime/fos") == 700 ]]
for field in pid start_time argv0 exe backend output; do state_value "$field" >/dev/null; done
$FOS_BIN capture record status | grep -Fq "pid $pid"

# A changed start time or backend identity is never signaled.
start_time=$(state_value start_time)
replace_state_value start_time "$((start_time + 1))"
assert_failure capture record status
reset_log; assert_failure capture record stop; assert_log ''
replace_state_value start_time "$start_time"
backend=$(state_value backend)
replace_state_value backend "$bin/not-the-recorder"
reset_log; assert_failure capture record stop; assert_log ''
replace_state_value backend "$backend"

if ! $FOS_BIN capture record stop >/dev/null 2>"$root/record-stop.err"; then
  printf 'record stop failed: %s\n' "$(<"$root/record-stop.err")" >&2
  exit 1
fi
[[ ! -e $runtime/fos/recording.state && -f $runtime/fos/recording.lock ]]

# Output names remain unique even within one second.
$FOS_BIN capture record start screen >"$root/second-output" 2>/dev/null
second_output=$(<"$root/second-output")
[[ $second_output != "$first_output" ]]
$FOS_BIN capture record stop >/dev/null 2>&1

# Immediate startup failure commits no state and removes its reserved output and lock.
outputs_before=$(printf '%s\n' "$root"/Videos/fos-recording-*.mp4)
FOS_TEST_WF_FAIL=true assert_failure capture record start screen
outputs_after=$(printf '%s\n' "$root"/Videos/fos-recording-*.mp4)
[[ $outputs_after == "$outputs_before" && ! -e $runtime/fos/recording.state && -f $runtime/fos/recording.lock ]]

# Invalid stale state reports inactive and is cleaned without signaling on the next start.
mkdir -p "$runtime/fos"
printf 'pid\t%s\nstart_time\t1\nargv0\tforged\nexe\tforged\nbackend\t%s\noutput\t%s\n' $$ "$bin/wf-recorder" "$root/forged.mp4" >"$runtime/fos/recording.state"
assert_failure capture record status
jq -e '.recording == "inactive"' < <($FOS_BIN status --json) >/dev/null
reset_log; $FOS_BIN capture record start screen >/dev/null 2>&1
if grep -Fq 'kill|' "$log"; then exit 1; fi
$FOS_BIN capture record stop >/dev/null 2>&1

# The explicit state path override covers fallback behavior without touching /run.
fallback=$root/fallback-runtime
env -u XDG_RUNTIME_DIR FOS_RUNTIME_STATE_DIR="$fallback" "$FOS_BIN" status --json | jq -e '.recording == "inactive"' >/dev/null

# Static and dynamic completion candidates come only through the hidden API.
completion=$($FOS_BIN __complete '')
grep -Fq $'nixos\t' <<<"$completion"
completion=$($FOS_BIN __complete network ''); grep -Fq $'wifi\t' <<<"$completion"
completion=$($FOS_BIN __complete network wifi ''); grep -Fq $'connect\t' <<<"$completion"
completion=$($FOS_BIN __complete media next ''); grep -Fq $'spotify\tdynamic value' <<<"$completion"
completion=$($FOS_BIN __complete nixos build l); grep -Fq $'laptop\tdynamic value' <<<"$completion"
completion=$($FOS_BIN __complete bluetooth connect A); grep -Fq $'AA:BB:CC:DD:EE:FF\tdynamic value' <<<"$completion"
completion=$($FOS_BIN __complete vm start t); grep -Fq $'test-vm\tdynamic value' <<<"$completion"
completion=$($FOS_BIN __complete commands -); grep -Fq -- $'--json\t' <<<"$completion"
completion=$($FOS_BIN __complete network status -); grep -Fq -- $'--verbose\t' <<<"$completion"
completion=$($FOS_BIN __complete audio mute ''); grep -Fq $'input\t' <<<"$completion"
completion=$($FOS_BIN __complete network speedtest ''); grep -Fq $'down\t' <<<"$completion"
completion=$($FOS_BIN __complete network wifi band ''); grep -Fq $'2.4\t' <<<"$completion"
completion=$($FOS_BIN __complete bluetooth power ''); grep -Fq $'toggle\t' <<<"$completion"
completion=$($FOS_BIN __complete power profile ''); grep -Fq $'autodetect\t' <<<"$completion"
completion=$($FOS_BIN __complete power profile ac ''); grep -Fq $'performance\t' <<<"$completion"
completion=$($FOS_BIN __complete help network ''); grep -Fq $'wifi\t' <<<"$completion"
completion=$($FOS_BIN __complete notifications dnd ''); grep -Fq $'on\t' <<<"$completion"
completion=$($FOS_BIN __complete capture record start screen -); grep -Fq -- $'--audio\t' <<<"$completion"
completion=$($FOS_BIN __complete network wifi share -); grep -Fq -- $'--reveal\t' <<<"$completion"
completion=$($FOS_BIN __complete network wifi connect C); grep -Fq $'Cafe\t' <<<"$completion"
grep -Fxq $'Cafe [guest] $pecial\tdynamic value' < <($FOS_BIN __complete network wifi connect 'Cafe ')
completion=$($FOS_BIN __complete network wifi disconnect w); grep -Fq $'wlan0\t' <<<"$completion"
completion=$($FOS_BIN __complete service status ''); grep -Fq $'test.service\t' <<<"$completion"; grep -Fq -- $'--user\t' <<<"$completion"
completion=$($FOS_BIN __complete hardware disk /); grep -Fq $'/dev/nvme0n1\t' <<<"$completion"
completion=$($FOS_BIN __complete system reboot -); grep -Fq -- $'--yes\t' <<<"$completion"

if [[ -n ${FOS_COMPLETION:-} ]]; then
  completion=$(PATH="${FOS_BIN%/*}:$PATH" zsh -c '
    compadd() {
      while (( $# )); do
        if [[ $1 == -- ]]; then shift; print -rl -- "$@"; return; fi
        shift
      done
    }
    words=(fos bluetooth connect A)
    CURRENT=4
    source "$FOS_COMPLETION"
  ')
  grep -Fxq 'AA:BB:CC:DD:EE:FF' <<<"$completion"

  completion=$(PATH="${FOS_BIN%/*}:$PATH" zsh -c '
    compadd() {
      while (( $# )); do
        if [[ $1 == -- ]]; then shift; print -rl -- "$@"; return; fi
        shift
      done
    }
    words=(fos network wifi connect "Cafe " trailing-argument)
    CURRENT=5
    source "$FOS_COMPLETION"
  ')
  grep -Fxq "Cafe [guest] \$pecial" <<<"$completion"
fi

printf '%s\n' 'fos v2 tests passed'
