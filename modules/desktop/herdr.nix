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
              if ! herdr pane run "$pane_id" 'nvim .' >/dev/null \
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

      if [[ -z "$workspace_id" ]]; then
        workspace_json="$(herdr workspace create --cwd "$project" --label "$label" --no-focus)"
        workspace_id="$(jq -r '.result.workspace.workspace_id' <<<"$workspace_json")"
        edit_tab_id="$(jq -r '.result.tab.tab_id' <<<"$workspace_json")"
        edit_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$workspace_json")"

        herdr tab rename "$edit_tab_id" edit >/dev/null
        herdr pane run "$edit_pane_id" 'nvim .' >/dev/null
        edit_created=true
      else
        tabs_json="$(herdr tab list --workspace "$workspace_id")"
        edit_tab_id="$(jq -r '[.result.tabs[] | select(.label == "edit") | .tab_id][0] // empty' <<<"$tabs_json")"

        if [[ -z "$edit_tab_id" ]]; then
          edit_json="$(herdr tab create --workspace "$workspace_id" --cwd "$project" --label edit --no-focus)"
          edit_tab_id="$(jq -r '.result.tab.tab_id' <<<"$edit_json")"
          edit_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$edit_json")"
          herdr pane run "$edit_pane_id" 'nvim .' >/dev/null
          edit_created=true
        fi
      fi

      tabs_json="$(herdr tab list --workspace "$workspace_id")"
      agent_tab_id="$(jq -r '[.result.tabs[] | select(.label == "agent") | .tab_id][0] // empty' <<<"$tabs_json")"
      if [[ -z "$agent_tab_id" ]]; then
        agent_json="$(herdr tab create --workspace "$workspace_id" --cwd "$project" --label agent --no-focus)"
        agent_pane_id="$(jq -r '.result.root_pane.pane_id' <<<"$agent_json")"
        herdr pane run "$agent_pane_id" 'opencode --auto --port' >/dev/null
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
        run_if_idle "$edit_tab_id" 'nvim .'
      fi
      if [[ "$agent_created" == false ]]; then
        run_if_idle "$agent_tab_id" 'opencode --auto --port'
      fi
      if [[ "$edit_created" == true ]]; then
        wait_until_busy "$edit_pane_id"
      fi
      if [[ "$agent_created" == true ]]; then
        wait_until_busy "$agent_pane_id"
      fi

      herdr workspace focus "$workspace_id" >/dev/null
      herdr tab focus "$edit_tab_id" >/dev/null
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
      exec kitty --class herdr --title Herdr --directory ${lib.escapeShellArg projectsDirectory} herdr
    '';
  };

  showHerdrKeybindings = pkgs.writeShellApplication {
    name = "show-herdr-keybindings";
    runtimeInputs = [ pkgs.rofi ];
    text = ''
      selection="$({
        printf '%s\n' \
          'Ctrl+Space ?             Help' \
          'Ctrl+Space F             Find/open project' \
          'Ctrl+Space W             Workspace navigator' \
          'Ctrl+Space G             Global/agent navigator' \
          'Ctrl+Space D             Detach' \
          'Ctrl+Space Q             Reload configuration' \
          'Ctrl+Space Y / [         Copy mode' \
          'Ctrl+Space H / Alt+Enter Split horizontally' \
          'Ctrl+Space V / Alt+Shift+Enter  Split vertically' \
          'Ctrl+Space X             Close pane' \
          'Ctrl+Space Z / ;         Zoom / last pane' \
          'Ctrl+Alt+Arrow           Focus pane' \
          'Ctrl+Alt+Shift+Arrow     Resize pane' \
          'Ctrl+Space Shift+O       Rename pane' \
          'Ctrl+Space C/R/K         New/rename/close tab' \
          'Alt+Shift+T              New tab' \
          'Ctrl+Space P/N           Previous/next tab' \
          'Alt+H / Alt+L            Previous/next tab' \
          'Alt+Shift+H / Alt+Shift+L  Move tab' \
          'Ctrl+Space 1-9           Switch tab' \
          'Ctrl+Space Shift+C/R/K   New/rename/close workspace' \
          'Ctrl+Space Shift+P/N     Previous/next workspace' \
          'Alt+K / Alt+J            Previous/next workspace' \
          'Ctrl+Space Alt+P/N       Previous/next agent' \
          'Alt+Shift+K / Alt+Shift+J  Previous/next agent' \
          'Ctrl+Space Shift+G       New Git worktree'
      } | rofi -dmenu -i -no-custom -p 'Herdr shortcuts')" || true

      : "$selection"
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
      showKeybindings = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = lib.getExe showHerdrKeybindings;
        description = "Show the configured Herdr keybindings.";
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
        herdrProject
        launchHerdr
        showHerdrKeybindings
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

            split_horizontal = [
              "prefix+h"
              "alt+enter"
            ];
            split_vertical = [
              "prefix+v"
              "alt+shift+enter"
            ];
            close_pane = "prefix+x";
            zoom = "prefix+z";
            last_pane = "prefix+semicolon";
            focus_pane_left = "ctrl+alt+left";
            focus_pane_down = "ctrl+alt+down";
            focus_pane_up = "ctrl+alt+up";
            focus_pane_right = "ctrl+alt+right";
            resize_pane_left = "ctrl+alt+shift+left";
            resize_pane_down = "ctrl+alt+shift+down";
            resize_pane_up = "ctrl+alt+shift+up";
            resize_pane_right = "ctrl+alt+shift+right";
            rename_pane = "prefix+shift+o";

            new_tab = [
              "prefix+c"
              "alt+shift+t"
            ];
            rename_tab = "prefix+r";
            close_tab = "prefix+k";
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

        "opencode/plugins/herdr-agent-state.js".source =
          "${inputs.herdr}/src/integration/assets/opencode/herdr-agent-state.js";
        "opencode/herdr-tui-session.js".source =
          "${inputs.herdr}/src/integration/assets/opencode/herdr-tui-session.js";
        "opencode/tui.jsonc".text = builtins.toJSON {
          plugin = [ "./herdr-tui-session.js" ];
        };
      };
    };
  };
}
