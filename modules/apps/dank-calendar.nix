{
  inputs,
  config,
  lib,
  ...
}:

let
  cfg = config.modules.apps.dank-calendar;
in
{
  options.modules.apps.dank-calendar = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} =
      { config, pkgs, ... }:
      let
        palette = import ../desktop/themes/_palette.nix;
        themeFile = pkgs.writeText "dank-calendar-gruvbox-theme.json" (
          builtins.toJSON {
            primary = palette.semantic.accent;
            primaryText = palette.hex.bg0Hard;
            primaryContainer = palette.hex.orangeDark;
            secondary = palette.semantic.accent;
            surface = palette.semantic.bg;
            surfaceText = palette.semantic.fg;
            surfaceVariant = palette.semantic.bgAlt;
            surfaceVariantText = palette.hex.fg2;
            surfaceTint = palette.semantic.accent;
            background = palette.semantic.bgStrong;
            backgroundText = palette.semantic.fg;
            outline = palette.hex.bg3;
            surfaceContainer = palette.hex.bg0Soft;
            surfaceContainerHigh = palette.hex.bg1;
            surfaceContainerHighest = palette.hex.bg2;
            error = palette.semantic.critical;
            warning = palette.semantic.warning;
            info = palette.semantic.info;
            success = palette.semantic.success;
          }
        );
        # The GUI owns this file; only theme selection is managed declaratively.
        settingsSync = pkgs.writeShellApplication {
          name = "dank-calendar-sync-theme-settings";
          runtimeInputs = with pkgs; [
            coreutils
            jq
          ];
          text = ''
            umask 077

            config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
            config_dir="$config_home/dankcal"
            settings_file="$config_dir/ui-settings.json"
            theme_file="''${1:-$config_dir/gruvbox-theme.json}"

            if [[ "$theme_file" != /* ]]; then
              printf 'dank-calendar theme settings: custom theme path must be absolute: %s\n' "$theme_file" >&2
              exit 1
            fi

            mkdir -p "$config_dir"
            temporary_file="$(mktemp "$config_dir/.ui-settings.json.tmp.XXXXXX")"
            trap 'rm -f "$temporary_file"' EXIT

            if ! {
              if [[ -e "$settings_file" ]]; then
                cat "$settings_file"
              else
                printf '{}\n'
              fi
            } | jq --slurp --arg theme_file "$theme_file" '
              if length == 1 and (.[0] | type == "object") then
                .[0] + {
                  themeMode: "dark",
                  colorSource: "custom",
                  customThemeFile: $theme_file
                }
              else
                error("ui-settings.json must contain a JSON object")
              end
            ' > "$temporary_file"; then
              printf 'dank-calendar theme settings: %s is malformed or is not a JSON object\n' "$settings_file" >&2
              exit 1
            fi

            mv "$temporary_file" "$settings_file"
            trap - EXIT
          '';
        };
        installedThemeFile = "${config.xdg.configHome}/dankcal/gruvbox-theme.json";
      in
      {
        imports = [ inputs.dankcalendar.homeModules.dank-calendar ];

        xdg.configFile."dankcal/gruvbox-theme.json".source = themeFile;

        programs.dank-calendar = {
          enable = true;
          systemd = {
            enable = true;
            target = "hyprland-session.target";
          };
          quickshell = lib.mkIf config.programs.quickshell.enable {
            package = config.programs.quickshell.package;
          };
        };

        systemd.user.services.dcal = {
          Service.ExecStartPre = lib.mkBefore [
            "${lib.getExe settingsSync} ${lib.escapeShellArg installedThemeFile}"
          ];
          Unit.X-Restart-Triggers = [ themeFile ];
        };
      };
  };
}
