#!/usr/bin/env bash

set -euo pipefail

: "${DICTATION_STATUS_SOURCE:?set DICTATION_STATUS_SOURCE to dictation-status.sh}"

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
bash_bin=$(type -P bash)

idle=$(PATH="$test_root" "$bash_bin" "$DICTATION_STATUS_SOURCE")
[[ $idle == '{"alt": "", "class": "idle", "tooltip": ""}' ]]

mkdir -p "$test_root/bin"
cat >"$test_root/bin/voxtype" <<EOF
#!$bash_bin
exit 99
EOF
cat >"$test_root/bin/setpriv" <<EOF
#!$bash_bin
printf '%s\n' "\$*"
EOF
chmod +x "$test_root/bin/voxtype" "$test_root/bin/setpriv"

invocation=$(PATH="$test_root/bin" "$bash_bin" "$DICTATION_STATUS_SOURCE")
[[ $invocation == '--pdeathsig TERM voxtype status --follow --extended --format json' ]]

printf 'dictation status tests passed\n'
