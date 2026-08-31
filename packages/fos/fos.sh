# shellcheck shell=bash

set -euo pipefail

nh_command=${FOS_NH:-nh}
nix_command=${FOS_NIX:-nix}
hostname_command=${FOS_HOSTNAME:-hostname}
auth_command=${FOS_AUTH_COMMAND:-refresh-nix-gitlab-token}
vpn_command=${FOS_VPN_COMMAND:-aegis-vpn}

usage() {
  cat <<'EOF'
Froidmont Operating System command center

Usage:
  fos <command> [arguments]

Commands:
  hosts                              List operational host configurations
  build [HOST]                       Build a host without activating it
  test                               Temporarily activate the local host
  switch                             Activate and persist the local host
  boot                               Select the local host for the next boot
  update [INPUT...]                  Update inputs and build the local host
  generations                        List local NixOS generations
  rollback [GENERATION]              Roll back the local NixOS generation
  auth refresh [GITLAB_HOST]         Refresh Nix's GitLab credentials
  vpn <COMMAND> [ARGUMENTS]          Control the Aegis Mullvad gateway

Run fos <command> --help for command-specific usage.
EOF
}

command_usage() {
  case "$1" in
    hosts)
      printf '%s\n' 'Usage: fos hosts'
      ;;
    build)
      printf '%s\n' 'Usage: fos build [HOST]'
      ;;
    test | switch | boot)
      printf 'Usage: fos %s\n' "$1"
      ;;
    update)
      printf '%s\n' 'Usage: fos update [INPUT...]'
      ;;
    generations)
      printf '%s\n' 'Usage: fos generations'
      ;;
    rollback)
      printf '%s\n' 'Usage: fos rollback [GENERATION]'
      ;;
    auth)
      printf '%s\n' 'Usage: fos auth refresh [GITLAB_HOST]'
      ;;
    vpn)
      cat <<'EOF'
Usage:
  fos vpn up
  fos vpn down
  fos vpn status
  fos vpn list
  fos vpn switch SERVER
EOF
      ;;
    *)
      usage
      ;;
  esac
}

fail() {
  printf 'fos: %s\n' "$1" >&2
  exit 2
}

require_command() {
  local command=$1

  if [[ $command == */* ]]; then
    [[ -x $command ]] || fail "required command is not executable: $command"
  elif ! command -v "$command" >/dev/null 2>&1; then
    fail "required command is unavailable: $command"
  fi
}

run_command() {
  printf '+' >&2
  printf ' %q' "$@" >&2
  printf '\n' >&2
  exec "$@"
}

flake_path() {
  local flake=${NH_OS_FLAKE:-${NH_FLAKE:-}}

  [[ -n $flake ]] || fail 'NH_OS_FLAKE and NH_FLAKE are unset; configure programs.nh.flake'
  [[ -d $flake && -f $flake/flake.nix ]] || fail "configured flake is not a flake directory: $flake"
  printf '%s\n' "$flake"
}

operational_hosts() {
  local flake=$1

  require_command "$nix_command"
  "$nix_command" eval --raw "$flake#nixosConfigurations" --apply \
    'configs: builtins.concatStringsSep "\n" (builtins.filter (name: name != "aegis-installer") (builtins.attrNames configs)) + "\n"'
}

require_operational_host() {
  local flake=$1
  local host=$2
  local hosts

  hosts=$(operational_hosts "$flake")
  if ! grep -Fxq -- "$host" <<<"$hosts"; then
    printf "fos: unknown operational host '%s'\n" "$host" >&2
    printf '%s\n' "$hosts" >&2
    exit 2
  fi
}

local_host() {
  require_command "$hostname_command"
  "$hostname_command"
}

run_local_rebuild() {
  local action=$1
  local flake host

  flake=$(flake_path)
  host=$(local_host)
  require_operational_host "$flake" "$host"
  require_command "$nh_command"
  run_command "$nh_command" os "$action" "$flake" -H "$host" --ask
}

if (($# == 0)); then
  usage
  exit 0
fi

case "$1" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

for argument in "${@:2}"; do
  case "$argument" in
    -h | --help)
      command_usage "$1"
      exit 0
      ;;
  esac
done

command=$1
shift

case "$command" in
  hosts)
    (($# == 0)) || fail 'hosts takes no arguments'
    flake=$(flake_path)
    operational_hosts "$flake"
    ;;

  build)
    (($# <= 1)) || fail 'build accepts at most one host'
    flake=$(flake_path)
    host=${1:-$(local_host)}
    require_operational_host "$flake" "$host"
    require_command "$nh_command"
    run_command "$nh_command" os build "$flake" -H "$host"
    ;;

  test | switch | boot)
    (($# == 0)) || fail "$command always targets the local host and takes no arguments"
    run_local_rebuild "$command"
    ;;

  update)
    update_arguments=()
    flake=$(flake_path)
    host=$(local_host)
    require_operational_host "$flake" "$host"
    require_command "$nh_command"

    for input in "$@"; do
      [[ $input != -* ]] || fail "invalid flake input: $input"
      update_arguments+=(--update-input "$input")
    done

    if (($# == 0)); then
      run_command "$nh_command" os build "$flake" -H "$host" --update
    else
      run_command "$nh_command" os build "$flake" -H "$host" "${update_arguments[@]}"
    fi
    ;;

  generations)
    (($# == 0)) || fail 'generations takes no arguments'
    require_command "$nh_command"
    run_command "$nh_command" os info
    ;;

  rollback)
    (($# <= 1)) || fail 'rollback accepts at most one generation'
    require_command "$nh_command"
    if (($# == 0)); then
      run_command "$nh_command" os rollback --ask
    fi
    [[ $1 =~ ^[1-9][0-9]*$ ]] || fail "invalid generation: $1"
    run_command "$nh_command" os rollback --to "$1" --ask
    ;;

  auth)
    [[ ${1:-} == refresh ]] || fail 'auth requires the refresh command'
    shift
    (($# <= 1)) || fail 'auth refresh accepts at most one GitLab host'
    if (($# == 1)); then
      [[ $1 != -* ]] || fail "invalid GitLab host: $1"
    fi
    require_command "$auth_command"
    run_command "$auth_command" "$@"
    ;;

  vpn)
    vpn_action=${1:-}
    [[ -n $vpn_action ]] || fail 'vpn requires a command'
    shift

    case "$vpn_action" in
      up | down | status | list)
        (($# == 0)) || fail "vpn $vpn_action takes no arguments"
        ;;
      switch)
        (($# == 1)) || fail 'vpn switch requires exactly one server'
        [[ $1 != -* ]] || fail "invalid VPN server: $1"
        ;;
      *)
        fail "unknown VPN command: $vpn_action"
        ;;
    esac

    require_command "$vpn_command"
    run_command "$vpn_command" "$vpn_action" "$@"
    ;;

  *)
    printf "fos: unknown command '%s'\n\n" "$command" >&2
    usage >&2
    exit 2
    ;;
esac
