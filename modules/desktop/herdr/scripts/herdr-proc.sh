#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Manage long-running processes in the tabs of the current Herdr workspace.

Usage:
  herdr-proc list
  herdr-proc start <name> [--cwd PATH] [--] <command...>
  herdr-proc logs <target> [--lines N]
  herdr-proc stop <target>
  herdr-proc restart <target> [--] [command...]
  herdr-proc close <target>

<target> is a tab label or a pane id from `herdr-proc list`.
A single command argument is a raw shell line ('A=1 npm run dev | tee log');
several arguments are quoted as an argv (-- npm run dev).
restart without a command reruns the one recorded by start/restart.
Agent panes, panes running opencode, and the caller's own pane are protected.
EOF
}

fail() {
  printf 'herdr-proc: %s\n' "$*" >&2
  exit 1
}

workspace_id="${HERDR_WORKSPACE_ID:-}"
[[ -n "$workspace_id" ]] || fail "HERDR_WORKSPACE_ID is not set; run inside a Herdr pane"

state_directory="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/herdr-proc"

# Prints {state, command} for a pane as compact JSON, where state is
# protected, idle, or running. Callers must check the exit status: set -e
# does not apply inside `if` conditions.
describe_pane() {
  local pane_id="$1"
  local agent_status process_json

  agent_status="$(herdr pane list --workspace "$workspace_id" | jq -er --arg pane_id "$pane_id" \
    '.result.panes[] | select(.pane_id == $pane_id) | .agent_status')" || return 1
  process_json="$(herdr pane process-info --pane "$pane_id")" || return 1
  jq -ce --arg pane_id "$pane_id" --arg self "${HERDR_PANE_ID:-}" \
    --arg agent_status "$agent_status" '
    .result.process_info as $process
    | $process.foreground_processes as $foreground
    | ($foreground | map(select(.pid == $process.foreground_process_group_id))[0]) as $leader
    | {
        state: (
          if $pane_id == $self
            or $agent_status != "unknown"
            or ($foreground | length == 0)
            or any($foreground[];
              ((.name // "") + " " + ((.argv // []) | join(" "))) | test("opencode"))
          then "protected"
          elif $process.foreground_process_group_id == $process.shell_pid
            and any($foreground[]; .pid == $process.shell_pid)
          then "idle"
          else "running"
          end
        ),
        command: (
          if $leader == null or $process.foreground_process_group_id == $process.shell_pid
          then ""
          else ($leader.argv // []) | join(" ")
          end
        )
      }
  ' <<<"$process_json"
}

pane_state() {
  local pane_id="$1"
  local description

  description="$(describe_pane "$pane_id")" || return 1
  jq -r '.state' <<<"$description"
}

panes_json() {
  herdr pane list --workspace "$workspace_id"
}

tabs_json() {
  herdr tab list --workspace "$workspace_id"
}

# Resolves a pane id or a tab label to a single pane id.
resolve_pane() {
  local target="$1"
  local panes tabs tab_id pane_count

  panes="$(panes_json)"
  if jq -e --arg target "$target" 'any(.result.panes[]; .pane_id == $target)' \
    <<<"$panes" >/dev/null; then
    printf '%s\n' "$target"
    return
  fi

  tabs="$(tabs_json)"
  tab_id="$(jq -r --arg target "$target" \
    '[.result.tabs[] | select(.label == $target) | .tab_id] | if length == 1 then .[0] else "" end' \
    <<<"$tabs")"
  if [[ -z "$tab_id" ]]; then
    if jq -e --arg target "$target" 'any(.result.tabs[]; .label == $target)' \
      <<<"$tabs" >/dev/null; then
      fail "several tabs are labelled '$target'; use a pane id"
    fi
    fail "no tab or pane '$target' in workspace $workspace_id"
  fi

  pane_count="$(jq --arg tab_id "$tab_id" \
    '[.result.panes[] | select(.tab_id == $tab_id)] | length' <<<"$panes")"
  if (( pane_count != 1 )); then
    fail "tab '$target' has $pane_count panes; use a pane id"
  fi
  jq -r --arg tab_id "$tab_id" \
    '.result.panes[] | select(.tab_id == $tab_id) | .pane_id' <<<"$panes"
}

# Prints the pane state, exiting when it is protected or cannot be inspected.
require_unprotected() {
  local pane_id="$1"
  local state

  state="$(pane_state "$pane_id")" || fail "cannot inspect pane $pane_id"
  if [[ "$state" == protected ]]; then
    fail "pane $pane_id is protected (agent, opencode, or caller pane)"
  fi
  printf '%s\n' "$state"
}

wait_for_state() {
  local pane_id="$1"
  local wanted="$2"
  local tenths="$3"
  local state

  for (( i = 0; i < tenths; i++ )); do
    state="$(pane_state "$pane_id")" || fail "cannot inspect pane $pane_id"
    if [[ "$state" == "$wanted" ]]; then
      return
    fi
    sleep 0.1
  done
  return 1
}

command_file() {
  printf '%s/%s\n' "$state_directory" "$1"
}

# Herdr counts the blank screen rows below the cursor in --lines and caps reads at 1000.
read_output() {
  local pane_id="$1"
  local lines="$2"

  herdr pane read "$pane_id" --source recent --lines 1000 \
    | tac | sed '/[^[:space:]]/,$!d' | tac | tail -n "$lines"
}

# A single argument is a raw shell command line; several arguments are an argv to quote.
command_line() {
  if (( $# == 1 )); then
    printf '%s' "$1"
  else
    printf '%q ' "$@"
  fi
}

run_in_pane() {
  local pane_id="$1"
  local command="$2"

  local state

  mkdir -p "$state_directory"
  printf '%s\n' "$command" >"$(command_file "$pane_id")"
  herdr pane run "$pane_id" "$command" >/dev/null
  for _ in {1..50}; do
    state="$(pane_state "$pane_id")" || fail "cannot inspect pane $pane_id"
    if [[ "$state" != idle ]]; then
      printf 'Running in pane %s: %s\n' "$pane_id" "$command"
      return
    fi
    sleep 0.1
  done

  printf 'herdr-proc: command exited or did not start in pane %s; recent output:\n' \
    "$pane_id" >&2
  read_output "$pane_id" 30 >&2
  exit 1
}

stop_pane() {
  local pane_id="$1"
  local state

  state="$(require_unprotected "$pane_id")" || exit 1
  if [[ "$state" == idle ]]; then
    printf 'Pane %s is already idle\n' "$pane_id"
    return
  fi

  herdr pane send-keys "$pane_id" ctrl+c >/dev/null
  if ! wait_for_state "$pane_id" idle 100; then
    herdr pane send-keys "$pane_id" ctrl+c >/dev/null
    wait_for_state "$pane_id" idle 50 \
      || fail "pane $pane_id is still busy after two Ctrl-C"
  fi
  printf 'Stopped pane %s\n' "$pane_id"
}

cmd_list() {
  local panes tabs pane_id tab_label description state command

  panes="$(panes_json)"
  tabs="$(tabs_json)"
  printf '%-10s %-16s %-10s %s\n' PANE TAB STATE COMMAND
  while IFS=$'\t' read -r pane_id tab_label; do
    if description="$(describe_pane "$pane_id")"; then
      state="$(jq -r '.state' <<<"$description")"
      command="$(jq -r '.command' <<<"$description")"
    else
      state=unknown
      command=""
    fi
    printf '%-10s %-16s %-10s %s\n' "$pane_id" "$tab_label" "$state" "$command"
  done < <(jq -r --argjson tabs "$tabs" '
    ($tabs.result.tabs | map({key: .tab_id, value: .label}) | from_entries) as $labels
    | .result.panes[]
    | [.pane_id, ($labels[.tab_id] // "?")]
    | @tsv
  ' <<<"$panes")
}

cmd_start() {
  (( $# >= 1 )) || fail "start needs a name"
  local name="$1"
  local cwd="$PWD"
  local pane_id tab_json
  shift

  while (( $# > 0 )); do
    case "$1" in
      --cwd)
        (( $# >= 2 )) || fail "--cwd needs a path"
        cwd="$2"
        shift 2
        ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  (( $# >= 1 )) || fail "start needs a command"
  [[ -d "$cwd" ]] || fail "directory $cwd does not exist"
  cwd="$(realpath -- "$cwd")"
  local command
  command="$(command_line "$@")"

  if jq -e --arg name "$name" 'any(.result.tabs[]; .label == $name)' \
    <<<"$(tabs_json)" >/dev/null; then
    fail "tab '$name' already exists; use 'herdr-proc restart $name -- <command>'"
  fi

  tab_json="$(herdr tab create --workspace "$workspace_id" --cwd "$cwd" \
    --label "$name" --no-focus)"
  pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$tab_json")"
  run_in_pane "$pane_id" "$command"
}

cmd_logs() {
  (( $# >= 1 )) || fail "logs needs a target"
  local pane_id lines=200
  pane_id="$(resolve_pane "$1")"
  shift

  while (( $# > 0 )); do
    case "$1" in
      --lines)
        lines="${2:-}"
        [[ "$lines" =~ ^[0-9]+$ ]] || fail "--lines needs a number"
        shift 2
        ;;
      *) fail "unknown logs option: $1" ;;
    esac
  done

  read_output "$pane_id" "$lines"
}

cmd_stop() {
  (( $# == 1 )) || fail "stop needs exactly one target"
  local pane_id
  pane_id="$(resolve_pane "$1")"
  stop_pane "$pane_id"
}

cmd_restart() {
  (( $# >= 1 )) || fail "restart needs a target"
  local pane_id command
  pane_id="$(resolve_pane "$1")"
  shift
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi
  require_unprotected "$pane_id" >/dev/null

  if (( $# > 0 )); then
    command="$(command_line "$@")"
  elif [[ -f "$(command_file "$pane_id")" ]]; then
    command="$(<"$(command_file "$pane_id")")"
  else
    fail "no command recorded for pane $pane_id; pass it explicitly (see herdr-proc list)"
  fi

  stop_pane "$pane_id"
  run_in_pane "$pane_id" "$command"
}

cmd_close() {
  (( $# == 1 )) || fail "close needs exactly one target"
  local pane_id tab_id
  pane_id="$(resolve_pane "$1")"
  stop_pane "$pane_id"
  rm -f -- "$(command_file "$pane_id")"

  tab_id="$(jq -r --arg pane_id "$pane_id" \
    '.result.panes[] | select(.pane_id == $pane_id) | .tab_id' <<<"$(panes_json)")"
  if jq -e --arg tab_id "$tab_id" \
    '[.result.panes[] | select(.tab_id == $tab_id)] | length == 1' \
    <<<"$(panes_json)" >/dev/null; then
    herdr tab close "$tab_id" >/dev/null
    printf 'Closed tab %s\n' "$tab_id"
  else
    herdr pane close "$pane_id" >/dev/null
    printf 'Closed pane %s\n' "$pane_id"
  fi
}

subcommand="${1:-}"
(( $# > 0 )) && shift
case "$subcommand" in
  list) cmd_list "$@" ;;
  start) cmd_start "$@" ;;
  logs) cmd_logs "$@" ;;
  stop) cmd_stop "$@" ;;
  restart) cmd_restart "$@" ;;
  close) cmd_close "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 1 ;;
esac
