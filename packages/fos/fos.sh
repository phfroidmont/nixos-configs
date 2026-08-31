# shellcheck shell=bash

set -euo pipefail

# One registry drives help, `commands`, and completion.  Fields are separated by |.
read -r -d '' COMMANDS <<'EOF' || true
version|version|Show the FOS version
help|help [COMMAND...]|Show command help
commands|commands [--json]|List commands
status|status [--json]|Show a safe system status
doctor|doctor [--json]|Check command backends
nixos hosts|nixos hosts|List operational host configurations
nixos build|nixos build [HOST]|Build a host without activating it
nixos test|nixos test|Temporarily activate the local host
nixos switch|nixos switch|Activate and persist the local host
nixos boot|nixos boot|Select the local host for the next boot
nixos update|nixos update [INPUT...]|Update inputs and build the local host
nixos generations|nixos generations|List NixOS generations
nixos rollback|nixos rollback [GENERATION]|Roll back a NixOS generation
auth status|auth status|Show GitLab authentication status
auth refresh|auth refresh [GITLAB_HOST]|Refresh Nix GitLab credentials
menu apps|menu apps|Open the application launcher
menu clipboard|menu clipboard|Open clipboard history
menu keybindings|menu keybindings|Open the keybindings helper
menu notifications|menu notifications|Open notification history
menu agents|menu agents|Open the agents menu
menu audio|menu audio|Open audio controls
menu bluetooth|menu bluetooth|Open Bluetooth controls
menu clock|menu clock|Open clock controls
menu display|menu display|Open display controls
menu network|menu network|Open network controls
menu power|menu power|Open power controls
launch browser|launch browser|Launch the browser
launch terminal|launch terminal|Launch the terminal
launch editor|launch editor|Launch the editor
launch files|launch files|Launch the file manager
audio status|audio status|Show audio status
audio volume|audio volume <+N|-N|N>|Set or adjust output volume
audio mute|audio mute [output|input]|Toggle mute
audio output list|audio output list|List audio outputs
audio output set|audio output set NODE_ID PULSE_NAME|Select the default output
audio input list|audio input list|List audio inputs
audio input set|audio input set NODE_ID PULSE_NAME|Select the default input
audio mixer|audio mixer|Open the audio mixer
media status|media status [PLAYER]|Show media status
media play-pause|media play-pause [PLAYER]|Play or pause media
media next|media next [PLAYER]|Play the next item
media previous|media previous [PLAYER]|Play the previous item
media stop|media stop [PLAYER]|Stop media
display status|display status|Show display status
display brightness|display brightness [VALUE]|Show or set brightness
display scale|display scale <up|down|SCALE>|Adjust display scale
display configure|display configure|Open display configuration
network status|network status [--verbose]|Show network status
network speedtest|network speedtest <down|up>|Test network transfer speed
network wifi list|network wifi list|List Wi-Fi networks
network wifi connect|network wifi connect SSID|Connect to Wi-Fi interactively
network wifi disconnect|network wifi disconnect [INTERFACE] [--yes]|Disconnect Wi-Fi
network wifi band|network wifi band [auto|2.4|5|6]|Show or select Wi-Fi band
network wifi share|network wifi share [INTERFACE] --reveal|Reveal a Wi-Fi QR code
bluetooth status|bluetooth status|Show Bluetooth status
bluetooth power|bluetooth power <on|off|toggle>|Control Bluetooth power
bluetooth pair|bluetooth pair ADDRESS|Pair a Bluetooth device
bluetooth connect|bluetooth connect ADDRESS|Connect a Bluetooth device
bluetooth disconnect|bluetooth disconnect ADDRESS|Disconnect a Bluetooth device
bluetooth forget|bluetooth forget ADDRESS [--yes]|Forget a Bluetooth device
power battery|power battery|Show battery status
power profiles|power profiles|List power profiles
power profile|power profile <autodetect|ac|battery> [PROFILE]|Select a power profile
system stats|system stats|Show system statistics
system monitor|system monitor|Open the system monitor
system lock|system lock|Lock the session
system logout|system logout [--yes]|Log out
system suspend|system suspend [--yes]|Suspend
system hibernate|system hibernate [--yes]|Hibernate
system reboot|system reboot [--yes]|Reboot
system shutdown|system shutdown [--yes]|Shut down
notifications status|notifications status|Show notification state
notifications dismiss|notifications dismiss [--all]|Dismiss notifications
notifications dnd|notifications dnd <on|off|toggle>|Control do-not-disturb
notifications history|notifications history|Open notification history
notifications send|notifications send TITLE [BODY]|Send a notification
clipboard open|clipboard open|Open clipboard history
clipboard clear|clipboard clear --yes|Clear Quickshell clipboard state
capture screenshot region|capture screenshot region|Capture a region
capture screenshot window|capture screenshot window|Capture a window
capture screenshot screen|capture screenshot screen|Capture the screen
capture ocr region|capture ocr region|Copy text from a region
capture record start region|capture record start region [--audio]|Record a region
capture record start screen|capture record start screen [--audio]|Record the screen
capture record status|capture record status|Show recording status
capture record stop|capture record stop|Stop the FOS recording
vpn status|vpn status|Show VPN status
vpn list|vpn list|List VPN servers
vpn up|vpn up [--yes]|Start the VPN
vpn down|vpn down [--yes]|Stop the VPN
vpn switch|vpn switch SERVER [--yes]|Switch VPN server
tailscale status|tailscale status|Show Tailscale status
tailscale up|tailscale up [--yes]|Start Tailscale
tailscale down|tailscale down [--yes]|Stop Tailscale
service status|service status [--user] UNIT|Show service status
service restart|service restart [--user] UNIT [--yes]|Restart a service
service logs|service logs [--user] UNIT|Show service logs
vm list|vm list|List virtual machines
vm status|vm status NAME|Show virtual machine status
vm start|vm start NAME|Start a virtual machine
vm shutdown|vm shutdown NAME [--yes]|Shut down a virtual machine
hardware summary|hardware summary|Show hardware summary
hardware cpu|hardware cpu|Show CPU information
hardware memory|hardware memory|Show memory information
hardware gpu|hardware gpu|Show GPU information
hardware storage|hardware storage|Show storage information
hardware sensors|hardware sensors|Show sensor information
hardware battery|hardware battery|Show battery information
hardware network|hardware network|Show network hardware
hardware pci|hardware pci|Show PCI devices
hardware usb|hardware usb|Show USB devices
hardware firmware|hardware firmware|Show firmware information
hardware disk|hardware disk DEVICE|Show read-only disk information
EOF

