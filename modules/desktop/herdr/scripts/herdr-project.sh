#!/usr/bin/env bash
# herdr.nix sets projects_directory before this script.
# shellcheck disable=SC2154
set -euo pipefail

runtime_directory="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

pane_is_idle() {
  local pane_id="$1"
  local process_json

  if ! process_json="$(herdr pane process-info --pane "$pane_id")"; then
    return 1
  fi
  jq -e '
    .result.process_info as $process
    | ($process.foreground_processes | length == 0)
      or (
        $process.foreground_process_group_id == $process.shell_pid
        and any($process.foreground_processes[]; .pid == $process.shell_pid)
      )
  ' <<<"$process_json" >/dev/null
}

wait_until_busy() {
  local pane_id="$1"

  for _ in {1..50}; do
    if ! pane_is_idle "$pane_id"; then
      return
    fi
    sleep 0.1
  done

  printf 'Pane %s did not start its command within five seconds\n' "$pane_id" >&2
  return 1
}

restore_editors() {
  local tabs_json panes_json tab_id pane_id

  exec 8>"$runtime_directory/herdr-restore-editors.lock"
  flock 8

  for _ in {1..100}; do
    if tabs_json="$(herdr tab list 2>/dev/null)" \
      && panes_json="$(herdr pane list 2>/dev/null)"; then
      break
    fi
    sleep 0.1
  done

  if [[ -z "${tabs_json:-}" || -z "${panes_json:-}" ]]; then
    return
  fi

  while IFS= read -r tab_id; do
    while IFS= read -r pane_id; do
      if [[ -n "$pane_id" ]] && pane_is_idle "$pane_id"; then
        if ! herdr pane run "$pane_id" 'nvim' >/dev/null \
          || ! wait_until_busy "$pane_id"; then
          continue
        fi
      fi
    done < <(jq -r --arg tab_id "$tab_id" \
      '.result.panes[] | select(.tab_id == $tab_id) | .pane_id' <<<"$panes_json")
  done < <(jq -r '.result.tabs[] | select(.label == "edit") | .tab_id' <<<"$tabs_json")
}

if [[ "${1:-}" == "--restore-editors" ]]; then
  restore_editors
  exit
fi

choose_project() {
  local git_path project selected
  local -a projects=()

  while IFS= read -r -d $'\0' git_path; do
    project="$(dirname -- "$git_path")"
    projects+=("${project#"$projects_directory"/}")
  done < <(fd --hidden --no-ignore --type directory --type file --print0 \
    --exclude .direnv \
    --exclude build \
    --exclude dist \
    --exclude node_modules \
    --exclude target \
    '^\.git$' "$projects_directory")

  if (( ${#projects[@]} == 0 )); then
    printf 'No Git repositories found under %s\n' "$projects_directory" >&2
    return 1
  fi

  selected="$(printf '%s\n' "${projects[@]}" | sort -u | fzf \
    --border \
    --height=100% \
    --prompt='Project > ' \
    --reverse)" || return

  realpath -- "$projects_directory/$selected"
}

project="${1:-}"
if [[ -z "$project" ]]; then
  project="$(choose_project)" || exit 0
fi

project="$(realpath -- "$project")"
requested_project="$project"
if ! project="$(git -C "$project" rev-parse --show-toplevel 2>/dev/null)"; then
  printf '%s is not inside a Git repository\n' "$requested_project" >&2
  exit 1
fi
project="$(realpath -- "$project")"

exec 9>"$runtime_directory/herdr-project.lock"
flock 9

label="${project#"$projects_directory"/}"
if [[ "$label" == "$project" ]]; then
  label="$(basename -- "$project")"
fi

panes_json="$(herdr pane list)"
workspace_id="$(jq -r --arg cwd "$project" \
  '[.result.panes[] | select(.cwd == $cwd) | .workspace_id][0] // empty' \
  <<<"$panes_json")"
edit_created=false
agent_created=false
workspace_created=false

if [[ -z "$workspace_id" ]]; then
  workspace_json="$(herdr workspace create --cwd "$project" --label "$label" --no-focus)"
  workspace_id="$(jq -r '.result.workspace.workspace_id' <<<"$workspace_json")"
  edit_tab_id="$(jq -r '.result.tab.tab_id' <<<"$workspace_json")"
  edit_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$workspace_json")"

  herdr tab rename "$edit_tab_id" edit >/dev/null
  herdr pane run "$edit_pane_id" 'nvim' >/dev/null
  edit_created=true
  workspace_created=true
else
  tabs_json="$(herdr tab list --workspace "$workspace_id")"
  edit_tab_id="$(jq -r '[.result.tabs[] | select(.label == "edit") | .tab_id][0] // empty' <<<"$tabs_json")"

  if [[ -z "$edit_tab_id" ]]; then
    edit_json="$(herdr tab create --workspace "$workspace_id" --cwd "$project" --label edit --no-focus)"
    edit_tab_id="$(jq -r '.result.tab.tab_id' <<<"$edit_json")"
    edit_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$edit_json")"
    herdr pane run "$edit_pane_id" 'nvim' >/dev/null
    edit_created=true
  fi
fi

tabs_json="$(herdr tab list --workspace "$workspace_id")"
agent_tab_id="$(jq -r '[.result.tabs[] | select(.label == "agent") | .tab_id][0] // empty' <<<"$tabs_json")"
if [[ -z "$agent_tab_id" ]]; then
  agent_json="$(herdr tab create --workspace "$workspace_id" --cwd "$project" --label agent --no-focus)"
  agent_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$agent_json")"
  herdr pane run "$agent_pane_id" 'pi' >/dev/null
  agent_created=true
fi

shell_tab_id="$(jq -r '[.result.tabs[] | select(.label == "shell") | .tab_id][0] // empty' <<<"$tabs_json")"
if [[ -z "$shell_tab_id" ]]; then
  herdr tab create --workspace "$workspace_id" --cwd "$project" --label shell --no-focus >/dev/null
fi

run_if_idle() {
  local tab_id="$1"
  local command="$2"
  local pane_id

  pane_id="$(herdr pane list --workspace "$workspace_id" | jq -r --arg tab_id "$tab_id" \
    '[.result.panes[] | select(.tab_id == $tab_id) | .pane_id][0] // empty')"
  [[ -n "$pane_id" ]] || return

  if pane_is_idle "$pane_id"; then
    herdr pane run "$pane_id" "$command" >/dev/null
    wait_until_busy "$pane_id"
  fi
}

if [[ "$edit_created" == false ]]; then
  run_if_idle "$edit_tab_id" 'nvim'
fi
if [[ "$agent_created" == false ]]; then
  run_if_idle "$agent_tab_id" 'pi'
fi
if [[ "$edit_created" == true ]]; then
  wait_until_busy "$edit_pane_id"
fi
if [[ "$agent_created" == true ]]; then
  wait_until_busy "$agent_pane_id"
fi

herdr workspace focus "$workspace_id" >/dev/null
if [[ "$workspace_created" == true ]]; then
  herdr tab focus "$edit_tab_id" >/dev/null
fi
