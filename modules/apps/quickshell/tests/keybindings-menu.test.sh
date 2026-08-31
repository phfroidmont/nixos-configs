#!/usr/bin/env bash

set -euo pipefail

: "${KEYBINDINGS_MENU_BIN:?set KEYBINDINGS_MENU_BIN to fos-internal-menu-keybindings}"

test_root=$(mktemp -d)
dispatch_log="$test_root/dispatch.log"
export HOME="$test_root/home"
export XDG_CACHE_HOME="$test_root/cache"
export XDG_CONFIG_HOME="$test_root/config"
export HYPRCTL_DISPATCH_LOG="$dispatch_log"
export SELECT_DESCRIPTION="Keybindings"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$XDG_CONFIG_HOME/hypr"

write_config() {
  local keybindings_command=$1

  cat >"$XDG_CONFIG_HOME/hypr/hyprland.lua" <<LUA
hl.bind("SUPER + B", hl.dsp.exec_cmd("$keybindings_command"), { description = "Keybindings" })
hl.bind("SUPER + C", hl.dsp.window.close(), { description = "Close window" })
hl.bind("SUPER + code:10", hl.dsp.focus({ workspace = 1 }), { description = "Focus physical workspace 1" })
LUA
}

hyprctl() {
  if [[ ${1:-} == -j && ${2:-} == getoption ]]; then
    case ${3:-} in
      input:kb_rules)
        printf '%s\n' '{"option":"input:kb_rules","str":"[[EMPTY]]","set":false}'
        ;;
      input:kb_model)
        printf '%s\n' '{"option":"input:kb_model","str":"[[EMPTY]]","set":false}'
        ;;
      input:kb_layout)
        printf '%s\n' '{"option":"input:kb_layout","str":"fr","set":true}'
        ;;
      input:kb_variant)
        printf '%s\n' '{"option":"input:kb_variant","str":"[[EMPTY]]","set":false}'
        ;;
      input:kb_options)
        printf '%s\n' '{"option":"input:kb_options","str":"caps:escape","set":true}'
        ;;
      *)
        return 1
        ;;
    esac
    return 0
  fi

  case ${1:-} in
    binds)
      cat <<'BINDS'
bind
	modmask: 64
	submap:
	key: SUPER + B
	keycode: 0
	catchall: false
	description: Keybindings
	dispatcher: __lua
	arg: 1
bind
	modmask: 64
	submap:
	key: SUPER + C
	keycode: 0
	catchall: false
	description: Close window
	dispatcher: __lua
	arg: 2
bind
	modmask: 64
	submap:
	key: SUPER + code:10
	keycode: 0
	catchall: false
	description: Focus physical workspace 1
	dispatcher: __lua
	arg: 3
BINDS
      ;;
    devices)
      printf '%s\n' 'active keymap: French'
      ;;
    dispatch)
      printf '%s\n' "$*" >>"$HYPRCTL_DISPATCH_LOG"
      printf '%s\n' ok
      ;;
    *)
      return 1
      ;;
  esac
}

fos-internal-menu-select() {
  local row

  while IFS= read -r row; do
    if [[ $row == *"$SELECT_DESCRIPTION"* ]]; then
      printf '%s\n' "$row"
      return 0
    fi
  done

  return 1
}

export -f hyprctl fos-internal-menu-select

write_config /first-keybindings-command

rendered=$("$KEYBINDINGS_MENU_BIN" --print)
grep -Fq 'Keybindings' <<<"$rendered"
grep -Fq 'Close window' <<<"$rendered"
grep -Eq 'SUPER \+ AMPERSAND +.*Focus physical workspace 1' <<<"$rendered"
if grep -Eq 'Copy URL from Web App|Download Video from Web App' <<<"$rendered"; then
  printf '%s\n' 'Omarchy-only static bindings leaked into the catalog' >&2
  exit 1
fi

# The live Hyprland records do not change here. Only the Lua action does, so
# this catches stale caches that key solely on `hyprctl binds` output.
write_config /second-keybindings-command
: >"$dispatch_log"
"$KEYBINDINGS_MENU_BIN" >/dev/null
grep -Fq '/second-keybindings-command' "$dispatch_log"
if grep -Fq '/first-keybindings-command' "$dispatch_log"; then
  printf '%s\n' 'The catalog dispatched a stale Lua action' >&2
  exit 1
fi

: >"$dispatch_log"
SELECT_DESCRIPTION="Close window" "$KEYBINDINGS_MENU_BIN" >/dev/null
grep -Fq 'hl.dsp.window.close()' "$dispatch_log"

printf '%s\n' 'keybindings menu tests passed'
