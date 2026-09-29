# The Nix package supplies readonly executable and preset paths, preserving PATH.
usage() {
  printf '%s\n' 'Usage: oc [launcher options] [--] [opencode arguments...]

  --profile balanced|openai|anthropic|premium
  --agents custom|stock       Custom orchestration (default) or stock agents
  --review-model fable|opus   Override the custom default reviewer
  --power                    Enable the pinned Superpowers plugin
  --no-auto                  Do not automatically add --auto
  --help                     Show this help (use oc -- --help for native help)

Options also accept --name=value. Launcher parsing ends at the first native
argument or --. Conflicting repeated selectors are errors.

Examples:
  oc --profile premium --power --review-model fable
  oc --agents stock --profile anthropic
  oc --agents stock -- run "Explain this project"

Shared configuration and project rules apply in both agent modes. Stock mode
omits the global custom suite and delegation rules; project agents still apply.
Custom mode supplies its agent preset as an inline override of project settings.
Inherited OPENCODE_CONFIG_CONTENT overrides defaults; explicit launcher options
override it. Plugins and instructions are combined without duplicate entries.'
}

fail() { printf 'oc: %s\n' "$*" >&2; exit 2; }

profile=''
agents=''
reviewer=''
power=false auto=true
args=()
while (( $# )); do
  case "$1" in
    --profile|--agents|--review-model|--profile=*|--agents=*|--review-model=*)
      option=${1%%=*}
      if [[ "$1" == *=* ]]; then
        value=${1#*=}
        shift
      else
        (( $# >= 2 )) || fail "$option requires a value"
        value=$2
        shift 2
      fi
      case "$option:$value" in
        --profile:balanced|--profile:openai|--profile:anthropic|--profile:premium) key=profile ;;
        --agents:custom|--agents:stock) key=agents ;;
        --review-model:fable|--review-model:opus) key=reviewer ;;
        *) fail "invalid value for $option: $value" ;;
      esac
      [[ -z "${!key}" || "${!key}" == "$value" ]] || fail "conflicting $option values"
      printf -v "$key" '%s' "$value"
      ;;
    --power) power=true; shift ;;
    --no-auto) auto=false; shift ;;
    --auto) args+=("$1"); shift ;;
    --help) usage; exit 0 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
args+=("$@")
agents=${agents:-custom}
[[ "$agents" != stock || -z "$reviewer" ]] || fail '--review-model requires --agents custom'

# A nested oc starts from the original input, not its parent's selected preset.
# An explicitly replaced inline config is still honored as new input.
input=${OPENCODE_CONFIG_CONTENT:-"{}"}
if [[ -n "${OC_CONFIG_OUTPUT:-}" && "$input" == "$OC_CONFIG_OUTPUT" ]]; then
  input=${OC_CONFIG_INPUT:-"{}"}
fi
# jq variables are intentionally expanded by jq, not by the shell.
# shellcheck disable=SC2016
if ! config=$(printf '%s\n' "$input" | "$jq" -ces \
  --slurpfile presets "$presets" --arg profile "$profile" --arg agents "$agents" \
  --arg reviewer "$reviewer" --argjson power "$power" '
  def merge($right):
    reduce ($right | keys_unsorted[]) as $key (. ;
      .[$key] = (
        if (.[$key] | type) == "object" and ($right[$key] | type) == "object"
        then .[$key] | merge($right[$key])
        elif ($key == "plugin" or $key == "instructions") and
             (.[$key] | type) == "array" and ($right[$key] | type) == "array"
        then reduce (.[$key] + $right[$key])[] as $item ([];
          if any(.[]; . == $item) then . else . + [$item] end)
        else $right[$key] end));
  if length != 1 or (.[0] | type) != "object" then
    error("OPENCODE_CONFIG_CONTENT must contain one JSON object")
  else .[0] end as $inherited |
  $presets[0] as $p |
  (if $agents == "custom" then $p.custom else {} end) |
  merge($inherited) |
  (if $profile != "" then
    ($p.profiles[$profile] | if $agents == "stock" then
      .agent |= with_entries(select(.key | IN("build", "plan", "general", "explore", "compaction", "title", "summary")))
    else . end) as $selected | merge($selected)
  else . end) |
  (if $power then merge($p.power) else . end) |
  if $reviewer != "" then
    .agent.review.model = $p.reviewModels[$reviewer] | del(.agent.review.variant)
  else . end
'); then
  fail 'cannot compose configuration; check OPENCODE_CONFIG_CONTENT'
fi
export OPENCODE_CONFIG_CONTENT="$config"
export OC_CONFIG_INPUT="$input" OC_CONFIG_OUTPUT="$config"

wait_for_metals_mcp() {
  local resolved url http_status deadline
  [[ -f opencode.json || -f opencode.jsonc ]] || return 0
  resolved=$("$timeout" --kill-after=1s 10s "$native" debug config 2>/dev/null) || return 0
  url=$("$jq" -r '.mcp["metals-lsp"] | select(.type == "remote" and .enabled != false) | .url // empty' \
    <<<"$resolved" 2>/dev/null) || return 0
  [[ "$url" == http://localhost:* || "$url" == http://127.0.0.1:* ]] || return 0
  deadline=$((SECONDS + 60))
  while (( SECONDS < deadline )); do
    http_status=$("$curl" --silent --output /dev/null --write-out '%{http_code}' \
      --connect-timeout 1 --max-time 1 "$url") || http_status=
    [[ "$http_status" == [234][0-9][0-9] ]] && return 0
    "$sleep" 0.25
  done
  printf 'Timed out waiting for Metals MCP at %s; starting OpenCode anyway\n' "$url" >&2
}

has_auto=false herdr_agent=false
for arg in "${args[@]}"; do
  [[ "$arg" != -- ]] || break
  case "$arg" in
    --auto) has_auto=true ;;
    -s|-c|--continue|--session|--session=*|--port|--port=*) herdr_agent=true ;;
  esac
done
if [[ "${HERDR_ENV:-}" == 1 && "$herdr_agent" == true ]]; then
  wait_for_metals_mcp
fi
if [[ "$auto" == true && "$has_auto" == false ]]; then
  args=(--auto "${args[@]}")
fi
exec "$native" "${args[@]}"
