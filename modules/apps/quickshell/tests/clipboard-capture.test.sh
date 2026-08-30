#!/usr/bin/env bash

set -euo pipefail
umask 022

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
capture="$root/scripts/clipboard-capture.sh"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

export HOME="$temporary/home"
export XDG_STATE_HOME="$temporary/state"
fake_bin="$temporary/bin"
mkdir -p "$HOME" "$fake_bin"

cat >"$fake_bin/wl-paste" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --list-types ]]; then
  sleep "${WL_LIST_TYPES_DELAY:-0}"
  printf '%b' "${WL_PASTE_TYPES:-text/plain\n}"
elif [[ ${1:-} == --type && ${2:-} == text ]]; then
  printf '%s' "${WL_PASTE_TEXT:-snapshot text}"
elif [[ ${1:-} == --type && ${2:-} == image/* ]]; then
  printf '%s' "${WL_PASTE_IMAGE_PREFIX:-}"
  sleep "${WL_PASTE_DELAY:-0}"
  printf '%s' "${WL_PASTE_IMAGE:-snapshot image}"
fi
EOF
cat >"$fake_bin/file" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FILE_MIME_TYPE:-image/webp}"
EOF
chmod +x "$fake_bin/wl-paste" "$fake_bin/file"
export PATH="$fake_bin:$PATH"

captured=$(printf 'watched text' | bash "$capture" text)
[[ $(jq -r '.type' <<<"$captured") == text ]]
[[ $(jq -r '.text' <<<"$captured") == "watched text" ]]

captured=$(WL_PASTE_TEXT="current text" bash "$capture")
[[ $(jq -r '.text' <<<"$captured") == "current text" ]]

captured=$(printf 'secret' | CLIPBOARD_STATE=sensitive bash "$capture" text)
[[ -z $captured ]]
captured=$(WL_PASTE_TYPES='text/plain\nx-kde-passwordManagerHint\n' bash "$capture")
[[ -z $captured ]]

captured=$(printf 'png data' | bash "$capture" image/png)
image_path=$(jq -r '.path' <<<"$captured")
[[ $(jq -r '.mime' <<<"$captured") == image/png ]]
[[ $image_path == "$XDG_STATE_HOME/quickshell/clipboard-images/"*.png ]]
[[ $(<"$image_path") == "png data" ]]
[[ $(stat -c %a "$XDG_STATE_HOME/quickshell") == 700 ]]
[[ $(stat -c %a "$XDG_STATE_HOME/quickshell/clipboard-images") == 700 ]]
[[ $(stat -c %a "$image_path") == 600 ]]

duplicate=$(printf 'png data' | bash "$capture" image/png)
[[ $(jq -r '.path' <<<"$duplicate") == "$image_path" ]]
[[ $(find "$XDG_STATE_HOME/quickshell/clipboard-images" -mindepth 1 -maxdepth 1 -type f | wc -l) == 1 ]]

captured=$(printf 'webp data' | bash "$capture" image)
[[ $(jq -r '.mime' <<<"$captured") == image/webp ]]
[[ $(jq -r '.path' <<<"$captured") == *.webp ]]

captured=$(printf '12345' | CLIPBOARD_TEXT_LIMIT_BYTES=4 bash "$capture" text)
[[ -z $captured ]]
captured=$(printf '12345' | CLIPBOARD_IMAGE_LIMIT_BYTES=4 bash "$capture" image/png)
[[ -z $captured ]]

before=$(find "$XDG_STATE_HOME/quickshell/clipboard-images" -mindepth 1 -maxdepth 1 -type f | wc -l)
captured=$(WL_PASTE_TYPES='image/png\n' WL_PASTE_IMAGE_PREFIX=partial WL_PASTE_DELAY=2 CLIPBOARD_CAPTURE_TIMEOUT_SECONDS=1 bash "$capture")
after=$(find "$XDG_STATE_HOME/quickshell/clipboard-images" -mindepth 1 -maxdepth 1 -type f | wc -l)
[[ -z $captured ]]
[[ $after == "$before" ]]
[[ -z $(find "$XDG_STATE_HOME/quickshell" -mindepth 1 -maxdepth 1 -name 'clipboard-text.*' -print -quit) ]]

captured=$(printf 'delayed types' | WL_LIST_TYPES_DELAY=2 CLIPBOARD_CAPTURE_TIMEOUT_SECONDS=1 bash "$capture" text)
[[ $(jq -r '.text' <<<"$captured") == "delayed types" ]]

printf 'clipboard capture tests passed\n'