NH=${FOS_NH:-nh}; NIX=${FOS_NIX:-nix}; HOSTNAME=${FOS_HOSTNAME:-hostname}
GLAB=${FOS_GLAB:-glab}; AUTH=${FOS_AUTH_COMMAND:-refresh-nix-gitlab-token}; QS=${FOS_QUICKSHELL:-qs}
WPCTL=${FOS_WPCTL:-wpctl}; PULSEMIXER=${FOS_PULSEMIXER:-pulsemixer}
PLAYERCTL=${FOS_PLAYERCTL:-playerctl}
HYPRCTL=${FOS_HYPRCTL:-hyprctl}; WDISPLAYS=${FOS_WDISPLAYS:-wdisplays}; NMCLI=${FOS_NMCLI:-nmcli}
BLUETOOTHCTL=${FOS_BLUETOOTHCTL:-bluetoothctl}
POWERPROFILESCTL=${FOS_POWERPROFILESCTL:-powerprofilesctl}
UPOWER=${FOS_UPOWER:-upower}; SYSTEMCTL=${FOS_SYSTEMCTL:-systemctl}; JOURNALCTL=${FOS_JOURNALCTL:-journalctl}
HYPRLOCK=${FOS_HYPRLOCK:-hyprlock}
NOTIFY_SEND=${FOS_NOTIFY_SEND:-notify-send}; BTOP=${FOS_BTOP:-btop}; GRIM=${FOS_GRIM:-grim}; SLURP=${FOS_SLURP:-slurp}
SATTY=${FOS_SATTY:-satty}; TESSERACT=${FOS_TESSERACT:-tesseract}; WL_COPY=${FOS_WL_COPY:-wl-copy}
WF_RECORDER=${FOS_WF_RECORDER:-wf-recorder}; VPN=${FOS_VPN_COMMAND:-aegis-vpn}; TAILSCALE=${FOS_TAILSCALE:-tailscale}
VIRSH=${FOS_VIRSH:-virsh}; LSHW=${FOS_LSHW:-lshw}; LSCPU=${FOS_LSCPU:-lscpu}; FREE=${FOS_FREE:-free}
LSPCI=${FOS_LSPCI:-lspci}; LSUSB=${FOS_LSUSB:-lsusb}; LSBLK=${FOS_LSBLK:-lsblk}; SENSORS=${FOS_SENSORS:-sensors}
FWUPDMGR=${FOS_FWUPDMGR:-fwupdmgr}; SMARTCTL=${FOS_SMARTCTL:-smartctl}; IP=${FOS_IP:-ip}
UPTIME=${FOS_UPTIME:-@fos-uptime@}
UNAME=${FOS_UNAME:-uname}
JQ=${FOS_JQ:-jq}
KILL=${FOS_KILL:-kill}
FLOCK=${FOS_FLOCK:-flock}
LAUNCH_BROWSER=${FOS_LAUNCH_BROWSER:-launch-browser}
LAUNCH_TERMINAL=${FOS_LAUNCH_TERMINAL:-launch-terminal}; LAUNCH_EDITOR=${FOS_LAUNCH_EDITOR:-launch-editor}
LAUNCH_FILES=${FOS_LAUNCH_FILES:-launch-file-manager}
KEYBINDINGS=${FOS_KEYBINDINGS:-${XDG_DATA_HOME:-$HOME/.local/share}/fos/bin/menu-keybindings}
AUDIO_OUTPUT_SET=${FOS_AUDIO_OUTPUT_SET:-fos-internal-audio-output-set-default}
AUDIO_INPUT_SET=${FOS_AUDIO_INPUT_SET:-fos-internal-audio-input-set-default}
MONITOR_STATE=${FOS_MONITOR_STATE:-fos-internal-monitor-state}
BRIGHTNESS_DISPLAY=${FOS_BRIGHTNESS_DISPLAY:-fos-internal-brightness-display}
MONITOR_SCALING=${FOS_MONITOR_SCALING:-fos-internal-hyprland-monitor-scaling}
NETWORK_STATUS=${FOS_NETWORK_STATUS:-fos-internal-network-status}
NETWORK_SPEEDTEST=${FOS_NETWORK_SPEEDTEST:-fos-internal-network-speedtest}
NETWORK_BAND=${FOS_NETWORK_BAND:-fos-internal-network-band}
NETWORK_QR=${FOS_NETWORK_QR:-fos-internal-network-qr}
BATTERY_STATUS=${FOS_BATTERY_STATUS:-fos-internal-battery-status}
POWERPROFILES_LIST=${FOS_POWERPROFILES_LIST:-fos-internal-powerprofiles-list}
POWERPROFILES_SET=${FOS_POWERPROFILES_SET:-fos-internal-powerprofiles-set}
SYSTEM_STATS=${FOS_SYSTEM_STATS:-fos-internal-system-stats}

