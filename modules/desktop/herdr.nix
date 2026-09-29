{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.herdr;
  user = config.user.name;
  homeDirectory = config.home-manager.users.${user}.home.homeDirectory;
  projectsDirectory = "${homeDirectory}/Projects";
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # Keep child prompt transitions scoped to the root session until herdrdev/herdr#3052 is fixed.
  herdrAgentState = pkgs.runCommand "herdr-agent-state.js" { } ''
    substitute ${inputs.herdr}/src/integration/assets/opencode/herdr-agent-state.js "$out" \
      --replace-fail \
      'await reportState(state);' \
      'await reportState(state, reportedRootSessionID);'
  '';
  toml = pkgs.formats.toml { };

  herdrProject = pkgs.writeShellApplication {
    name = "herdr-project";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fd
      pkgs.fzf
      pkgs.git
      herdr
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      projects_directory=${lib.escapeShellArg projectsDirectory}
      runtime_directory="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      pane_is_idle() {
        local pane_id="$1"
        local process_json

        if ! process_json="$(herdr pane process-info --pane "$pane_id")"; then
          return 1
        fi
        jq -e '
          .result.process_info as $process
          | ($process.foreground_processes | length == 0)
            or (
              $process.foreground_process_group_id == $process.shell_pid
              and any($process.foreground_processes[]; .pid == $process.shell_pid)
            )
        ' <<<"$process_json" >/dev/null
      }

      wait_until_busy() {
        local pane_id="$1"

        for _ in {1..50}; do
          if ! pane_is_idle "$pane_id"; then
            return
          fi
          sleep 0.1
        done

        printf 'Pane %s did not start its command within five seconds\n' "$pane_id" >&2
        return 1
      }

      restore_editors() {
        local tabs_json panes_json tab_id pane_id

        exec 8>"$runtime_directory/herdr-restore-editors.lock"
        flock 8

        for _ in {1..100}; do
          if tabs_json="$(herdr tab list 2>/dev/null)" \
            && panes_json="$(herdr pane list 2>/dev/null)"; then
            break
          fi
          sleep 0.1
        done

        if [[ -z "''${tabs_json:-}" || -z "''${panes_json:-}" ]]; then
          return
        fi

        while IFS= read -r tab_id; do
          while IFS= read -r pane_id; do
            if [[ -n "$pane_id" ]] && pane_is_idle "$pane_id"; then
              if ! herdr pane run "$pane_id" 'nvim' >/dev/null \
                || ! wait_until_busy "$pane_id"; then
                continue
              fi
            fi
          done < <(jq -r --arg tab_id "$tab_id" \
            '.result.panes[] | select(.tab_id == $tab_id) | .pane_id' <<<"$panes_json")
        done < <(jq -r '.result.tabs[] | select(.label == "edit") | .tab_id' <<<"$tabs_json")
      }

      if [[ "''${1:-}" == "--restore-editors" ]]; then
        restore_editors
        exit
      fi

      choose_project() {
        local git_path project selected
        local -a projects=()

        while IFS= read -r -d $'\0' git_path; do
          project="$(dirname -- "$git_path")"
          projects+=("''${project#"$projects_directory"/}")
        done < <(fd --hidden --no-ignore --type directory --type file --print0 \
          --exclude .direnv \
          --exclude build \
          --exclude dist \
          --exclude node_modules \
          --exclude target \
          '^\.git$' "$projects_directory")

        if (( ''${#projects[@]} == 0 )); then
          printf 'No Git repositories found under %s\n' "$projects_directory" >&2
          return 1
        fi

        selected="$(printf '%s\n' "''${projects[@]}" | sort -u | fzf \
          --border \
          --height=100% \
          --prompt='Project > ' \
          --reverse)" || return

        realpath -- "$projects_directory/$selected"
      }

      project="''${1:-}"
      if [[ -z "$project" ]]; then
        project="$(choose_project)" || exit 0
      fi

      project="$(realpath -- "$project")"
      requested_project="$project"
      if ! project="$(git -C "$project" rev-parse --show-toplevel 2>/dev/null)"; then
        printf '%s is not inside a Git repository\n' "$requested_project" >&2
        exit 1
      fi
      project="$(realpath -- "$project")"

      exec 9>"$runtime_directory/herdr-project.lock"
      flock 9

      label="''${project#"$projects_directory"/}"
      if [[ "$label" == "$project" ]]; then
        label="$(basename -- "$project")"
      fi

      panes_json="$(herdr pane list)"
      workspace_id="$(jq -r --arg cwd "$project" \
        '[.result.panes[] | select(.cwd == $cwd) | .workspace_id][0] // empty' \
        <<<"$panes_json")"
      edit_created=false
      agent_created=false
      workspace_created=false

      if [[ -z "$workspace_id" ]]; then
        workspace_json="$(herdr workspace create --cwd "$project" --label "$label" --no-focus)"
        workspace_id="$(jq -r '.result.workspace.workspace_id' <<<"$workspace_json")"
        edit_tab_id="$(jq -r '.result.tab.tab_id' <<<"$workspace_json")"
        edit_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$workspace_json")"

        herdr tab rename "$edit_tab_id" edit >/dev/null
        herdr pane run "$edit_pane_id" 'nvim' >/dev/null
        edit_created=true
        workspace_created=true
      else
        tabs_json="$(herdr tab list --workspace "$workspace_id")"
        edit_tab_id="$(jq -r '[.result.tabs[] | select(.label == "edit") | .tab_id][0] // empty' <<<"$tabs_json")"

        if [[ -z "$edit_tab_id" ]]; then
          edit_json="$(herdr tab create --workspace "$workspace_id" --cwd "$project" --label edit --no-focus)"
          edit_tab_id="$(jq -r '.result.tab.tab_id' <<<"$edit_json")"
          edit_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$edit_json")"
          herdr pane run "$edit_pane_id" 'nvim' >/dev/null
          edit_created=true
        fi
      fi

      tabs_json="$(herdr tab list --workspace "$workspace_id")"
      agent_tab_id="$(jq -r '[.result.tabs[] | select(.label == "agent") | .tab_id][0] // empty' <<<"$tabs_json")"
      if [[ -z "$agent_tab_id" ]]; then
        agent_json="$(herdr tab create --workspace "$workspace_id" --cwd "$project" --label agent --no-focus)"
        agent_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$agent_json")"
        herdr pane run "$agent_pane_id" 'oc --auto --port' >/dev/null
        agent_created=true
      fi

      shell_tab_id="$(jq -r '[.result.tabs[] | select(.label == "shell") | .tab_id][0] // empty' <<<"$tabs_json")"
      if [[ -z "$shell_tab_id" ]]; then
        herdr tab create --workspace "$workspace_id" --cwd "$project" --label shell --no-focus >/dev/null
      fi

      run_if_idle() {
        local tab_id="$1"
        local command="$2"
        local pane_id

        pane_id="$(herdr pane list --workspace "$workspace_id" | jq -r --arg tab_id "$tab_id" \
          '[.result.panes[] | select(.tab_id == $tab_id) | .pane_id][0] // empty')"
        [[ -n "$pane_id" ]] || return

        if pane_is_idle "$pane_id"; then
          herdr pane run "$pane_id" "$command" >/dev/null
          wait_until_busy "$pane_id"
        fi
      }

      if [[ "$edit_created" == false ]]; then
        run_if_idle "$edit_tab_id" 'nvim'
      fi
      if [[ "$agent_created" == false ]]; then
        run_if_idle "$agent_tab_id" 'oc --auto --port'
      fi
      if [[ "$edit_created" == true ]]; then
        wait_until_busy "$edit_pane_id"
      fi
      if [[ "$agent_created" == true ]]; then
        wait_until_busy "$agent_pane_id"
      fi

      herdr workspace focus "$workspace_id" >/dev/null
      if [[ "$workspace_created" == true ]]; then
        herdr tab focus "$edit_tab_id" >/dev/null
      fi
    '';
  };

  herdrProc = pkgs.writeShellApplication {
    name = "herdr-proc";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      herdr
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      usage() {
        cat <<'EOF'
      Manage long-running processes in the tabs of the current Herdr workspace.

      Usage:
        herdr-proc list
        herdr-proc start <name> [--cwd PATH] [--] <command...>
        herdr-proc logs <target> [--lines N]
        herdr-proc stop <target>
        herdr-proc restart <target> [--] [command...]
        herdr-proc close <target>

      <target> is a tab label or a pane id from `herdr-proc list`.
      A single command argument is a raw shell line ('A=1 npm run dev | tee log');
      several arguments are quoted as an argv (-- npm run dev).
      restart without a command reruns the one recorded by start/restart.
      Agent panes, panes running opencode, and the caller's own pane are protected.
      EOF
      }

      fail() {
        printf 'herdr-proc: %s\n' "$*" >&2
        exit 1
      }

      workspace_id="''${HERDR_WORKSPACE_ID:-}"
      [[ -n "$workspace_id" ]] || fail "HERDR_WORKSPACE_ID is not set; run inside a Herdr pane"

      state_directory="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/herdr-proc"

      # Prints {state, command} for a pane as compact JSON, where state is
      # protected, idle, or running. Callers must check the exit status: set -e
      # does not apply inside `if` conditions.
      describe_pane() {
        local pane_id="$1"
        local agent_status process_json

        agent_status="$(herdr pane list --workspace "$workspace_id" | jq -er --arg pane_id "$pane_id" \
          '.result.panes[] | select(.pane_id == $pane_id) | .agent_status')" || return 1
        process_json="$(herdr pane process-info --pane "$pane_id")" || return 1
        jq -ce --arg pane_id "$pane_id" --arg self "''${HERDR_PANE_ID:-}" \
          --arg agent_status "$agent_status" '
          .result.process_info as $process
          | $process.foreground_processes as $foreground
          | ($foreground | map(select(.pid == $process.foreground_process_group_id))[0]) as $leader
          | {
              state: (
                if $pane_id == $self
                  or $agent_status != "unknown"
                  or ($foreground | length == 0)
                  or any($foreground[];
                    ((.name // "") + " " + ((.argv // []) | join(" "))) | test("opencode"))
                then "protected"
                elif $process.foreground_process_group_id == $process.shell_pid
                  and any($foreground[]; .pid == $process.shell_pid)
                then "idle"
                else "running"
                end
              ),
              command: (
                if $leader == null or $process.foreground_process_group_id == $process.shell_pid
                then ""
                else ($leader.argv // []) | join(" ")
                end
              )
            }
        ' <<<"$process_json"
      }

      pane_state() {
        local pane_id="$1"
        local description

        description="$(describe_pane "$pane_id")" || return 1
        jq -r '.state' <<<"$description"
      }

      panes_json() {
        herdr pane list --workspace "$workspace_id"
      }

      tabs_json() {
        herdr tab list --workspace "$workspace_id"
      }

      # Resolves a pane id or a tab label to a single pane id.
      resolve_pane() {
        local target="$1"
        local panes tabs tab_id pane_count

        panes="$(panes_json)"
        if jq -e --arg target "$target" 'any(.result.panes[]; .pane_id == $target)' \
          <<<"$panes" >/dev/null; then
          printf '%s\n' "$target"
          return
        fi

        tabs="$(tabs_json)"
        tab_id="$(jq -r --arg target "$target" \
          '[.result.tabs[] | select(.label == $target) | .tab_id] | if length == 1 then .[0] else "" end' \
          <<<"$tabs")"
        if [[ -z "$tab_id" ]]; then
          if jq -e --arg target "$target" 'any(.result.tabs[]; .label == $target)' \
            <<<"$tabs" >/dev/null; then
            fail "several tabs are labelled '$target'; use a pane id"
          fi
          fail "no tab or pane '$target' in workspace $workspace_id"
        fi

        pane_count="$(jq --arg tab_id "$tab_id" \
          '[.result.panes[] | select(.tab_id == $tab_id)] | length' <<<"$panes")"
        if (( pane_count != 1 )); then
          fail "tab '$target' has $pane_count panes; use a pane id"
        fi
        jq -r --arg tab_id "$tab_id" \
          '.result.panes[] | select(.tab_id == $tab_id) | .pane_id' <<<"$panes"
      }

      # Prints the pane state, exiting when it is protected or cannot be inspected.
      require_unprotected() {
        local pane_id="$1"
        local state

        state="$(pane_state "$pane_id")" || fail "cannot inspect pane $pane_id"
        if [[ "$state" == protected ]]; then
          fail "pane $pane_id is protected (agent, opencode, or caller pane)"
        fi
        printf '%s\n' "$state"
      }

      wait_for_state() {
        local pane_id="$1"
        local wanted="$2"
        local tenths="$3"
        local state

        for (( i = 0; i < tenths; i++ )); do
          state="$(pane_state "$pane_id")" || fail "cannot inspect pane $pane_id"
          if [[ "$state" == "$wanted" ]]; then
            return
          fi
          sleep 0.1
        done
        return 1
      }

      command_file() {
        printf '%s/%s\n' "$state_directory" "$1"
      }

      # Herdr counts the blank screen rows below the cursor in --lines and caps reads at 1000.
      read_output() {
        local pane_id="$1"
        local lines="$2"

        herdr pane read "$pane_id" --source recent --lines 1000 \
          | tac | sed '/[^[:space:]]/,$!d' | tac | tail -n "$lines"
      }

      # A single argument is a raw shell command line; several arguments are an argv to quote.
      command_line() {
        if (( $# == 1 )); then
          printf '%s' "$1"
        else
          printf '%q ' "$@"
        fi
      }

      run_in_pane() {
        local pane_id="$1"
        local command="$2"

        local state

        mkdir -p "$state_directory"
        printf '%s\n' "$command" >"$(command_file "$pane_id")"
        herdr pane run "$pane_id" "$command" >/dev/null
        for _ in {1..50}; do
          state="$(pane_state "$pane_id")" || fail "cannot inspect pane $pane_id"
          if [[ "$state" != idle ]]; then
            printf 'Running in pane %s: %s\n' "$pane_id" "$command"
            return
          fi
          sleep 0.1
        done

        printf 'herdr-proc: command exited or did not start in pane %s; recent output:\n' \
          "$pane_id" >&2
        read_output "$pane_id" 30 >&2
        exit 1
      }

      stop_pane() {
        local pane_id="$1"
        local state

        state="$(require_unprotected "$pane_id")" || exit 1
        if [[ "$state" == idle ]]; then
          printf 'Pane %s is already idle\n' "$pane_id"
          return
        fi

        herdr pane send-keys "$pane_id" ctrl+c >/dev/null
        if ! wait_for_state "$pane_id" idle 100; then
          herdr pane send-keys "$pane_id" ctrl+c >/dev/null
          wait_for_state "$pane_id" idle 50 \
            || fail "pane $pane_id is still busy after two Ctrl-C"
        fi
        printf 'Stopped pane %s\n' "$pane_id"
      }

      cmd_list() {
        local panes tabs pane_id tab_label description state command

        panes="$(panes_json)"
        tabs="$(tabs_json)"
        printf '%-10s %-16s %-10s %s\n' PANE TAB STATE COMMAND
        while IFS=$'\t' read -r pane_id tab_label; do
          if description="$(describe_pane "$pane_id")"; then
            state="$(jq -r '.state' <<<"$description")"
            command="$(jq -r '.command' <<<"$description")"
          else
            state=unknown
            command=""
          fi
          printf '%-10s %-16s %-10s %s\n' "$pane_id" "$tab_label" "$state" "$command"
        done < <(jq -r --argjson tabs "$tabs" '
          ($tabs.result.tabs | map({key: .tab_id, value: .label}) | from_entries) as $labels
          | .result.panes[]
          | [.pane_id, ($labels[.tab_id] // "?")]
          | @tsv
        ' <<<"$panes")
      }

      cmd_start() {
        (( $# >= 1 )) || fail "start needs a name"
        local name="$1"
        local cwd="$PWD"
        local pane_id tab_json
        shift

        while (( $# > 0 )); do
          case "$1" in
            --cwd)
              (( $# >= 2 )) || fail "--cwd needs a path"
              cwd="$2"
              shift 2
              ;;
            --) shift; break ;;
            *) break ;;
          esac
        done
        (( $# >= 1 )) || fail "start needs a command"
        [[ -d "$cwd" ]] || fail "directory $cwd does not exist"
        cwd="$(realpath -- "$cwd")"
        local command
        command="$(command_line "$@")"

        if jq -e --arg name "$name" 'any(.result.tabs[]; .label == $name)' \
          <<<"$(tabs_json)" >/dev/null; then
          fail "tab '$name' already exists; use 'herdr-proc restart $name -- <command>'"
        fi

        tab_json="$(herdr tab create --workspace "$workspace_id" --cwd "$cwd" \
          --label "$name" --no-focus)"
        pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$tab_json")"
        run_in_pane "$pane_id" "$command"
      }

      cmd_logs() {
        (( $# >= 1 )) || fail "logs needs a target"
        local pane_id lines=200
        pane_id="$(resolve_pane "$1")"
        shift

        while (( $# > 0 )); do
          case "$1" in
            --lines)
              lines="''${2:-}"
              [[ "$lines" =~ ^[0-9]+$ ]] || fail "--lines needs a number"
              shift 2
              ;;
            *) fail "unknown logs option: $1" ;;
          esac
        done

        read_output "$pane_id" "$lines"
      }

      cmd_stop() {
        (( $# == 1 )) || fail "stop needs exactly one target"
        local pane_id
        pane_id="$(resolve_pane "$1")"
        stop_pane "$pane_id"
      }

      cmd_restart() {
        (( $# >= 1 )) || fail "restart needs a target"
        local pane_id command
        pane_id="$(resolve_pane "$1")"
        shift
        if [[ "''${1:-}" == "--" ]]; then
          shift
        fi
        require_unprotected "$pane_id" >/dev/null

        if (( $# > 0 )); then
          command="$(command_line "$@")"
        elif [[ -f "$(command_file "$pane_id")" ]]; then
          command="$(<"$(command_file "$pane_id")")"
        else
          fail "no command recorded for pane $pane_id; pass it explicitly (see herdr-proc list)"
        fi

        stop_pane "$pane_id"
        run_in_pane "$pane_id" "$command"
      }

      cmd_close() {
        (( $# == 1 )) || fail "close needs exactly one target"
        local pane_id tab_id
        pane_id="$(resolve_pane "$1")"
        stop_pane "$pane_id"
        rm -f -- "$(command_file "$pane_id")"

        tab_id="$(jq -r --arg pane_id "$pane_id" \
          '.result.panes[] | select(.pane_id == $pane_id) | .tab_id' <<<"$(panes_json)")"
        if jq -e --arg tab_id "$tab_id" \
          '[.result.panes[] | select(.tab_id == $tab_id)] | length == 1' \
          <<<"$(panes_json)" >/dev/null; then
          herdr tab close "$tab_id" >/dev/null
          printf 'Closed tab %s\n' "$tab_id"
        else
          herdr pane close "$pane_id" >/dev/null
          printf 'Closed pane %s\n' "$pane_id"
        fi
      }

      subcommand="''${1:-}"
      (( $# > 0 )) && shift
      case "$subcommand" in
        list) cmd_list "$@" ;;
        start) cmd_start "$@" ;;
        logs) cmd_logs "$@" ;;
        stop) cmd_stop "$@" ;;
        restart) cmd_restart "$@" ;;
        close) cmd_close "$@" ;;
        -h|--help|help) usage ;;
        *) usage >&2; exit 1 ;;
      esac
    '';
  };

  checkpointHerdrEditors = pkgs.writeShellApplication {
    name = "checkpoint-herdr-editors";
    runtimeInputs = [
      pkgs.coreutils
      herdr
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      if ! tabs_json="$(herdr tab list 2>/dev/null)" \
        || ! panes_json="$(herdr pane list 2>/dev/null)"; then
        exit 0
      fi

      checkpoint_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/herdr-nvim-checkpoints"
      mkdir -p "$checkpoint_dir"
      declare -a checkpoint_files=()

      while IFS= read -r tab_id; do
        while IFS= read -r pane_id; do
          [[ -n "$pane_id" ]] || continue

          if ! process_json="$(herdr pane process-info --pane "$pane_id" 2>/dev/null)"; then
            continue
          fi
          nvim_pid="$(jq -r '
            [.result.process_info.foreground_processes[]
              | select(.name == "nvim")
              | select((.argv | index("--embed")) == null)
              | .pid][0] // empty
          ' <<<"$process_json")"
          [[ -n "$nvim_pid" ]] || continue

          checkpoint_file="$checkpoint_dir/$nvim_pid"
          rm -f -- "$checkpoint_file"
          if kill -USR1 "$nvim_pid" 2>/dev/null; then
            checkpoint_files+=("$checkpoint_file")
          fi
        done < <(jq -r --arg tab_id "$tab_id" \
          '.result.panes[] | select(.tab_id == $tab_id) | .pane_id' <<<"$panes_json")
      done < <(jq -r '.result.tabs[] | select(.label == "edit") | .tab_id' <<<"$tabs_json")

      (( ''${#checkpoint_files[@]} > 0 )) || exit 0

      for _ in {1..50}; do
        pending=0
        for checkpoint_file in "''${checkpoint_files[@]}"; do
          [[ -e "$checkpoint_file" ]] || pending=1
        done
        (( pending )) || break
        sleep 0.1
      done

      if (( pending )); then
        printf 'Timed out waiting for one or more Neovim session checkpoints\n' >&2
      fi
      rm -f -- "''${checkpoint_files[@]}"
    '';
  };

  launchHerdr = pkgs.writeShellApplication {
    name = "launch-herdr";
    runtimeInputs = [
      herdr
      pkgs.hyprland
      pkgs.jq
      pkgs.kitty
    ];
    text = ''
      if hyprctl clients -j | jq -e 'any(.[]; .class == "herdr")' >/dev/null; then
        exec hyprctl dispatch focuswindow 'class:^(herdr)$'
      fi

      if ! herdr pane list >/dev/null 2>&1; then
        ${lib.getExe herdrProject} --restore-editors &
      fi
      exec kitty \
        --override 'map=ctrl+shift+right' \
        --override 'map=ctrl+tab' \
        --override 'map=ctrl+shift+left' \
        --override 'map=ctrl+shift+tab' \
        --override 'map=ctrl+shift+t' \
        --override 'map=ctrl+shift+q' \
        --override 'map=ctrl+shift+.' \
        --override 'map=ctrl+shift+,' \
        --override 'map=ctrl+shift+alt+t' \
        --override 'map=ctrl+,' \
        --override 'map=ctrl+;' \
        --override 'map=ctrl+shift+;' \
        --class herdr \
        --title Herdr \
        --directory ${lib.escapeShellArg projectsDirectory} \
        herdr
    '';
  };

in
{
  options.modules.desktop.herdr = {
    enable = lib.my.mkBoolOpt false;
    commands = {
      launch = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = lib.getExe launchHerdr;
        description = "Launch or focus the shared Herdr session.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.checkpoint-herdr-editors = lib.mkIf config.modules.editor.vim.enable {
      description = "Checkpoint Herdr Neovim sessions before shutdown";
      wantedBy = [ "multi-user.target" ];
      after = [
        "display-manager.service"
        "systemd-user-sessions.service"
      ];
      restartIfChanged = false;
      environment = {
        HOME = homeDirectory;
        XDG_CONFIG_HOME = "${homeDirectory}/.config";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = user;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = lib.getExe checkpointHerdrEditors;
        TimeoutStopSec = "8s";
      };
    };

    home-manager.users.${user} = {
      home.packages = [
        herdr
        herdrProc
        herdrProject
        launchHerdr
      ];

      xdg.configFile = {
        "herdr/config.toml".source = toml.generate "herdr-config.toml" {
          onboarding = false;

          terminal = {
            default_shell = lib.getExe pkgs.zsh;
            shell_mode = "non_login";
            new_cwd = "follow";
          };

          worktrees.directory = "${projectsDirectory}/.worktrees";

          theme.name = "gruvbox";

          ui = {
            agent_panel_sort = "priority";
            prompt_new_tab_name = false;
            status_indicators = "symbols";
            window_title = "{workspace}: {tab}";
            sound.enabled = false;
            toast = {
              delivery = "system";
              delay_seconds = 1;
            };
          };

          session.resume_agents_on_restore = true;
          experimental.pane_history = false;
          update.version_check = false;

          keys = {
            prefix = "ctrl+space";
            help = "prefix+?";
            reload_config = "prefix+q";
            detach = "prefix+d";
            copy_mode = [
              "prefix+y"
              "prefix+["
            ];

            split_horizontal = "prefix+h";
            split_vertical = "prefix+v";
            close_pane = "prefix+x";
            zoom = "prefix+z";
            last_pane = "prefix+semicolon";
            focus_pane_left = "";
            focus_pane_down = "";
            focus_pane_up = "";
            focus_pane_right = "";
            swap_pane_left = "";
            swap_pane_down = "";
            swap_pane_up = "";
            swap_pane_right = "";
            resize_mode = "";
            resize_pane_left = "";
            resize_pane_down = "";
            resize_pane_up = "";
            resize_pane_right = "";
            rename_pane = "prefix+shift+o";

            new_tab = [
              "prefix+c"
              "alt+shift+t"
            ];
            rename_tab = [
              "prefix+r"
              "alt+shift+r"
            ];
            close_tab = [
              "prefix+k"
              "alt+shift+x"
            ];
            switch_tab = "prefix+1..9";
            previous_tab = [
              "prefix+p"
              "alt+h"
            ];
            next_tab = [
              "prefix+n"
              "alt+l"
            ];
            move_tab_previous = "alt+shift+h";
            move_tab_next = "alt+shift+l";

            new_workspace = "prefix+shift+c";
            rename_workspace = "prefix+shift+r";
            close_workspace = "prefix+shift+k";
            previous_workspace = [
              "prefix+shift+p"
              "alt+k"
            ];
            next_workspace = [
              "prefix+shift+n"
              "alt+j"
            ];
            workspace_picker = "prefix+w";
            goto = "prefix+g";
            new_worktree = "prefix+shift+g";

            previous_agent = [
              "prefix+alt+p"
              "alt+shift+k"
            ];
            next_agent = [
              "prefix+alt+n"
              "alt+shift+j"
            ];

            command = [
              {
                key = "prefix+f";
                type = "popup";
                command = lib.getExe herdrProject;
                description = "find or open project";
                width = "80%";
                height = "80%";
              }
            ];
          };
        };

        "opencode/plugins/herdr-agent-state.js".source = herdrAgentState;
        "opencode/skills/herdr-processes/SKILL.md".source = ../ai/skills/herdr-processes/SKILL.md;
        "opencode/herdr-tui-session.js".source =
          "${inputs.herdr}/src/integration/assets/opencode/herdr-tui-session.js";
        "opencode/tui.jsonc".text = builtins.toJSON {
          plugin = [ "./herdr-tui-session.js" ];
        };
      };
    };
  };
}
