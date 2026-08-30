umask 077

temporary_files=()
cleanup_temporary_files() {
  rm -f -- "${temporary_files[@]}"
}
trap cleanup_temporary_files EXIT

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
history_path="$state_dir/clipboard-history.json"
image_dir="$state_dir/clipboard-images"
prune_grace=${CLIPBOARD_PRUNE_GRACE_SECONDS:-5}
[[ $prune_grace =~ ^[0-9]+$ ]] || prune_grace=5

secure_state() {
  local path

  mkdir -p "$state_dir" "$image_dir"
  chmod 700 "$state_dir" "$image_dir"
  [[ ! -e $history_path ]] || chmod 600 "$history_path"
  while IFS= read -r -d '' path; do
    chmod 600 "$path"
  done < <(find "$image_dir" -mindepth 1 -maxdepth 1 -type f -print0)
}

paste_keys() {
  sleep 0.15
  wtype -M shift -k Insert -m shift 2>/dev/null || true
}

snapshot_entry() {
  local id="$1"
  local output="$2"

  for _ in {1..25}; do
    if [[ -r $history_path ]] && jq -ce --arg id "$id" \
      'first(.[] | select(.id == $id)) // empty' "$history_path" >"$output"; then
      return 0
    fi
    sleep 0.02
  done

  return 1
}

copy_text() {
  local id="$1"
  local snapshot

  [[ -n $id ]] || exit 1
  snapshot=$(mktemp --tmpdir="$state_dir" clipboard-entry.XXXXXX)
  temporary_files+=("$snapshot")
  snapshot_entry "$id" "$snapshot"
  jq -je 'select(.type == "text") | .text | select(type == "string")' "$snapshot" | wl-copy
}

copy_image() {
  local mime="$1"
  local path="$2"

  [[ $mime == image/* && -r $path ]] || exit 1
  wl-copy --type "$mime" <"$path"
}

open_entry() {
  local id="$1"
  local type text path first_line url open_dir open_file snapshot

  [[ -n $id ]] || exit 1
  snapshot=$(mktemp --tmpdir="$state_dir" clipboard-entry.XXXXXX)
  temporary_files+=("$snapshot")
  snapshot_entry "$id" "$snapshot"
  type=$(jq -er '.type' "$snapshot")

  if [[ $type == image ]]; then
    path=$(jq -er '.path' "$snapshot")
    [[ -r $path ]] || exit 1
    xdg-open "$path"
    return
  fi

  [[ $type == text ]] || exit 1
  text=$(jq -er '.text' "$snapshot")
  first_line=${text%%$'\n'*}
  if [[ $first_line == file://* ]]; then
    xdg-open "$first_line"
    return
  fi

  url=$(grep -Eom1 'https?://[^[:space:]"<>]+' <<<"$text" || true)
  if [[ -z $url && $text =~ ^[[:space:]]*([[:alnum:]][[:alnum:].-]+\.[[:alpha:]]{2,})(/[^[:space:]]*)?[[:space:]]*$ ]]; then
    url="https://${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
  fi
  if [[ -n $url ]]; then
    "$CLIPBOARD_BROWSER" "$url"
    return
  fi

  open_dir="$state_dir/clipboard-open"
  mkdir -p "$open_dir"
  open_file=$(mktemp --tmpdir="$open_dir" clipboard.XXXXXX.txt)
  temporary_files+=("$open_file")
  printf '%s' "$text" >"$open_file"
  "$CLIPBOARD_EDITOR" "$open_file"
}

quarantine_history() {
  local backup manifest path

  [[ -e $history_path ]] || return 0
  if jq -e 'type == "array"' "$history_path" >/dev/null 2>&1; then
    return 0
  fi

  backup="${history_path%.json}.corrupt-$(date +%s)-$$.json"
  mv "$history_path" "$backup"
  chmod 600 "$backup"
  manifest="${backup%.json}.images"
  while IFS= read -r -d '' path; do
    printf '%s\n' "$path"
  done < <(find "$image_dir" -mindepth 1 -maxdepth 1 -type f -print0) >"$manifest"
  chmod 600 "$manifest"
}

clear_corrupt_history() {
  local path

  while IFS= read -r -d '' path; do
    rm -f -- "$path"
  done < <(find "$state_dir" -mindepth 1 -maxdepth 1 -type f \
    -name 'clipboard-history.corrupt-*' -print0)
}

prune_images() {
  local path modified now manifest
  declare -A retained=()

  [[ -d $image_dir ]] || return 0
  if [[ -r $history_path ]]; then
    jq -e 'type == "array"' "$history_path" >/dev/null 2>&1 || return 0
    while IFS= read -r path; do
      [[ -n $path ]] && retained["$path"]=1
    done < <(jq -r '.[] | select(.type == "image") | .path // empty' "$history_path")
  fi
  while IFS= read -r -d '' manifest; do
    while IFS= read -r path; do
      [[ -n $path ]] && retained["$path"]=1
    done <"$manifest"
  done < <(find "$state_dir" -mindepth 1 -maxdepth 1 -type f \
    -name 'clipboard-history.corrupt-*.images' -print0)

  now=$(date +%s)
  while IFS= read -r -d '' path; do
    [[ ! ${retained[$path]+retained} ]] || continue
    modified=$(stat -c %Y "$path")
    if (( now - modified < prune_grace )); then
      continue
    fi
    if [[ -r $history_path ]] && jq -e --arg path "$path" \
      'any(.[]; .type == "image" and .path == $path)' "$history_path" >/dev/null; then
      continue
    fi
    rm -f -- "$path"
  done < <(find "$image_dir" -mindepth 1 -maxdepth 1 -type f -print0)
}

action=${1:-}
shift || true
secure_state

case "$action" in
  paste-text)
    copy_only=false
    if [[ ${1:-} == --copy-only ]]; then
      copy_only=true
      shift
    fi
    copy_text "${1:-}"
    [[ $copy_only == true ]] || paste_keys
    ;;
  paste-image)
    copy_only=false
    if [[ ${1:-} == --copy-only ]]; then
      copy_only=true
      shift
    fi
    copy_image "${1:-}" "${2:-}"
    [[ $copy_only == true ]] || paste_keys
    ;;
  open)
    open_entry "${1:-}"
    ;;
  quarantine-history)
    quarantine_history
    ;;
  clear-corrupt-history)
    clear_corrupt_history
    ;;
  prune-images)
    prune_images
    ;;
  *)
    echo "Unknown clipboard action: $action" >&2
    exit 1
    ;;
esac