fail() { printf 'fos: %s\n' "$1" >&2; exit 2; }
need() { if [[ $1 == */* ]]; then [[ -x $1 ]] || fail "required command is not executable: $1"; else command -v "$1" >/dev/null || fail "required command is unavailable: $1"; fi; }
print_command() { printf '+' >&2; printf ' %q' "$@" >&2; printf '\n' >&2; }
exec_command() { need "$1"; print_command "$@"; exec "$@"; }
run_command() { need "$1"; print_command "$@"; "$@"; }
no_args() { (($# == 0)) || fail 'unexpected arguments'; }
safe_value() { [[ -n $1 && $1 != -* && $1 != *$'\n'* ]] || fail "invalid value: $1"; }
address() { [[ $1 =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || fail "invalid Bluetooth address: $1"; }
unit_name() { [[ $1 =~ ^[A-Za-z0-9_.@:-]+$ ]] || fail "invalid service unit: $1"; }
confirm() {
  local operation=$1; shift
  if (($# == 1)) && [[ $1 == --yes ]]; then return; fi
  (($# == 0)) || fail "$operation accepts only --yes"
  [[ -t 0 ]] || fail "$operation requires --yes in a non-interactive session"
  local answer; read -r -p "$operation? [y/N] " answer
  [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || fail 'cancelled'
}

registry_rows() {
  local line key rest syntax description
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    key=${line%%|*}; rest=${line#*|}; description=${rest##*|}; syntax=${rest%|*}
    printf '%s\t%s\t%s\n' "$key" "$syntax" "$description"
  done <<<"$COMMANDS"
}
registry_json() { registry_rows | jq -Rsc 'split("\n") | map(select(length>0) | split("\t") | {command:.[0], usage:.[1], description:.[2]})'; }
usage() {
  printf '%s\n\n%s\n' 'Froidmont Operating System command center (v2)' 'Usage: fos <command> [arguments]'
  printf '%s\n' 'Commands:'
  while IFS=$'\t' read -r _ syntax description; do printf '  %-48s %s\n' "$syntax" "$description"; done < <(registry_rows)
}

commands_command() { if (($# == 0)); then while IFS=$'\t' read -r _ syntax description; do printf '%-48s %s\n' "$syntax" "$description"; done < <(registry_rows); elif (($# == 1)) && [[ $1 == --json ]]; then registry_json; else fail 'commands accepts only --json'; fi; }

help_command() {
  local requested key syntax description found=false
  if (($# == 0)); then
    usage
    return
  fi

  requested=$*
  while IFS=$'\t' read -r key syntax description; do
    if [[ $key == "$requested" || $key == "$requested "* ]]; then
      printf 'Usage: fos %s\n  %s\n' "$syntax" "$description"
      found=true
    fi
  done < <(registry_rows)
  $found || fail "unknown command path: $requested"
}

completion_add() {
  local value=$1 description=$2
  [[ $value != *$'\t'* && $value != *$'\n'* ]] || return 0
  [[ -n $value && $value == "$prefix"* && -z ${seen[$value]:-} ]] || return 0
  printf '%s\t%s\n' "$value" "$description"
  seen[$value]=1
}

completion() {
  local -a entered path_words help_words
  local -a completion_scope=()
  local prefix key _usage description i candidate dynamic='' context
  local -A seen=()
  entered=("$@"); ((${#entered[@]})) || entered=('')
  prefix=${entered[-1]}; unset 'entered[-1]'
  context=${entered[*]}
  while IFS=$'\t' read -r key _usage description; do
    read -r -a path_words <<<"$key"
    ((${#entered[@]} < ${#path_words[@]})) || continue
    for ((i=0; i<${#entered[@]}; i++)); do [[ ${entered[i]} == "${path_words[i]}" ]] || continue 2; done
    candidate=${path_words[${#entered[@]}]}
    completion_add "$candidate" "$description"
  done < <(registry_rows)

  if [[ ${entered[0]:-} == help ]]; then
    help_words=("${entered[@]:1}")
    while IFS=$'\t' read -r key _usage description; do
      read -r -a path_words <<<"$key"
      ((${#help_words[@]} < ${#path_words[@]})) || continue
      for ((i=0; i<${#help_words[@]}; i++)); do [[ ${help_words[i]} == "${path_words[i]}" ]] || continue 2; done
      completion_add "${path_words[${#help_words[@]}]}" "$description"
    done < <(registry_rows)
  fi

  if [[ ${entered[0]:-} == help ]]; then
    local -a help_entered=("${entered[@]:1}")
    while IFS=$'\t' read -r key _usage description; do
      read -r -a path_words <<<"$key"
      ((${#help_entered[@]} < ${#path_words[@]})) || continue
      for ((i = 0; i < ${#help_entered[@]}; i++)); do
        [[ ${help_entered[i]} == "${path_words[i]}" ]] || continue 2
      done
      completion_add "${path_words[${#help_entered[@]}]}" "$description"
    done < <(registry_rows)
  fi

  case $context in
    'nixos build') dynamic=$(operational_hosts "$(flake_path)" 2>/dev/null || true) ;;
    'media status'|'media play-pause'|'media next'|'media previous'|'media stop') dynamic=$($PLAYERCTL -l 2>/dev/null || true) ;;
    'vpn switch') dynamic=$($VPN list 2>/dev/null | sed -E 's/^[*[:space:]]+//' || true) ;;
    'bluetooth pair'|'bluetooth connect'|'bluetooth disconnect'|'bluetooth forget') dynamic=$($BLUETOOTHCTL devices 2>/dev/null | sed -E 's/^Device ([^ ]+).*/\1/' || true) ;;
    'vm status'|'vm start'|'vm shutdown') dynamic=$($VIRSH -c qemu:///system list --all --name 2>/dev/null || true) ;;
    'network wifi connect') dynamic=$($NMCLI --terse --escape no --fields SSID device wifi list --rescan no 2>/dev/null | sed '/^$/d' || true) ;;
    'network wifi disconnect'|'network wifi share') dynamic=$($NMCLI --terse --fields DEVICE,TYPE device status 2>/dev/null | sed -n 's/:wifi$//p' || true) ;;
    'hardware disk') dynamic=$($LSBLK --paths --noheadings --raw --output NAME,TYPE 2>/dev/null | while read -r candidate _usage; do [[ $_usage == disk ]] && printf '%s\n' "$candidate"; done || true) ;;
    'power profile ac'|'power profile battery') dynamic=$($POWERPROFILES_LIST 2>/dev/null || true) ;;
    'service status'|'service restart'|'service logs'|'service status --user'|'service restart --user'|'service logs --user')
      [[ $context == *' --user' ]] && completion_scope=(--user)
      dynamic=$($SYSTEMCTL "${completion_scope[@]}" list-unit-files --no-legend --plain 2>/dev/null | sed -E 's/[[:space:]].*//' || true)
      ;;
  esac

  while IFS= read -r candidate; do completion_add "$candidate" 'dynamic value'; done <<<"$dynamic"

  case $context in
    commands|status|doctor) completion_add --json 'Return JSON' ;;
    'network status') completion_add --verbose 'Show detailed network status' ;;
    'audio mute') completion_add output 'Mute output'; completion_add input 'Mute input' ;;
    'network speedtest') completion_add down 'Test download speed'; completion_add up 'Test upload speed' ;;
    'network wifi band') for candidate in auto 2.4 5 6; do completion_add "$candidate" 'Wi-Fi band'; done ;;
    'bluetooth power') for candidate in on off toggle; do completion_add "$candidate" 'Bluetooth power state'; done ;;
    'power profile') for candidate in autodetect ac battery; do completion_add "$candidate" 'Power source mode'; done ;;
    'notifications dnd') for candidate in on off toggle; do completion_add "$candidate" 'Do-not-disturb state'; done ;;
    'capture record start region'|'capture record start screen') completion_add --audio 'Record audio' ;;
    'network wifi share'|network\ wifi\ share\ *) completion_add --reveal 'Allow revealing Wi-Fi credentials' ;;
    'service status'|'service logs') completion_add --user 'Use the user service manager' ;;
    'service restart') completion_add --user 'Use the user service manager'; completion_add --yes 'Skip confirmation' ;;
    'system logout'|'system suspend'|'system hibernate'|'system reboot'|'system shutdown'|'network wifi disconnect'|'bluetooth forget'|'clipboard clear'|'vpn up'|'vpn down'|'tailscale up'|'tailscale down'|'vm shutdown'|vpn\ switch\ *|network\ wifi\ disconnect\ *|bluetooth\ forget\ *|service\ restart\ *|vm\ shutdown\ *) completion_add --yes 'Skip confirmation' ;;
  esac
  return 0
}

