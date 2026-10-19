#!/usr/bin/env bash
set -euo pipefail

if ! tabs_json="$(herdr tab list 2>/dev/null)" \
  || ! panes_json="$(herdr pane list 2>/dev/null)"; then
  exit 0
fi

checkpoint_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/herdr-nvim-checkpoints"
mkdir -p "$checkpoint_dir"
declare -a checkpoint_files=()

while IFS= read -r tab_id; do
  while IFS= read -r pane_id; do
    [[ -n "$pane_id" ]] || continue

    if ! process_json="$(herdr pane process-info --pane "$pane_id" 2>/dev/null)"; then
      continue
    fi
    nvim_pid="$(jq -r '
      [.result.process_info.foreground_processes[]
        | select(.name == "nvim")
        | select((.argv | index("--embed")) == null)
        | .pid][0] // empty
    ' <<<"$process_json")"
    [[ -n "$nvim_pid" ]] || continue

    checkpoint_file="$checkpoint_dir/$nvim_pid"
    rm -f -- "$checkpoint_file"
    if kill -USR1 "$nvim_pid" 2>/dev/null; then
      checkpoint_files+=("$checkpoint_file")
    fi
  done < <(jq -r --arg tab_id "$tab_id" \
    '.result.panes[] | select(.tab_id == $tab_id) | .pane_id' <<<"$panes_json")
done < <(jq -r '.result.tabs[] | select(.label == "edit") | .tab_id' <<<"$tabs_json")

(( ${#checkpoint_files[@]} > 0 )) || exit 0

for _ in {1..50}; do
  pending=0
  for checkpoint_file in "${checkpoint_files[@]}"; do
    [[ -e "$checkpoint_file" ]] || pending=1
  done
  (( pending )) || break
  sleep 0.1
done

if (( pending )); then
  printf 'Timed out waiting for one or more Neovim session checkpoints\n' >&2
fi
rm -f -- "${checkpoint_files[@]}"
