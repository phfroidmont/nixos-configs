set -euo pipefail

config="$HOME/.config/omarchy/shell.toml"
current() {
  [[ -f $config ]] || return 0
  awk '/^[[:space:]]*\[/ { f=($0 ~ /^[[:space:]]*\[font\]([[:space:]]|$)/); next } f && /^[[:space:]]*base-size[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]*(#.*)?$/, ""); print; exit }' "$config"
}
write_config() {
  local value=$1 dir tmp
  dir=$(dirname "$config"); mkdir -p "$dir"; tmp=$(mktemp "$dir/.shell.toml.XXXXXX")
  if [[ ! -f $config ]]; then printf '[font]\nbase-size = %s\n' "$value" >"$tmp"
  else
    awk -v value="$value" '
      function emit() { if (value != "") print "base-size = " value; done=1 }
      /^[[:space:]]*\[/ { if (font && !done) emit(); font=($0 ~ /^[[:space:]]*\[font\]([[:space:]]|$)/); print; next }
      font && /^[[:space:]]*base-size[[:space:]]*=/ { if(!done) emit(); next }
      { print }
      END { if(font && !done) emit(); if(!done && value != "") { if(NR) print ""; print "[font]"; emit() } }
    ' "$config" >"$tmp"
    chmod --reference="$config" "$tmp"
  fi
  mv "$tmp" "$config"
}
case "${1:-}" in
  "") value=$(current); printf '%s\n' "${value:-12}" ;;
  reset|default) write_config "" ;;
  *) (( $# == 1 )) || { echo "Usage: fos-internal-display-text-size [9-20|reset]" >&2; exit 2; }
     if [[ ! $1 =~ ^[0-9]+$ ]] || (( $1 < 9 || $1 > 20 )); then
       echo "Size must be between 9 and 20" >&2
       exit 2
     fi
     write_config "$1" ;;
esac