flake_path() { local flake=${NH_OS_FLAKE:-${NH_FLAKE:-}}; [[ -n $flake ]] || fail 'NH_OS_FLAKE and NH_FLAKE are unset'; [[ -d $flake && -f $flake/flake.nix ]] || fail "configured flake is invalid: $flake"; printf '%s\n' "$flake"; }
operational_hosts() { need "$NIX"; "$NIX" eval --raw "$1#nixosConfigurations" --apply 'configs: builtins.concatStringsSep "\n" (builtins.filter (name: name != "aegis-installer") (builtins.attrNames configs)) + "\n"'; }
local_host() { need "$HOSTNAME"; "$HOSTNAME"; }
require_host() { local hosts; hosts=$(operational_hosts "$1"); grep -Fxq -- "$2" <<<"$hosts" || fail "unknown operational host: $2"; }
nixos_command() {
  local action=${1:-}; shift || true; local flake host input; local -a updates=()
  case $action in
    hosts) no_args "$@"; operational_hosts "$(flake_path)" ;;
    build) (($# <= 1)) || fail 'nixos build accepts at most one host'; flake=$(flake_path); host=${1:-$(local_host)}; require_host "$flake" "$host"; exec_command "$NH" os build "$flake" -H "$host" ;;
    test|switch|boot) no_args "$@"; flake=$(flake_path); host=$(local_host); require_host "$flake" "$host"; exec_command "$NH" os "$action" "$flake" -H "$host" --ask ;;
    update) for input in "$@"; do safe_value "$input"; updates+=(--update-input "$input"); done; flake=$(flake_path); host=$(local_host); require_host "$flake" "$host"; if (($#)); then exec_command "$NH" os build "$flake" -H "$host" "${updates[@]}"; else exec_command "$NH" os build "$flake" -H "$host" --update; fi ;;
    generations) no_args "$@"; exec_command "$NH" os info ;;
    rollback) (($# <= 1)) || fail 'nixos rollback accepts at most one generation'; if (($#)); then [[ $1 =~ ^[1-9][0-9]*$ ]] || fail 'invalid generation'; exec_command "$NH" os rollback --to "$1" --ask; else exec_command "$NH" os rollback --ask; fi ;;
    *) fail 'nixos requires a valid command' ;;
  esac
}

auth_command() { local action=${1:-}; shift || true; case $action in status) no_args "$@"; exec_command "$GLAB" auth status;; refresh) (($# <= 1)) || fail 'auth refresh accepts at most one host'; (($# == 0)) || safe_value "$1"; exec_command "$AUTH" "$@";; *) fail 'auth requires status or refresh';; esac; }
require_session() { [[ -n ${XDG_RUNTIME_DIR:-} ]] || fail 'a graphical session is required'; }
qs() { require_session; exec_command "$QS" -c desktop ipc call -- "$@"; }
menu_command() { local item=${1:-}; shift || true; no_args "$@"; case $item in apps) qs launcher toggle;; clipboard) qs clipboard toggle;; keybindings) exec_command "$KEYBINDINGS";; notifications) qs notifications showHistory;; agents) qs shell toggle omarchy.agents '{}';; audio) qs shell toggle omarchy.audio '{}';; bluetooth) qs shell toggle omarchy.bluetooth '{}';; clock) qs shell toggle omarchy.clock '{}';; display) qs shell toggle omarchy.monitor '{}';; network) qs shell toggle omarchy.network '{}';; power) qs shell toggle omarchy.power '{}';; *) fail 'invalid menu';; esac; }

public_path() {
  local entry result=''
  local -a entries
  IFS=: read -r -a entries <<<"$PATH"
  for entry in "${entries[@]}"; do
    [[ -n $entry ]] || continue
    case $entry in
      *-fos-internal-*/bin | *-quickshell-desktop-config/bin | *-quickshell-panel-tools/bin) continue ;;
    esac
    result+="${result:+:}$entry"
  done
  printf '%s\n' "$result"
}

launch_command() {
  local clean_path target
  (($# == 1)) || fail 'launch requires one target'
  clean_path=$(public_path)
  case $1 in
    browser) target=$LAUNCH_BROWSER ;;
    terminal) target=$LAUNCH_TERMINAL ;;
    editor) target=$LAUNCH_EDITOR ;;
    files) target=$LAUNCH_FILES ;;
    *) fail 'invalid launcher' ;;
  esac
  PATH=$clean_path exec_command "$target"
}

