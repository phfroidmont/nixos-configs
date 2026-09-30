#compdef oc

_oc() {
  local -a wrapper_options native_options native_commands values subcommands
  local flag arg command subcommand third_command option previous
  local -i index=2 native_start=0 end_options=0

  wrapper_options=(
    --profile --agents --review-model --auto --no-auto --help
  )
  native_commands=(
    acp api mcp run mini debug auth upgrade uninstall serve models stats
    session plugin service reload pair
  )

  # Only completed arguments can determine whether the cursor is still in the
  # wrapper prefix. A value (including --key=value) belongs to its option.
  while (( index < CURRENT )); do
    arg=${words[index]}
    case $arg in
      --) native_start=$(( index + 1 )); break ;;
      --profile|--agents|--review-model)
        (( index++ ))
        ;;
      --profile=*|--agents=*|--review-model=*|--auto|--no-auto|--help)
        ;;
      *) native_start=$index; break ;;
    esac
    (( index++ ))
  done

  if (( native_start == 0 )); then
    flag=''
    if (( CURRENT > 2 )); then
      case ${words[CURRENT-1]} in
        --profile|--agents|--review-model) flag=${words[CURRENT-1]} ;;
      esac
    fi
    if [[ -z $flag ]]; then
      case ${words[CURRENT]} in
        --profile=*|--agents=*|--review-model=*)
          flag=${words[CURRENT]%%=*}
          compset -P "${flag}="
          ;;
      esac
    fi
    case $flag in
      --profile) values=(balanced openai anthropic premium) ;;
      --agents) values=(custom stock) ;;
      --review-model) values=(fable opus) ;;
    esac
    if [[ -n $flag ]]; then
      compadd -- "${values[@]}"
      return
    fi
    if [[ ${words[CURRENT]} == -* ]]; then
      compadd -X 'oc options' -- "${wrapper_options[@]}"
    fi
    native_start=$CURRENT
  fi

  # The native completer sees only its own argv and the native command name.
  # Delegate to an installed completer; the fallback does not run OpenCode.
  local native_completer=${_comps[opencode]-}
  if [[ -n $native_completer ]] && (( $+functions[$native_completer] )); then
    local -a words=(opencode "${(@)words[native_start,-1]}")
    local -i CURRENT=$(( CURRENT - native_start + 2 ))
    local service=opencode
    "$native_completer"
    return
  fi
  if (( $+functions[_opencode] )); then
    local -a words=(opencode "${(@)words[native_start,-1]}")
    local -i CURRENT=$(( CURRENT - native_start + 2 ))
    local service=opencode
    _opencode
    return
  fi

  # Fallback for installations without a native completion function. Walk only
  # completed words; option values must not be mistaken for subcommands.
  command='' subcommand='' third_command='' previous=''
  for (( index=native_start; index<CURRENT; index++ )); do
    arg=${words[index]}
    if [[ -n $previous ]]; then
      previous=''
      continue
    fi
    if [[ $arg == -- ]]; then
      end_options=1
      continue
    fi
    if (( ! end_options )); then
      if [[ $arg == -f && $command != run ]]; then
        continue
      fi
      case $arg in
        --model|--agent|--session|--hostname|--port|--prompt|--log-level|-m|-s|--dir|--cwd|--file|-f|--path|--format|--method|--days|--tools|--project|--max-count|-n|--replay-limit|--mdns-domain|--cors|--command|--title|--attach|--password|-p|--username|-u|--variant|--description|--mode|--permissions|--env|--header|--url|--event|--token)
          previous=$arg; continue ;;
        -*) continue ;;
      esac
    fi
    if [[ -z $command ]]; then
      command=$arg
    elif [[ -z $subcommand ]]; then
      subcommand=$arg
    elif [[ -z $third_command ]]; then
      third_command=$arg
    fi
  done

  native_options=(--help -h --version -v --print-logs --log-level --server --completions)
  case $command in
    ''|acp|serve|web)
      native_options+=(--port --hostname --mdns --mdns-domain --cors)
      [[ $command == acp ]] && native_options+=(--cwd)
      if [[ -z $command ]]; then
        native_options+=(-m --model -c --continue -s --session --fork --prompt --agent --auto --mini --no-replay --replay-limit)
      fi ;;
    run)
      native_options+=(--command -c --continue -s --session --fork --share -m --model --agent --format -f --file --title --attach -p --password -u --username --dir --port --variant --thinking -i --interactive --auto) ;;
    attach)
      native_options+=(--dir -c --continue -s --session --fork -p --password -u --username --mini --no-replay --replay-limit) ;;
    upgrade) native_options+=(-m --method) ;;
    uninstall) native_options+=(-c --keep-config -d --keep-data --dry-run -f --force) ;;
    models) native_options+=(--verbose --refresh) ;;
    stats) native_options+=(--days --tools --models --project) ;;
    export) native_options+=(--sanitize) ;;
    plugin|plug) native_options+=(-g --global -f --force) ;;
    db) native_options+=(--format) ;;
  esac
  case "$command $subcommand" in
    'agent create') native_options+=(--path --description --mode --permissions --tools -m --model) ;;
    'mcp add') native_options+=(--url --env --header) ;;
    'github run') native_options+=(--event --token) ;;
    'session list') native_options+=(-n --max-count --format) ;;
  esac

  option=''
  if (( CURRENT > native_start )); then
    case ${words[CURRENT-1]} in
      --model|--agent|--session|--hostname|--port|--prompt|--log-level|-m|-s|--dir|--cwd|--file|-f|--path|--format|--method|--days|--tools|--project|--max-count|-n|--replay-limit|--mdns-domain|--cors|--command|--title|--attach|--password|-p|--username|-u|--variant|--description|--mode|--permissions|--env|--header|--url|--event|--token)
        option=${words[CURRENT-1]} ;;
    esac
  fi
  if [[ -z $option && ${words[CURRENT]} == --*=* ]]; then
    option=${words[CURRENT]%%=*}
    compset -P "${option}="
  fi
  [[ $option == -f && $command != run ]] && option=''
  if [[ -n $option ]]; then
    case $option in
      --log-level) values=(DEBUG INFO WARN ERROR) ;;
      --format)
        case "$command $subcommand" in
          'run '* ) values=(default json) ;;
          'session list') values=(table json) ;;
          'db '* ) values=(json tsv) ;;
        esac ;;
      --method) values=(curl npm pnpm bun brew choco scoop) ;;
      -m)
        [[ $command == upgrade ]] && values=(curl npm pnpm bun brew choco scoop) || values=(provider/model) ;;
      --mode) values=(all primary subagent) ;;
      --hostname) values=(127.0.0.1 localhost 0.0.0.0) ;;
      --port) values=(0 4096) ;;
      --agent) values=(build plan general explore) ;;
      --model) values=(provider/model) ;;
      --dir|--cwd|--file|--path) _files; return ;;
      -f) [[ $command == run ]] && _files; return ;;
    esac
    (( ${#values} )) && compadd -- "${values[@]}"
    return
  fi

  if (( ! end_options )) && [[ ${words[CURRENT]} == -* ]]; then
    compadd -X 'opencode options' -- "${native_options[@]}"
    return
  fi
  if [[ -z $command ]]; then
    compadd -X 'opencode commands' -- "${native_commands[@]}"
    _files
    return
  fi
  subcommands=()
  case $command in
    mcp) subcommands=(add list ls auth logout debug) ;;
    auth) subcommands=(list login logout switch import export) ;;
    agent) subcommands=(create list) ;;
    debug)
      case $subcommand in
        '') subcommands=(config agents paths) ;;
        file) [[ -z $third_command ]] && subcommands=(read list search) ;;
      esac ;;
    github) subcommands=(install run) ;;
    session) subcommands=(list delete export import) ;;
    service) subcommands=(start stop restart status get set unset) ;;
    plugin) subcommands=(list add remove check update) ;;
    db) subcommands=(path) ;;
  esac
  if (( ${#subcommands} )) && (( ! end_options )); then
    compadd -X 'opencode subcommands' -- "${subcommands[@]}"
  fi
  if (( ! ${native_commands[(Ie)$command]} )); then
    _files
    return
  fi
  case "$command $subcommand" in
    'import '*|'debug file'|'agent create') _files ;;
  esac
}

_oc "$@"
