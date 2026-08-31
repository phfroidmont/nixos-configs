set -euo pipefail

[[ ${1:-} == "" || ${1:-} == --active-state ]] || { echo "Usage: fos-internal-powerprofiles-list [--active-state]" >&2; exit 2; }
powerprofilesctl list | awk -v state="${1:+1}" '/^[[:space:]]*[* ]?[[:space:]]*[a-zA-Z0-9-]+:$/ { active=($1=="*"); gsub(/^[*[:space:]]+|:$/, ""); print $0 (state ? "\t" active : "") }'