audio_command() {
  local action=${1:-}
  local target value node pulse
  shift || true
  case $action in
    status) no_args "$@"; exec_command "$WPCTL" status ;;
    volume) (($# == 1)) || fail 'audio volume requires one value'; value=$1; [[ $value =~ ^(\+|-)?[0-9]{1,3}$ ]] || fail 'invalid volume'; if [[ $value == +* ]]; then target=${value#+}%+; elif [[ $value == -* ]]; then target=${value#-}%-; else ((10#$value <= 100)) || fail 'volume exceeds 100'; target=$value%; fi; exec_command "$WPCTL" set-volume -l 1 @DEFAULT_AUDIO_SINK@ "$target" ;;
    mute) (($# <= 1)) || fail 'audio mute accepts one target'; case ${1:-output} in output) target=@DEFAULT_AUDIO_SINK@;; input) target=@DEFAULT_AUDIO_SOURCE@;; *) fail 'mute target must be output or input';; esac; exec_command "$WPCTL" set-mute "$target" toggle ;;
    output|input)
      target=$action
      action=${1:-}
      shift || true
      case $action in
        list) no_args "$@"; exec_command "$WPCTL" status ;;
        set)
          (($# == 2)) || fail "audio $target set requires NODE_ID PULSE_NAME"
          node=$1; pulse=$2
          [[ $node =~ ^[0-9]+$ ]] || fail 'invalid node id'
          safe_value "$pulse"
          if [[ $target == output ]]; then
            exec_command "$AUDIO_OUTPUT_SET" "$node" "$pulse"
          else
            exec_command "$AUDIO_INPUT_SET" "$node" "$pulse"
          fi
          ;;
        *) fail "audio $target requires list or set" ;;
      esac
      ;;
    mixer) no_args "$@"; exec_command "$PULSEMIXER" ;;
    *) fail 'invalid audio command' ;;
  esac
}
media_command() { local action=${1:-}; shift || true; (($# <= 1)) || fail 'media command accepts at most one player'; local -a selector=(); if (($#)); then safe_value "$1"; selector=(-p "$1"); fi; case $action in status) exec_command "$PLAYERCTL" "${selector[@]}" status;; play-pause|next|previous|stop) exec_command "$PLAYERCTL" "${selector[@]}" "$action";; *) fail 'invalid media command';; esac; }
display_command() {
  local action=${1:-} value
  shift || true
  case $action in
    status) no_args "$@"; exec_command "$MONITOR_STATE" ;;
    brightness)
      (($# <= 1)) || fail 'brightness accepts one value'
      if (($# == 0)); then exec_command "$BRIGHTNESS_DISPLAY"; fi
      value=$1
      [[ $value =~ ^(\+|-)?[0-9]{1,3}%?$ ]] || fail 'invalid brightness'
      value=${value%%%}
      if [[ $value == +* ]]; then value="${value}%"; elif [[ $value == -* ]]; then value="${value#-}%-"; else value="${value}%"; fi
      exec_command "$BRIGHTNESS_DISPLAY" "$value"
      ;;
    scale)
      (($# == 1)) || fail 'scale requires one value'
      [[ $1 == up || $1 == down || $1 =~ ^[0-9]+([.][0-9]+)?$ ]] || fail 'invalid scale'
      exec_command "$MONITOR_SCALING" "$1"
      ;;
    configure) no_args "$@"; exec_command "$WDISPLAYS" ;;
    *) fail 'invalid display command' ;;
  esac
}

network_command() {
  local action=${1:-} sub interface ssid value
  local -a rest
  shift || true
  sub=${1:-}
  case $action in
    status)
      if (($# == 0)); then exec_command "$NETWORK_STATUS"; fi
      (($# == 1)) && [[ $1 == --verbose ]] || fail 'network status accepts only --verbose'
      exec_command "$NETWORK_STATUS" --verbose
      ;;
    speedtest)
      (($# == 1)) && [[ $1 == down || $1 == up ]] || fail 'speedtest requires down or up'
      exec_command "$NETWORK_SPEEDTEST" "$1"
      ;;
    wifi)
      shift || true
      case $sub in
        list) no_args "$@"; exec_command "$NMCLI" --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list ;;
        connect) (($# == 1)) || fail 'wifi connect requires SSID'; ssid=$1; safe_value "$ssid"; exec_command "$NMCLI" --ask device wifi connect "$ssid" ;;
        disconnect)
          interface=''; rest=()
          for value in "$@"; do
            if [[ $value == --yes ]]; then rest+=("$value")
            elif [[ -z $interface ]]; then interface=$value; safe_value "$interface"
            else fail 'invalid wifi disconnect arguments'
            fi
          done
          confirm 'disconnect Wi-Fi' "${rest[@]}"
          if [[ -n $interface ]]; then exec_command "$NMCLI" device disconnect "$interface"; else exec_command "$NMCLI" radio wifi off; fi
          ;;
        band)
          (($# <= 1)) || fail 'wifi band accepts one band'
          (($# == 0)) || [[ $1 == auto || $1 == 2.4 || $1 == 5 || $1 == 6 ]] || fail 'invalid Wi-Fi band'
          exec_command "$NETWORK_BAND" "$@"
          ;;
        share)
          (($# >= 1 && $# <= 2)) || fail 'wifi share requires [INTERFACE] --reveal'
          [[ ${!#} == --reveal ]] || fail 'wifi share requires --reveal'
          if (($# == 2)); then interface=$1; safe_value "$interface"; exec_command "$NETWORK_QR" "$interface"; fi
          exec_command "$NETWORK_QR"
          ;;
        *) fail 'invalid wifi command' ;;
      esac
      ;;
    *) fail 'invalid network command' ;;
  esac
}
bluetooth_command() { local action=${1:-}; shift || true; local state; case $action in status) no_args "$@"; exec_command "$BLUETOOTHCTL" show;; power) (($# == 1)) || fail 'bluetooth power requires a state'; case $1 in on|off) exec_command "$BLUETOOTHCTL" power "$1";; toggle) state=$($BLUETOOTHCTL show | grep -q 'Powered: yes' && printf off || printf on); exec_command "$BLUETOOTHCTL" power "$state";; *) fail 'invalid power state';; esac;; pair|connect|disconnect) (($# == 1)) || fail "$action requires an address"; address "$1"; exec_command "$BLUETOOTHCTL" "$action" "$1";; forget) (($# >= 1 && $# <= 2)) || fail 'forget requires ADDRESS [--yes]'; address "$1"; state=$1; shift; confirm 'forget Bluetooth device' "$@"; exec_command "$BLUETOOTHCTL" remove "$state";; *) fail 'invalid bluetooth command';; esac; }
power_command() {
  local action=${1:-}; shift || true
  case $action in
    battery) no_args "$@"; exec_command "$BATTERY_STATUS" ;;
    profiles) no_args "$@"; exec_command "$POWERPROFILES_LIST" ;;
    profile)
      (($# >= 1 && $# <= 2)) || fail 'profile requires mode and optional profile'
      [[ $1 == autodetect || $1 == ac || $1 == battery ]] || fail 'invalid profile mode'
      (($# == 1)) || safe_value "$2"
      exec_command "$POWERPROFILES_SET" "$@"
      ;;
    *) fail 'invalid power command' ;;
  esac
}

system_command() {
  local action=${1:-}; shift || true
  case $action in
    stats) no_args "$@"; exec_command "$SYSTEM_STATS" ;;
    monitor) no_args "$@"; exec_command "$BTOP" ;;
    lock) no_args "$@"; exec_command "$HYPRLOCK" ;;
    logout|suspend|hibernate|reboot|shutdown)
      confirm "$action" "$@"
      case $action in
        logout) exec_command "$HYPRCTL" dispatch exit ;;
        suspend|hibernate|reboot) exec_command "$SYSTEMCTL" "$action" ;;
        shutdown) exec_command "$SYSTEMCTL" poweroff ;;
      esac
      ;;
    *) fail 'invalid system command' ;;
  esac
}

notifications_command() { local action=${1:-}; shift || true; case $action in status) no_args "$@"; qs notifications dndState;; dismiss) if (($# == 0)); then qs notifications dismissOne; elif (($# == 1)) && [[ $1 == --all ]]; then qs notifications dismissAll; else fail 'dismiss accepts only --all'; fi;; dnd) (($# == 1)) || fail 'dnd requires a state'; case $1 in on) qs notifications setDnd true;; off) qs notifications setDnd false;; toggle) qs notifications toggleDnd;; *) fail 'invalid dnd state';; esac;; history) no_args "$@"; qs notifications showHistory;; send) (($# >= 1 && $# <= 2)) || fail 'send requires TITLE [BODY]'; exec_command "$NOTIFY_SEND" "$@";; *) fail 'invalid notifications command';; esac; }
clipboard_command() { local action=${1:-}; shift || true; case $action in open) no_args "$@"; qs clipboard toggle;; clear) confirm 'clear clipboard history' "$@"; qs clipboard clear;; *) fail 'invalid clipboard command';; esac; }

select_geometry() {
  local mode=$1 clients rectangles geometry
  case $mode in
    region)
      geometry=$(run_command "$SLURP")
      ;;
    window)
      clients=$(run_command "$HYPRCTL" -j clients)
      rectangles=$(run_command "$JQ" -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' <<<"$clients")
      [[ -n $rectangles ]] || fail 'Hyprland reported no client windows'
      geometry=$(run_command "$SLURP" -r <<<"$rectangles")
      ;;
    *) fail 'invalid capture selection mode' ;;
  esac
  [[ $geometry =~ ^-?[0-9]+,-?[0-9]+[[:space:]][1-9][0-9]*x[1-9][0-9]*$ ]] || fail 'capture selection was empty or invalid'
  printf '%s\n' "$geometry"
}

fos_runtime_state_dir() {
  if [[ -n ${FOS_RUNTIME_STATE_DIR:-} ]]; then
    printf '%s\n' "$FOS_RUNTIME_STATE_DIR"
  elif [[ -n ${XDG_RUNTIME_DIR:-} ]]; then
    printf '%s/fos\n' "$XDG_RUNTIME_DIR"
  else
    printf '%s/fos-%s\n' "${TMPDIR:-/tmp}" "$(id -u)"
  fi
}

RECORDING_LOCK_FD=''
RECORDING_CLEANUP_FILES=()
RECORDING_CLEANUP_PID=''

recording_cleanup() {
  local file
  if [[ $RECORDING_CLEANUP_PID =~ ^[1-9][0-9]*$ ]]; then
    "$KILL" -INT "$RECORDING_CLEANUP_PID" 2>/dev/null || true
    for _ in {1..10}; do
      kill -0 "$RECORDING_CLEANUP_PID" 2>/dev/null || break
      sleep 0.05
    done
    if kill -0 "$RECORDING_CLEANUP_PID" 2>/dev/null; then
      "$KILL" -TERM "$RECORDING_CLEANUP_PID" 2>/dev/null || true
      for _ in {1..10}; do
        kill -0 "$RECORDING_CLEANUP_PID" 2>/dev/null || break
        sleep 0.05
      done
    fi
    if kill -0 "$RECORDING_CLEANUP_PID" 2>/dev/null; then
      "$KILL" -KILL "$RECORDING_CLEANUP_PID" 2>/dev/null || true
    fi
    if ! kill -0 "$RECORDING_CLEANUP_PID" 2>/dev/null; then
      wait "$RECORDING_CLEANUP_PID" 2>/dev/null || true
    fi
  fi
  RECORDING_CLEANUP_PID=''
  for file in "${RECORDING_CLEANUP_FILES[@]}"; do rm -f -- "$file"; done
  RECORDING_CLEANUP_FILES=()
  if [[ $RECORDING_LOCK_FD =~ ^[0-9]+$ ]]; then exec {RECORDING_LOCK_FD}>&-; fi
  RECORDING_LOCK_FD=''
}

recording_lock() {
  local state_dir=$1 lock_file
  if [[ -e $state_dir ]]; then
    [[ -d $state_dir && ! -L $state_dir && -O $state_dir ]] || fail 'recording state directory is unsafe or unowned'
  else
    mkdir -m 700 -- "$state_dir"
  fi
  chmod 700 -- "$state_dir"
  lock_file=$state_dir/recording.lock
  [[ ! -L $lock_file && ( ! -e $lock_file || -f $lock_file && -O $lock_file ) ]] || fail 'recording lock file is unsafe or unowned'
  need "$FLOCK"
  exec {RECORDING_LOCK_FD}>>"$lock_file"
  chmod 600 -- "$lock_file"
  if ! "$FLOCK" --nonblock "$RECORDING_LOCK_FD"; then
    exec {RECORDING_LOCK_FD}>&-
    RECORDING_LOCK_FD=''
    fail 'another recording operation is in progress'
  fi
  trap recording_cleanup EXIT
}

process_identity() {
  local pid=$1 stat rest
  local -a fields cmdline
  [[ $pid =~ ^[1-9][0-9]*$ && -O /proc/$pid && -r /proc/$pid/stat && -r /proc/$pid/cmdline ]] || return 1
  stat=$(<"/proc/$pid/stat")
  rest=${stat##*) }
  read -r -a fields <<<"$rest"
  ((${#fields[@]} > 19)) || return 1
  PROC_STATE=${fields[0]}
  PROC_START_TIME=${fields[19]}
  PROC_EXE=$(readlink -f -- "/proc/$pid/exe" 2>/dev/null) || return 1
  mapfile -d '' -t cmdline <"/proc/$pid/cmdline" || true
  ((${#cmdline[@]} > 0)) || return 1
  PROC_ARGV0=${cmdline[0]}
  PROC_BACKEND_ARG=''
  ((${#cmdline[@]} > 1)) && PROC_BACKEND_ARG=${cmdline[1]}
  [[ $PROC_STATE != Z && $PROC_START_TIME =~ ^[0-9]+$ && -n $PROC_ARGV0 && -n $PROC_EXE ]]
}

recording_state_read() {
  local file=$1 key value
  RECORDING_PID=''; RECORDING_START_TIME=''; RECORDING_ARGV0=''; RECORDING_EXE=''; RECORDING_BACKEND=''; RECORDING_OUTPUT=''
  [[ -f $file && -O $file ]] || return 1
  while IFS=$'\t' read -r key value; do
    [[ -n $value && $value != *$'\t'* && $value != *$'\n'* ]] || return 1
    case $key in
      pid) [[ -z $RECORDING_PID ]] || return 1; RECORDING_PID=$value ;;
      start_time) [[ -z $RECORDING_START_TIME ]] || return 1; RECORDING_START_TIME=$value ;;
      argv0) [[ -z $RECORDING_ARGV0 ]] || return 1; RECORDING_ARGV0=$value ;;
      exe) [[ -z $RECORDING_EXE ]] || return 1; RECORDING_EXE=$value ;;
      backend) [[ -z $RECORDING_BACKEND ]] || return 1; RECORDING_BACKEND=$value ;;
      output) [[ -z $RECORDING_OUTPUT ]] || return 1; RECORDING_OUTPUT=$value ;;
      *) return 1 ;;
    esac
  done <"$file"
  [[ $RECORDING_PID =~ ^[1-9][0-9]*$ && $RECORDING_START_TIME =~ ^[0-9]+$ && -n $RECORDING_ARGV0 && -n $RECORDING_EXE && -n $RECORDING_BACKEND && -n $RECORDING_OUTPUT ]]
}

recording_state_valid() {
  local file=$1
  recording_state_read "$file" || return 1
  [[ $RECORDING_BACKEND == "$WF_RECORDER" ]] || return 1
  process_identity "$RECORDING_PID" || return 1
  [[ $PROC_START_TIME == "$RECORDING_START_TIME" && $PROC_ARGV0 == "$RECORDING_ARGV0" && $PROC_EXE == "$RECORDING_EXE" ]] || return 1
  [[ $PROC_ARGV0 == "$RECORDING_BACKEND" || $PROC_BACKEND_ARG == "$RECORDING_BACKEND" ]]
}

recording_write_state() {
  local file=$1 temporary=$2 pid=$3 output=$4
  process_identity "$pid" || return 1
  [[ $PROC_ARGV0 == "$WF_RECORDER" || $PROC_BACKEND_ARG == "$WF_RECORDER" ]] || return 1
  umask 077
  printf 'pid\t%s\nstart_time\t%s\nargv0\t%s\nexe\t%s\nbackend\t%s\noutput\t%s\n' \
    "$pid" "$PROC_START_TIME" "$PROC_ARGV0" "$PROC_EXE" "$WF_RECORDER" "$output" >"$temporary"
  mv -f -- "$temporary" "$file"
}

capture_command() {
  local kind=${1:-} action mode geometry output pid state_dir state_file state_temp audio=''
  local -a args
  shift || true
  state_dir=$(fos_runtime_state_dir); state_file=$state_dir/recording.state
  case $kind in
    screenshot)
      action=${1:-}; shift || true; no_args "$@"
      case $action in
        region|window) geometry=$(select_geometry "$action"); print_command "$GRIM" -g "$geometry" -; "$GRIM" -g "$geometry" - | exec_command "$SATTY" -f - ;;
        screen) print_command "$GRIM" -; "$GRIM" - | exec_command "$SATTY" -f - ;;
        *) fail 'invalid screenshot target' ;;
      esac
      ;;
    ocr)
      [[ ${1:-} == region ]] || fail 'ocr requires region'; shift; no_args "$@"
      geometry=$(select_geometry region)
      need "$GRIM"; need "$TESSERACT"; need "$WL_COPY"
      print_command "$GRIM" -g "$geometry" -
      print_command "$TESSERACT" stdin stdout -l eng+fre
      print_command "$WL_COPY"
      "$GRIM" -g "$geometry" - | "$TESSERACT" stdin stdout -l eng+fre | "$WL_COPY"
      ;;
    record)
      action=${1:-}; shift || true
      case $action in
        start)
          mode=${1:-}; shift || true
          [[ $mode == region || $mode == screen ]] || fail 'record start requires region or screen'
          if (($#)); then (($# == 1)) && [[ $1 == --audio ]] || fail 'record start accepts only --audio'; audio=--audio; fi
          recording_lock "$state_dir"
          if [[ -e $state_file ]]; then
            recording_state_valid "$state_file" && fail 'a FOS recording is already active'
            rm -f -- "$state_file"
          fi
          mkdir -p -- "${XDG_VIDEOS_DIR:-$HOME/Videos}"
          output=$(mktemp --tmpdir="${XDG_VIDEOS_DIR:-$HOME/Videos}" "fos-recording-$(date +%Y%m%d-%H%M%S)-XXXXXX.mp4")
          state_temp=$(mktemp --tmpdir="$state_dir" '.recording.state.XXXXXX')
          RECORDING_CLEANUP_FILES=("$output" "$state_temp")
          args=(--overwrite -f "$output")
          [[ $mode == region ]] && args+=(-g "$(select_geometry region)")
          [[ -n $audio ]] && args+=(--audio)
          need "$WF_RECORDER"; print_command "$WF_RECORDER" "${args[@]}"
          (
            exec {RECORDING_LOCK_FD}>&-
            exec "$WF_RECORDER" "${args[@]}"
          ) & pid=$!
          RECORDING_CLEANUP_PID=$pid
          sleep "${FOS_RECORDING_STARTUP_WAIT:-0.1}"
          process_identity "$pid" || fail 'wf-recorder failed during startup'
          recording_write_state "$state_file" "$state_temp" "$pid" "$output" || fail 'could not validate wf-recorder identity'
          RECORDING_CLEANUP_PID=''
          RECORDING_CLEANUP_FILES=()
          recording_cleanup; trap - EXIT
          printf '%s\n' "$output"
          ;;
        status)
          no_args "$@"; [[ -r $state_file ]] || fail 'no FOS recording is active'
          recording_state_valid "$state_file" || fail 'recording state is stale or invalid'
          printf 'recording (pid %s): %s\n' "$RECORDING_PID" "$RECORDING_OUTPUT"
          ;;
        stop)
          no_args "$@"; recording_lock "$state_dir"
          [[ -r $state_file ]] || fail 'no FOS recording is active'
          recording_state_valid "$state_file" || fail 'refusing stale, reused, or unowned recording state'
          pid=$RECORDING_PID
          recording_state_valid "$state_file" || fail 'recording identity changed before stop'
          run_command "$KILL" -INT "$pid"
          for _ in {1..40}; do
            recording_process_active "$pid" || break
            sleep 0.05
          done
          recording_process_active "$pid" && fail 'recorder did not finalize; state retained'
          rm -f -- "$state_file"
          recording_cleanup; trap - EXIT
          ;;
        *) fail 'record requires start, status, or stop' ;;
      esac
      ;;
    *) fail 'invalid capture command' ;;
  esac
}
recording_process_active() { local _pid=$1 _comm _state=''; [[ -r /proc/$_pid/stat ]] || return 1; read -r _pid _comm _state _ <"/proc/$_pid/stat" 2>/dev/null || return 1; [[ $_state != Z ]]; }

