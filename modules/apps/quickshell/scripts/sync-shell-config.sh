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
    and (.[0].nixosConfigMigrations.menuWidget | type) == "number"
    and (.[0].nixosConfigMigrations.menuWidget // 0) >= 1
    and (.[0].nixosConfigMigrations.statusFeatures | type) == "number"
    and (.[0].nixosConfigMigrations.statusFeatures // 0) >= 2
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
    def indicator_shows($wanted):
      if widget_id != "omarchy.indicators" then false
      elif type != "object" then true
      elif (.items | selection_is_nonempty) then
        (.items | if type == "array" then any(.[]; selected_id == $wanted) else . == $wanted end)
      elif (.indicators | selection_is_nonempty) then
        (.indicators | if type == "array" then any(.[]; selected_id == $wanted) else . == $wanted end)
      else true
      end;
    def dnd_only_indicator:
      widget_id == "omarchy.indicators"
      and type == "object"
      and (
        .items == "Dnd" or .items == ["Dnd"]
        or .indicators == "Dnd" or .indicators == ["Dnd"]
      );
    def status_indicator:
      .items = ["ScreenRecording", "Dictation", "Reminder", "Dnd", "StayAwake"]
      | del(.indicators);
    def add_dictation:
      .items = [.items[] | ., if selected_id == "ScreenRecording" then "Dictation" else empty end];
    def insert_before($before; $entry):
      (map(widget_id) | index($before)) as $index
      | if $index == null then . + [$entry]
        else .[0:$index] + [$entry] + .[$index:]
        end;

    if length != 1 then
      error("shell config must contain one JSON document")
    elif (.[0] | type) != "object" or .[0].version != 1 then
      error("unsupported shell config")
    elif (.[0] | [.. | numbers | select(isnan or isinfinite)] | length) > 0 then
      error("shell config contains a non-finite number")
    else
      .[0]
    end
    | if ((.nixosConfigMigrations.notifications | type) == "number"
        and (.nixosConfigMigrations.notifications // 0) >= 1) then . else
        .disabledPlugins = [
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
      end
    | if ((.nixosConfigMigrations.menuWidget | type) == "number"
        and (.nixosConfigMigrations.menuWidget // 0) >= 1) then . else
        .bar.layout.left = [(.bar.layout.left // [])[] | select(widget_id != "omarchy.menu")]
        | .bar.layout.center = [(.bar.layout.center // [])[] | select(widget_id != "omarchy.menu")]
        | .bar.layout.right = [(.bar.layout.right // [])[] | select(widget_id != "omarchy.menu")]
        | .nixosConfigMigrations.menuWidget = 1
      end
    | if ((.nixosConfigMigrations.statusFeatures | type) == "number"
        and (.nixosConfigMigrations.statusFeatures // 0) >= 2) then .
      elif ((.disabledPlugins // []) | index("omarchy.indicators")) != null then
        .nixosConfigMigrations.statusFeatures = 2
      else
        .disabledPlugins = [
          (.disabledPlugins // [])[]
          | select(
              . != "omarchy.microphone"
              and . != "omarchy.reminders"
              and . != "omarchy.tailscale"
            )
        ]
        | .bar.layout.left = [(.bar.layout.left // [])[]]
        | .bar.layout.center = [
            (.bar.layout.center // [])[]
            | if dnd_only_indicator then status_indicator
              elif widget_id == "omarchy.indicators"
                and (.items | type) == "array"
                and indicator_shows("ScreenRecording")
                and (indicator_shows("Dictation") | not)
              then add_dictation
              else .
              end
          ]
        | .bar.layout.right = [(.bar.layout.right // [])[]]
        | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
            | any(indicator_shows("ScreenRecording"))) as $has_recording
        | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
            | any(indicator_shows("Dictation"))) as $has_dictation
        | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
            | any(indicator_shows("Reminder"))) as $has_reminder
        | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
            | any(indicator_shows("StayAwake"))) as $has_stay_awake
        | ([
            (if $has_recording then empty else "ScreenRecording" end),
            (if $has_dictation then empty else "Dictation" end),
            (if $has_reminder then empty else "Reminder" end),
            (if $has_stay_awake then empty else "StayAwake" end)
          ]) as $missing_indicators
        | if ($missing_indicators | length) == 0 then . else
            (.bar.layout.center | map(widget_id) | index("omarchy.clock")) as $clock
            | .bar.layout.center = if $clock == null then
                .bar.layout.center + [{id: "omarchy.indicators", items: $missing_indicators}]
              else
                .bar.layout.center[0:$clock]
                + [{id: "omarchy.indicators", items: $missing_indicators}]
                + .bar.layout.center[$clock:]
              end
          end
        | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
            | any(widget_id == "omarchy.media")) as $has_media
        | if $has_media then . else
            .bar.layout.center = [{id: "omarchy.media"}] + .bar.layout.center
          end
        | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
            | any(widget_id == "omarchy.tailscale")) as $has_tailscale
        | if $has_tailscale then . else
            .bar.layout.right |= insert_before("omarchy.audio"; {id: "omarchy.tailscale"})
          end
        | ([.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]]
            | any(widget_id == "omarchy.microphone")) as $has_microphone
        | if $has_microphone then . else
            .bar.layout.right |= insert_before("omarchy.audio"; {id: "omarchy.microphone"})
          end
        | .nixosConfigMigrations.statusFeatures = 2
      end
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
