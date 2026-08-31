{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.apps.quickshell;
  quickshellPackage = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
  panelTools = import ./_omarchy-tools.nix { inherit pkgs; };
  shellRuntimePath = lib.makeBinPath ([
    quickshellConfig
    panelTools
    pkgs.bash
    pkgs.codex
    pkgs.coreutils
    pkgs.curl
    pkgs.findutils
    pkgs.fontconfig
    pkgs.hyprland
    pkgs.inotify-tools
    pkgs.jq
    pkgs.networkmanager
    pkgs.python3
    pkgs.ripgrep
    pkgs.util-linux
    pkgs.wl-clipboard
  ]);
  wrappedQuickshell = pkgs.symlinkJoin {
    name = "quickshell-${quickshellPackage.version}-desktop";
    paths = [ quickshellPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "quickshell";
    postBuild = ''
      rm "$out/bin/quickshell"
      makeWrapper ${quickshellPackage}/bin/quickshell "$out/bin/quickshell" \
        --prefix PATH : ${shellRuntimePath}
    '';
  };
  omarchyFont = pkgs.runCommandLocal "omarchy-icon-font" { } ''
    install -Dm644 ${inputs.omarchy}/default/fonts/omarchy/omarchy.ttf \
      "$out/share/fonts/truetype/omarchy.ttf"
  '';
  quickshellConfig =
    pkgs.runCommandLocal "quickshell-desktop-config"
      {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.patch
          pkgs.python3
        ];
      }
      ''
        mkdir -p "$out"
        cp -R ${inputs.omarchy}/shell "$out/shell"
        chmod -R u+w "$out/shell"
        patch -d "$out" -p1 < ${./omarchy/omarchy-nixos.patch}

        cp ${./config/Launcher.qml} "$out/shell/Launcher.qml"
        cp ${./config/Clipboard.qml} "$out/shell/Clipboard.qml"
        cp ${./config/ClipboardHistory.js} "$out/shell/ClipboardHistory.js"

        mkdir -p "$out/shell/plugins/panels/nextcloud"
        cp -R ${./omarchy/plugins/nextcloud}/. "$out/shell/plugins/panels/nextcloud/"

        mkdir -p "$out/config/omarchy" "$out/theme" "$out/share/licenses/omarchy"
        cp ${./omarchy/shell.json} "$out/config/omarchy/shell.json"
        cp ${./omarchy/colors.toml} "$out/theme/colors.toml"
        cp ${./omarchy/shell.toml} "$out/theme/shell.toml"
        cp ${inputs.omarchy}/LICENSE "$out/share/licenses/omarchy/LICENSE"

        mkdir -p "$out/bin"
        for command in update claude codex fireworks; do
          install -Dm755 \
            ${inputs.omarchy}/bin/omarchy-agent-usage-$command \
            "$out/bin/omarchy-agent-usage-$command"
        done
        patchShebangs "$out/bin"
      '';
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
  clipboardCapture = pkgs.writeShellApplication {
    name = "clipboard-capture";
    runtimeInputs = with pkgs; [
      coreutils
      file
      gnugrep
      jq
      perl
      wl-clipboard
    ];
    bashOptions = [ "pipefail" ];
    text = builtins.readFile ./scripts/clipboard-capture.sh;
  };
  clipboardAction = pkgs.writeShellApplication {
    name = "clipboard-action";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      jq
      wl-clipboard
      wtype
      xdg-utils
    ];
    text = builtins.readFile ./scripts/clipboard-action.sh;
  };
in
{
  options.modules.apps.quickshell = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = [
      omarchyFont
      pkgs.nerd-fonts.jetbrains-mono
    ];

    home-manager.users.${config.user.name} = {
      programs.quickshell = {
        enable = true;
        package = wrappedQuickshell;
        configs.desktop = "${quickshellConfig}/shell";
        activeConfig = "desktop";
        systemd = {
          enable = true;
          target = "hyprland-session.target";
        };
      };

      systemd.user.services.quickshell.Service.Environment = [
        "AGENTS_LAUNCH=${config.modules.desktop.herdr.commands.launch}"
        "CLIPBOARD_ACTION=${lib.getExe clipboardAction}"
        "CLIPBOARD_BROWSER=${config.modules.applications.commands.browser}"
        "CLIPBOARD_CAPTURE=${lib.getExe clipboardCapture}"
        "CLIPBOARD_EDITOR=${config.modules.applications.commands.editor}"
        "CLIPBOARD_PKILL=${lib.getExe' pkgs.procps "pkill"}"
        "CLIPBOARD_SETPRIV=${lib.getExe' pkgs.util-linux "setpriv"}"
        "CLIPBOARD_WL_PASTE=${lib.getExe' pkgs.wl-clipboard "wl-paste"}"
        "LAUNCHER_ENV=${lib.getExe' pkgs.coreutils "env"}"
        "LAUNCHER_ICON_INDEX=${lib.getExe launcherIconIndex}"
        "LAUNCHER_ICON_THEME=Gruvbox-Plus-Dark"
        "LAUNCHER_TERMINAL=${config.modules.applications.commands.terminal}"
        "NEXTCLOUD_OPEN=${lib.getExe pkgs.nextcloud-client}"
        "NEXTCLOUD_OPEN_FOLDER=${lib.getExe' pkgs.xdg-utils "xdg-open"}"
        "NEXTCLOUD_STATUS=${lib.getExe' panelTools "nextcloud-status"}"
        "OMARCHY_PATH=${quickshellConfig}"
        "QUICKSHELL_THEME_PATH=${quickshellConfig}/theme"
      ];
      systemd.user.services.quickshell.Service.UMask = "0077";
      systemd.user.services.quickshell.Unit.X-Restart-Triggers = [ quickshellConfig ];
    };
  };
}