vpn_command() { local action=${1:-}; shift || true; local server; case $action in status|list) no_args "$@"; exec_command "$VPN" "$action";; up|down) confirm "VPN $action" "$@"; exec_command "$VPN" "$action";; switch) (($# >= 1 && $# <= 2)) || fail 'vpn switch requires SERVER [--yes]'; server=$1; safe_value "$server"; shift; confirm 'switch VPN server' "$@"; exec_command "$VPN" switch "$server";; *) fail 'invalid vpn command';; esac; }
tailscale_command() { local action=${1:-}; shift || true; case $action in status) no_args "$@"; exec_command "$TAILSCALE" status;; up|down) confirm "Tailscale $action" "$@"; exec_command "$TAILSCALE" "$action";; *) fail 'invalid tailscale command';; esac; }
service_command() { local action=${1:-}; shift || true; local scope='' unit yes=''; [[ ${1:-} == --user ]] && { scope=--user; shift; }; (($# >= 1)) || fail 'service command requires UNIT'; unit=$1; shift; unit_name "$unit"; case $action in status) no_args "$@"; exec_command "$SYSTEMCTL" ${scope:+"$scope"} status "$unit";; logs) no_args "$@"; exec_command "$JOURNALCTL" ${scope:+"$scope"} --unit "$unit" --no-pager;; restart) (($# <= 1)) || fail 'service restart accepts only --yes'; (($# == 0)) || yes=$1; confirm "restart service $unit" ${yes:+"$yes"}; exec_command "$SYSTEMCTL" ${scope:+"$scope"} restart "$unit";; *) fail 'invalid service command';; esac; }
vm_command() { local action=${1:-}; shift || true; local name; case $action in list) no_args "$@"; exec_command "$VIRSH" -c qemu:///system list --all;; status|start) (($# == 1)) || fail "vm $action requires NAME"; name=$1; safe_value "$name"; if [[ $action == status ]]; then exec_command "$VIRSH" -c qemu:///system dominfo "$name"; else exec_command "$VIRSH" -c qemu:///system start "$name"; fi;; shutdown) (($# >= 1 && $# <= 2)) || fail 'vm shutdown requires NAME [--yes]'; name=$1; safe_value "$name"; shift; confirm "shut down VM $name" "$@"; exec_command "$VIRSH" -c qemu:///system shutdown "$name";; *) fail 'invalid vm command';; esac; }
hardware_command() { local action=${1:-}; shift || true; case $action in summary) no_args "$@"; exec_command "$LSHW" -short;; cpu) no_args "$@"; exec_command "$LSCPU";; memory) no_args "$@"; exec_command "$FREE" -h;; gpu) no_args "$@"; exec_command "$LSPCI" -nnk;; storage) no_args "$@"; exec_command "$LSBLK" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL;; sensors) no_args "$@"; exec_command "$SENSORS";; battery) no_args "$@"; exec_command "$UPOWER" -d;; network) no_args "$@"; exec_command "$IP" -details link show;; pci) no_args "$@"; exec_command "$LSPCI" -nn;; usb) no_args "$@"; exec_command "$LSUSB";; firmware) no_args "$@"; exec_command "$FWUPDMGR" get-devices;; disk) (($# == 1)) || fail 'hardware disk requires DEVICE'; [[ $1 =~ ^/dev/[A-Za-z0-9._/-]+$ && $1 != *..* ]] || fail 'invalid device'; exec_command "$SMARTCTL" --info --health "$1";; *) fail 'invalid hardware command';; esac; }

status_command() {
  local json=false host kernel uptime load memory network profile recording
  local key value total_kib='' available_kib=''
  (($# <= 1)) || fail 'status accepts only --json'
  if (($#)); then [[ $1 == --json ]] || fail 'status accepts only --json'; json=true; fi

  host=$(local_host 2>/dev/null || printf unknown)
  kernel=$($UNAME -r 2>/dev/null || printf unknown)
  uptime=$($UPTIME -p 2>/dev/null || true); uptime=${uptime:-unknown}
  read -r load _ </proc/loadavg || load=unknown
  while read -r key value _; do
    case $key in MemTotal:) total_kib=$value;; MemAvailable:) available_kib=$value;; esac
  done </proc/meminfo
  if [[ $total_kib =~ ^[0-9]+$ && $available_kib =~ ^[0-9]+$ ]]; then
    memory="$(((total_kib - available_kib) / 1024)) MiB / $((total_kib / 1024)) MiB"
  else
    memory=unknown
  fi
  network=$($NETWORK_STATUS 2>/dev/null | tr '\n' ';' || true); network=${network%;}; network=${network:-unavailable}
  profile=$($POWERPROFILESCTL get 2>/dev/null || true); profile=${profile:-unavailable}
  recording=inactive
  if recording_state_valid "$(fos_runtime_state_dir)/recording.state" 2>/dev/null; then recording=active; fi

  if $json; then
    # shellcheck disable=SC2016
    "$JQ" -n --arg host "$host" --arg kernel "$kernel" --arg uptime "$uptime" --arg load "$load" \
      --arg memory "$memory" --arg network "$network" --arg powerProfile "$profile" --arg recording "$recording" \
      '{host:$host,kernel:$kernel,uptime:$uptime,load:$load,memory:$memory,network:$network,power_profile:$powerProfile,recording:$recording}'
  else
    printf 'Host: %s\nKernel: %s\nUptime: %s\nLoad: %s\nMemory: %s\nNetwork: %s\nPower profile: %s\nRecording: %s\n' \
      "$host" "$kernel" "$uptime" "$load" "$memory" "$network" "$profile" "$recording"
  fi
}

command_available() {
  if [[ $1 == */* ]]; then [[ -x $1 ]]; else command -v "$1" >/dev/null 2>&1; fi
}

doctor_rows() {
  local tool state
  for tool in "$NIX" "$NH" "$QS" "$HYPRCTL" "$HYPRLOCK" "$NMCLI" "$WPCTL" "$PLAYERCTL" "$WF_RECORDER" \
    "$MONITOR_STATE" "$NETWORK_STATUS" "$POWERPROFILES_LIST" "$SYSTEM_STATS" "$AUTH" "$LAUNCH_BROWSER" \
    "$LAUNCH_TERMINAL" "$LAUNCH_EDITOR" "$LAUNCH_FILES" "$KEYBINDINGS" "$VPN"; do
    if command_available "$tool"; then state=ok; else state=missing; fi
    printf 'backend:%s\t%s\n' "${tool##*/}" "$state"
  done
  [[ -n ${XDG_RUNTIME_DIR:-} ]] && state=ok || state=missing
  printf 'session:runtime-dir\t%s\n' "$state"
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && state=ok || state=missing
  printf 'session:hyprland\t%s\n' "$state"
}

doctor_command() {
  local json=false
  (($# <= 1)) || fail 'doctor accepts only --json'
  if (($#)); then [[ $1 == --json ]] || fail 'doctor accepts only --json'; json=true; fi
  if $json; then
    doctor_rows | "$JQ" -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {check:.[0],status:.[1]})'
  else
    while IFS=$'\t' read -r check state; do printf '%-42s %s\n' "$check" "$state"; done < <(doctor_rows)
  fi
}

if (($# == 0)); then usage; exit 0; fi
case $1 in -h|--help) usage; exit 0;; __complete) shift; completion "$@"; exit 0;; esac
help_path=()
for argument in "$@"; do
  if [[ $argument == -h || $argument == --help ]]; then
    help_command "${help_path[@]}"
    exit 0
  fi
  help_path+=("$argument")
done
command=$1; shift
case $command in
  version) no_args "$@"; printf '%s\n' 'fos 2.0.0';;
  help) help_command "$@";; commands) commands_command "$@";; status) status_command "$@";; doctor) doctor_command "$@";;
  nixos) nixos_command "$@";; auth) auth_command "$@";; menu) menu_command "$@";; launch) launch_command "$@";;
  audio) audio_command "$@";; media) media_command "$@";; display) display_command "$@";; network) network_command "$@";;
  bluetooth) bluetooth_command "$@";; power) power_command "$@";; system) system_command "$@";;
  notifications) notifications_command "$@";; clipboard) clipboard_command "$@";; capture) capture_command "$@";;
  vpn) vpn_command "$@";; tailscale) tailscale_command "$@";; service) service_command "$@";; vm) vm_command "$@";; hardware) hardware_command "$@";;
  *) fail "unknown command: $command";;
esac
