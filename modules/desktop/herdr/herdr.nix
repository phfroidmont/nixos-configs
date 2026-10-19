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
  worktreesDirectory = "${projectsDirectory}/.worktrees";
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
      projects_directory=${lib.escapeShellArg projectsDirectory}
      ${builtins.readFile ./scripts/herdr-project.sh}
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
    text = builtins.readFile ./scripts/herdr-proc.sh;
  };

  checkpointHerdrEditors = pkgs.writeShellApplication {
    name = "checkpoint-herdr-editors";
    runtimeInputs = [
      pkgs.coreutils
      herdr
      pkgs.jq
    ];
    text = builtins.readFile ./scripts/checkpoint-herdr-editors.sh;
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
    enable = lib.mkEnableOption "Herdr";
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
      # The herdr-projects plugin writes its launcher here when its board first opens.
      home.sessionPath = [ "$HOME/.herdr-projects/data/bin" ];

      # A new task worktree's .envrc is not allowed yet, so the pane's zsh would
      # skip the dev shell and the agent started in it would inherit none.
      # Trade-off: any .envrc under this folder runs without `direnv allow`.
      programs.direnv.config.whitelist.prefix = [ worktreesDirectory ];

      xdg.configFile = {
        "herdr/config.toml".source = toml.generate "herdr-config.toml" {
          onboarding = false;

          terminal = {
            default_shell = lib.getExe pkgs.zsh;
            shell_mode = "non_login";
            new_cwd = "follow";
          };

          worktrees.directory = worktreesDirectory;

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
            # herdr-projects' rows: a task's number, title, state, and progress.
            # With these and its board key declared, its first run offers no config edits.
            sidebar = {
              agents.rows = [
                [
                  "state_icon"
                  "machine"
                  "workspace"
                  {
                    token = "tab";
                    rules = [
                      {
                        equals = "Agent";
                        hide = true;
                      }
                      {
                        starts_with = "Reviewer #";
                        hide = true;
                      }
                    ];
                  }
                ]
                [ "agent" ]
                [
                  {
                    token = "$summary";
                    dim = true;
                  }
                  "$progress"
                ]
              ];
              spaces.rows = [
                [
                  "state_icon"
                  "workspace"
                ]
                [
                  "branch"
                  "git_status"
                ]
                [
                  {
                    token = "$summary";
                    dim = true;
                  }
                  "$progress"
                ]
              ];
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
              {
                # Not alt+a: the board shows its archive with it.
                key = [
                  "prefix+a"
                  "alt+w"
                ];
                type = "plugin_action";
                command = "herdr-projects.open";
                description = "work board";
              }
              {
                key = "alt+shift+a";
                type = "plugin_action";
                command = "herdr-projects.approve-current";
                description = "approve the focused task";
              }
              {
                key = "alt+shift+d";
                type = "plugin_action";
                command = "persiyanov.reviewr.toggle";
                description = "review diff";
              }
            ];
          };
        };

        # The plugin itself is installed with `herdr plugin install persiyanov/herdr-reviewr`.
        # It opens as a tab in every new worktree space, the board's task spaces included.
        "herdr/plugins/config/persiyanov.reviewr/config.toml".source =
          toml.generate "herdr-reviewr-config.toml"
            {
              theme = "gruvbox";
              default_scope = "branch";
              toggle_placement = "tab";
              auto_open = true;
            };

        "opencode/skills/herdr-processes" = {
          source = ../../ai/skills/herdr-processes;
          recursive = true;
        };
        # Use the dependency-free implementation directly: upstream's small
        # re-export relies on a relative sibling path, unlike Nix store symlinks.
        "opencode/herdr-opencode/tui.js".source =
          "${inputs.herdr}/src/integration/assets/opencode/herdr-tui-session.js";
        "opencode/herdr-opencode/package.json".text = builtins.toJSON {
          name = "herdr-opencode";
          type = "module";
        };
        "opencode/cli.json" = {
          # The TUI can replace this symlink when saving preferences. Nix is
          # authoritative: restore the declared settings on every activation.
          force = true;
          text = builtins.toJSON {
            "$schema" = "https://opencode.ai/v2/cli.json";
            plugins = [ "./herdr-opencode" ];
            tabs.mode = "auto";
            theme.name = "gruvbox";
            # OpenTUI 0.5.12 can rebuild split diffs indefinitely after layout
            # changes, exhausting RAM (anomalyco/opentui#1543). This also applies
            # to inline tool diffs, not just the diff review screen.
            diffs.view = "unified";
          };
        };
      };

      home.file = lib.mkIf config.modules.ai.pi.enable {
        ".pi/agent/skills/herdr-processes" = {
          source = ../../ai/skills/herdr-processes;
          recursive = true;
        };
        ".pi/agent/extensions/herdr-agent-state.ts".source =
          "${inputs.herdr}/src/integration/assets/pi/herdr-agent-state.ts";
      };
    };
  };
}
