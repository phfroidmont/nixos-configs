#!/usr/bin/env bash

if ! command -v voxtype >/dev/null 2>&1; then
  printf '%s\n' '{"alt": "", "class": "idle", "tooltip": ""}'
  exit 0
fi

# Keep the status follower as Quickshell's direct child so it receives TERM
# when Quickshell exits instead of surviving under the user systemd instance.
exec setpriv --pdeathsig TERM voxtype status --follow --extended --format json
