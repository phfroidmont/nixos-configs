{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.apps.quickshell;
  quickshellConfig = ./config;
  launcherIconIndex = pkgs.writeShellApplication {
    name = "launcher-icon-index";
    runtimeInputs = [ pkgs.findutils ];
    text = ''
      icon_directories=()
      IFS=: read -ra xdg_data_directories <<< "''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

      for directory in "$HOME/.icons" "$HOME/.local/share/icons"; do
        if [[ -n "''${LAUNCHER_ICON_THEME:-}" ]]; then
          icon_directories+=("$directory/$LAUNCHER_ICON_THEME")
        fi
        icon_directories+=("$directory/hicolor")
      done

      for data_directory in "''${xdg_data_directories[@]}"; do
        if [[ -n "''${LAUNCHER_ICON_THEME:-}" ]]; then
          icon_directories+=("$data_directory/icons/$LAUNCHER_ICON_THEME")
        fi
        icon_directories+=("$data_directory/icons/hicolor")
      done

      for extension in svg png; do
        for directory in "''${icon_directories[@]}"; do
          if [[ -d "$directory" ]]; then
            find -H "$directory" \
              \( -path '*/apps/*' -o -path '*/devices/*' \) \
              -name "*.$extension" -print 2>/dev/null || true
          fi
        done

        for data_directory in "''${xdg_data_directories[@]}"; do
          if [[ -d "$data_directory/pixmaps" ]]; then
            find -H "$data_directory/pixmaps" -maxdepth 1 \
              -name "*.$extension" -print 2>/dev/null || true
          fi
        done
      done
    '';
  };
in
{
  options.modules.apps.quickshell = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      programs.quickshell = {
        enable = true;
        package = pkgs.quickshell;
        configs.desktop = quickshellConfig;
        activeConfig = "desktop";
        systemd = {
          enable = true;
          target = "hyprland-session.target";
        };
      };

      systemd.user.services.quickshell.Service.Environment = [
        "LAUNCHER_ENV=${lib.getExe' pkgs.coreutils "env"}"
        "LAUNCHER_ICON_INDEX=${lib.getExe launcherIconIndex}"
        "LAUNCHER_ICON_THEME=Gruvbox-Plus-Dark"
        "LAUNCHER_TERMINAL=${config.modules.applications.commands.terminal}"
      ];
      systemd.user.services.quickshell.Unit.X-Restart-Triggers = [ "${quickshellConfig}" ];
    };
  };
}
