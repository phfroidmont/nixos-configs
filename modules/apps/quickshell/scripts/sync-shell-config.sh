#!/usr/bin/env bash

set -uo pipefail

config="$HOME/.config/omarchy/shell.json"
temporary=""

trap '[[ -z ${temporary:-} ]] || rm -f "$temporary"' EXIT

warn() {
  printf 'quickshell config migration: %s\n' "$1" >&2
}

migrate() {
  if [[ -L $config ]]; then
    warn "leaving symlink-managed config unchanged: $config"
    return 0
  fi
  if [[ ! -e $config ]]; then
    return 0
  fi
  if [[ ! -f $config ]]; then
    warn "leaving non-regular config unchanged: $config"
    return 0
  fi

  if jq --exit-status --slurp '
    length == 1
    and (.[0] | type) == "object"
    and (.[0].nixosConfigMigrations.notifications | type) == "number"
    and (.[0].nixosConfigMigrations.notifications // 0) >= 1
  ' "$config" >/dev/null 2>&1; then
    return 0
  fi

  local directory
  directory=$(dirname "$config")
  temporary=$(mktemp "$directory/.shell.json.XXXXXX") || {
    warn "could not create a temporary file beside $config"
    return 0
  }

  if ! jq --slurp '
    def widget_id:
      if type == "string" then . else (.id // "") end;
    def selected_id:
      if type == "string" then . else (.id // "") end;
    def selection_is_nonempty:
      if type == "array" or type == "string" then length > 0 else false end;
    def selection_shows_dnd:
      if type == "array" then
        any(.[]; selected_id == "Dnd")
      else
        . == "Dnd"
      end;
    def indicator_shows_dnd:
      if widget_id != "omarchy.indicators" then false
      elif type != "object" then true
      elif (.items | selection_is_nonempty) then (.items | selection_shows_dnd)
      elif (.indicators | selection_is_nonempty) then (.indicators | selection_shows_dnd)
      else true
      end;
    def normalize_indicator:
      if widget_id == "omarchy.indicators" and type == "object" and .items == "Dnd" then
        .items = ["Dnd"]
      elif widget_id == "omarchy.indicators" and type == "object" and .indicators == "Dnd" then
        .indicators = ["Dnd"]
      else
        .
      end;
    def dnd_indicator:
      {id: "omarchy.indicators", items: ["Dnd"]};

    if length != 1 then
      error("shell config must contain one JSON document")
    elif (.[0] | type) != "object" or .[0].version != 1 then
      error("unsupported shell config")
    elif (.[0] | [.. | numbers | select(isnan or isinfinite)] | length) > 0 then
      error("shell config contains a non-finite number")
    else
      .[0]
    end
    | .disabledPlugins = [
        (.disabledPlugins // [])[]
        | select(. != "omarchy.notifications" and . != "omarchy.indicators")
      ]
    | .bar.layout.left = [(.bar.layout.left // [])[] | normalize_indicator]
    | .bar.layout.center = [(.bar.layout.center // [])[] | normalize_indicator]
    | .bar.layout.right = [(.bar.layout.right // [])[] | normalize_indicator]
    | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
        | any(indicator_shows_dnd)) as $has_dnd
    | if $has_dnd then . else
        (.bar.layout.center | map(widget_id) | index("omarchy.clock")) as $clock
        | .bar.layout.center = if $clock == null then
            [dnd_indicator] + .bar.layout.center
          else
            .bar.layout.center[0:$clock]
            + [dnd_indicator]
            + .bar.layout.center[$clock:]
          end
      end
    | .nixosConfigMigrations.notifications = 1
  ' "$config" >"$temporary"; then
    warn "leaving invalid config unchanged: $config"
    return 0
  fi

  if ! cmp -s "$config" "$temporary"; then
    chmod --reference="$config" "$temporary" || {
      warn "could not preserve permissions on $config"
      return 0
    }
    mv "$temporary" "$config" || {
      warn "could not replace $config"
      return 0
    }
    temporary=""
  fi
}

migrate
exit 0
