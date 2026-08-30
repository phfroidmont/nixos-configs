#!/usr/bin/env bash

set -euo pipefail
umask 022

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
action="$root/scripts/clipboard-action.sh"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

export HOME="$temporary/home"
export XDG_STATE_HOME="$temporary/state"
state_dir="$XDG_STATE_HOME/quickshell"
image_dir="$state_dir/clipboard-images"
history_path="$state_dir/clipboard-history.json"
fake_bin="$temporary/bin"
mkdir -p "$HOME" "$image_dir" "$fake_bin"

export COPY_OUTPUT="$temporary/copied"
export COPY_ARGS="$temporary/copy-args"
export WTYPE_OUTPUT="$temporary/wtype"
export OPEN_OUTPUT="$temporary/open"
export BROWSER_OUTPUT="$temporary/browser"
export EDITOR_TEXT_OUTPUT="$temporary/editor-text"

cat >"$fake_bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$COPY_ARGS"
cat >"$COPY_OUTPUT"
EOF
cat >"$fake_bin/wtype" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$WTYPE_OUTPUT"
EOF
cat >"$fake_bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$OPEN_OUTPUT"
EOF
cat >"$fake_bin/browser" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$BROWSER_OUTPUT"
EOF
cat >"$fake_bin/editor" <<'EOF'
#!/usr/bin/env bash
cat "$1" >"$EDITOR_TEXT_OUTPUT"
EOF
chmod +x "$fake_bin"/*

export PATH="$fake_bin:$PATH"
export CLIPBOARD_BROWSER="$fake_bin/browser"
export CLIPBOARD_EDITOR="$fake_bin/editor"
export CLIPBOARD_PRUNE_GRACE_SECONDS=0

image="$image_dir/referenced.png"
printf 'image data' >"$image"
jq -n --arg image "$image" '[
  {type: "text", text: "complete text value", id: "text-1"},
  {type: "image", mime: "image/png", path: $image, id: "image-1"}
]' >"$history_path"

bash "$action" paste-text --copy-only text-1
[[ $(<"$COPY_OUTPUT") == "complete text value" ]]
[[ ! -e $WTYPE_OUTPUT ]]
[[ $(stat -c %a "$state_dir") == 700 ]]
[[ $(stat -c %a "$image_dir") == 700 ]]
[[ $(stat -c %a "$history_path") == 600 ]]

bash "$action" paste-text text-1
[[ $(<"$WTYPE_OUTPUT") == "-M shift -k Insert -m shift" ]]

jq -n '[]' >"$history_path"
(
  sleep 0.1
  jq -n '[{type: "text", text: "delayed value", id: "delayed-1"}]' >"$history_path"
) &
writer_pid=$!
bash "$action" paste-text --copy-only delayed-1
wait "$writer_pid"
[[ $(<"$COPY_OUTPUT") == "delayed value" ]]

bash "$action" paste-image --copy-only image/png "$image"
[[ $(<"$COPY_OUTPUT") == "image data" ]]
[[ $(<"$COPY_ARGS") == "--type image/png" ]]

jq -n --arg image "$image" '[
  {type: "image", mime: "image/png", path: $image, id: "image-1"}
]' >"$history_path"

orphan="$image_dir/orphan.png"
printf 'orphan' >"$orphan"
bash "$action" prune-images
[[ -e $image ]]
[[ ! -e $orphan ]]

recent="$image_dir/recent.png"
printf 'recent' >"$recent"
CLIPBOARD_PRUNE_GRACE_SECONDS=60 bash "$action" prune-images
[[ -e $recent ]]
CLIPBOARD_PRUNE_GRACE_SECONDS=0 bash "$action" prune-images
[[ ! -e $recent ]]

bash "$action" open image-1
[[ $(<"$OPEN_OUTPUT") == "$image" ]]

jq -n '[{type: "text", text: "See https://example.com/docs now", id: "url-1"}]' >"$history_path"
bash "$action" open url-1
[[ $(<"$BROWSER_OUTPUT") == "https://example.com/docs" ]]

jq -n '[{type: "text", text: "plain clipboard notes", id: "notes-1"}]' >"$history_path"
bash "$action" open notes-1
[[ $(<"$EDITOR_TEXT_OUTPUT") == "plain clipboard notes" ]]
[[ -z $(find "$state_dir/clipboard-open" -mindepth 1 -maxdepth 1 -type f -print -quit) ]]

printf 'one' >"$image_dir/one.png"
printf 'two' >"$image_dir/two.png"
jq -n '[]' >"$history_path"
bash "$action" prune-images
[[ -z $(find "$image_dir" -mindepth 1 -maxdepth 1 -type f -print -quit) ]]

printf 'recoverable' >"$image_dir/recoverable.png"
printf 'not valid json' >"$history_path"
bash "$action" quarantine-history
[[ ! -e $history_path ]]
[[ -n $(find "$state_dir" -mindepth 1 -maxdepth 1 -name 'clipboard-history.corrupt-*.json' -print -quit) ]]
bash "$action" prune-images
[[ -e $image_dir/recoverable.png ]]
printf 'new orphan' >"$image_dir/new-orphan.png"
bash "$action" prune-images
[[ ! -e $image_dir/new-orphan.png ]]
bash "$action" clear-corrupt-history
jq -n '[]' >"$history_path"
bash "$action" prune-images
[[ ! -e $image_dir/recoverable.png ]]

printf 'clipboard action tests passed\n'
