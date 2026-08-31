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
  panelCommandNames = [
    "audio-input-set-default"
    "audio-output-set-default"
    "audio-output-sink"
    "audio-sink-availability"
    "battery-low"
    "battery-status"
    "bluetooth-device"
    "bluetooth-power"
    "brightness-display"
    "display-text-size"
    "hyprland-monitor-scaling"
    "monitor-state"
    "network-band"
    "network-password"
    "network-qr"
    "network-speedtest"
    "network-status"
    "notification-send"
    "powerprofiles-list"
    "powerprofiles-set"
    "system-stats"
    "weather-location"
    "weather-status"
  ];
  panelOldCommandNames = map (name: "omarchy-${name}") panelCommandNames;
  panelNewCommandNames = map (name: "fos-internal-${name}") panelCommandNames;
  panelTools = import ../../../packages/quickshell-panel-tools/package.nix { inherit inputs pkgs; };
  fosCommandPresent = pkgs.writeShellApplication {
    name = "fos-internal-cmd-present";
    bashOptions = [ ];
    text = builtins.readFile "${inputs.omarchy}/bin/omarchy-cmd-present";
  };
  fosShellSource =
    builtins.replaceStrings
      [
        ''qs ipc -n -p "$OMARCHY_PATH/shell" call''
        "omarchy-shell"
      ]
      [
        "qs ipc -n -c desktop call"
        "fos-internal-shell"
      ]
      (builtins.readFile "${inputs.omarchy}/bin/omarchy-shell");
  fosShell = pkgs.writeShellApplication {
    name = "fos-internal-shell";
    bashOptions = [ ];
    excludeShellChecks = [ "SC2010" ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      quickshellPackage
    ];
    text = ''
      export OMARCHY_PATH=${lib.escapeShellArg (toString quickshellConfig)}
      ${fosShellSource}
    '';
  };
  fosMenuSelect = pkgs.writeShellApplication {
    name = "fos-internal-menu-select";
    bashOptions = [ ];
    runtimeInputs = [
      fosShell
      pkgs.coreutils
      pkgs.perl
    ];
    text = builtins.replaceStrings [ "omarchy-shell" ] [ "fos-internal-shell" ] (
      builtins.readFile "${inputs.omarchy}/bin/omarchy-menu-select"
    );
  };
  publicEnvironment = pkgs.writeShellScriptBin "fos-internal-public-environment" ''
    clean_path=""
    IFS=: read -ra entries <<< "$PATH"
    for entry in "''${entries[@]}"; do
      [[ -n $entry ]] || continue
      case "$entry" in
        *-fos-internal-*/bin | *-quickshell-desktop-config/bin | *-quickshell-panel-tools/bin) continue ;;
      esac
      clean_path+="''${clean_path:+:}$entry"
    done
    export PATH="$clean_path"
    exec ${lib.getExe' pkgs.coreutils "env"} "$@"
  '';
  menuTerminal = pkgs.writeShellApplication {
    name = "fos-internal-menu-terminal";
    text = ''
      (($# > 0)) || {
        echo "usage: fos-internal-menu-terminal COMMAND [ARGUMENT...]" >&2
        exit 2
      }
      exec ${lib.getExe publicEnvironment} ${config.modules.applications.commands.terminal} \
        --hold -e ${lib.getExe pkgs.fos} "$@"
    '';
  };
  keybindingsMenu =
    pkgs.runCommandLocal "fos-internal-menu-keybindings"
      {
        nativeBuildInputs = [
          pkgs.makeWrapper
          pkgs.patch
        ];
        meta.mainProgram = "fos-internal-menu-keybindings";
      }
      ''
        mkdir -p "$out/bin"
        cp ${inputs.omarchy}/bin/omarchy-menu-keybindings "$out/bin/fos-internal-menu-keybindings"
        patch -d "$out" -p1 < ${./omarchy/keybindings-menu.patch}
        patchShebangs "$out/bin"
        substituteInPlace "$out/bin/fos-internal-menu-keybindings" \
          --replace-fail omarchy-cmd-present fos-internal-cmd-present \
          --replace-fail omarchy-menu-select fos-internal-menu-select
        wrapProgram "$out/bin/fos-internal-menu-keybindings" \
          --prefix PATH : ${
            lib.makeBinPath [
              fosCommandPresent
              fosMenuSelect
              pkgs.coreutils
              pkgs.findutils
              pkgs.gawk
              pkgs.gnugrep
              pkgs.hyprland
              pkgs.jq
              pkgs.lua5_1
              pkgs.libxkbcommon
            ]
          }

        KEYBINDINGS_MENU_BIN="$out/bin/fos-internal-menu-keybindings" \
          ${pkgs.bash}/bin/bash ${./tests/keybindings-menu.test.sh}
      '';
  shellRuntimePath = lib.makeBinPath ([
    quickshellConfig
    panelTools
    fosCommandPresent
    fosShell
    fosMenuSelect
    publicEnvironment
    menuTerminal
    keybindingsMenu
    pkgs.bash
    pkgs.codex
    pkgs.coreutils
    pkgs.curl
    pkgs.findutils
    pkgs.fos
    pkgs.fontconfig
    pkgs.gawk
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
          pkgs.jq
          pkgs.patch
          pkgs.python3
        ];
      }
      ''
        mkdir -p "$out"
        cp -R ${inputs.omarchy}/shell "$out/shell"
        chmod -R u+w "$out/shell"
        patch -d "$out" -p1 < ${./omarchy/omarchy-nixos.patch}
        patch -d "$out" -p1 < ${./omarchy/fos-command-menu.patch}

        cp ${./config/Clipboard.qml} "$out/shell/Clipboard.qml"
        cp ${./config/ClipboardHistory.js} "$out/shell/ClipboardHistory.js"

        mkdir -p "$out/shell/plugins/panels/nextcloud"
        cp -R ${./omarchy/plugins/nextcloud}/. "$out/shell/plugins/panels/nextcloud/"

        python3 - "$out/shell" <<'PYTHON'
        import os
        import pathlib
        import sys

        root = pathlib.Path(sys.argv[1])
        replacements = {
            'root.omarchyPath + "/bin/omarchy-notification-send"': '"fos-internal-notification-send"',
            "omarchy-cmd-present": "fos-internal-cmd-present",
            "omarchy-shell": "fos-internal-shell",
            "omarchy-menu-select": "fos-internal-menu-select",
            "omarchy-menu-keybindings": "fos-internal-menu-keybindings",
            "omarchy-agent-usage-update": "fos-internal-agent-usage-update",
            "omarchy-agent-usage-claude": "fos-internal-agent-usage-claude",
            "omarchy-agent-usage-codex": "fos-internal-agent-usage-codex",
            "omarchy-agent-usage-fireworks": "fos-internal-agent-usage-fireworks",
            "omarchy-hyprland-focus-app": "fos-internal-hyprland-focus-app",
            "uwsm-app -- gtk-launch": "fos-internal-public-environment uwsm-app -- gtk-launch",
        }
        replacements.update({
            old: new
            for old, new in zip(
                ${builtins.toJSON panelOldCommandNames},
                ${builtins.toJSON panelNewCommandNames},
            )
        })

        for directory, directory_names, file_names in os.walk(root):
            directory_names.sort()
            for file_name in sorted(file_names):
                path = pathlib.Path(directory, file_name)
                if path.suffix not in {".js", ".qml"}:
                    continue
                try:
                    text = path.read_text()
                except UnicodeDecodeError:
                    continue
                rewritten = text
                for old, new in replacements.items():
                    rewritten = rewritten.replace(old, new)
                if rewritten != text:
                    path.write_text(rewritten)

        for path in sorted(root.rglob("*")):
            if not path.is_file() or path.suffix not in {".js", ".qml"}:
                continue
            text = path.read_text()
            for old in replacements:
                if old == "uwsm-app -- gtk-launch":
                    continue
                if old in text:
                    raise SystemExit(f"unreplaced private command {old!r} in {path}")

        app_library = (root / "services" / "AppLibrary.qml").read_text()
        if "fos-internal-public-environment uwsm-app -- gtk-launch" not in app_library:
            raise SystemExit("application launcher does not sanitize its environment")

        for path in root.rglob("*.orig"):
            path.unlink()
        PYTHON

        mkdir -p "$out/config/omarchy" "$out/default/omarchy" "$out/theme" "$out/share/licenses/omarchy"
        cp ${./omarchy/shell.json} "$out/config/omarchy/shell.json"
        cp ${./config/FosMenu.jsonc} "$out/default/omarchy/omarchy-menu.jsonc"
        cp ${./omarchy/colors.toml} "$out/theme/colors.toml"
        cp ${./omarchy/shell.toml} "$out/theme/shell.toml"
        cp ${inputs.omarchy}/LICENSE "$out/share/licenses/omarchy/LICENSE"

        mkdir -p "$out/bin"
        for command in update claude codex fireworks; do
          install -Dm755 \
            ${inputs.omarchy}/bin/omarchy-agent-usage-$command \
            "$out/bin/fos-internal-agent-usage-$command"
        done
        install -Dm755 \
          ${inputs.omarchy}/bin/omarchy-hyprland-focus-app \
          "$out/bin/fos-internal-hyprland-focus-app"
        python3 - "$out/bin" <<'PYTHON'
        import pathlib
        import sys

        for path in sorted(pathlib.Path(sys.argv[1]).iterdir()):
            text = path.read_text()
            text = text.replace("omarchy-agent-usage-", "fos-internal-agent-usage-")
            text = text.replace("omarchy-hyprland-focus-app", "fos-internal-hyprland-focus-app")
            path.write_text(text)
        PYTHON
        patchShebangs "$out/bin"

        QUICKSHELL_MODULE_ROOT=${./.} \
          ${pkgs.bash}/bin/bash ${./tests/notification-tools.test.sh}
        ${lib.getExe pkgs.fos} commands --json > fos-commands.json
        ${lib.getExe pkgs.python3} ${./tests/command-menu.test.py} \
          "$out/default/omarchy/omarchy-menu.jsonc" fos-commands.json "$out/shell"
      '';
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
  shellConfigSync = pkgs.writeShellApplication {
    name = "quickshell-sync-shell-config";
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = builtins.readFile ./scripts/sync-shell-config.sh;
  };
in
{
  options.modules.apps.quickshell = {
    enable = lib.my.mkBoolOpt false;
    commands.keybindings = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lib.getExe keybindingsMenu;
      description = "Open the searchable Hyprland keybinding catalog.";
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = [
      pkgs.liberation_ttf
      omarchyFont
      pkgs.nerd-fonts.jetbrains-mono
    ];

    home-manager.users.${config.user.name} = {
      home.file.".local/share/fos/bin/menu-keybindings".source = lib.getExe keybindingsMenu;

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
        "NEXTCLOUD_OPEN=${lib.getExe pkgs.nextcloud-client}"
        "NEXTCLOUD_OPEN_FOLDER=${lib.getExe' pkgs.xdg-utils "xdg-open"}"
        "NEXTCLOUD_STATUS=${lib.getExe' panelTools "nextcloud-status"}"
        "OMARCHY_PATH=${quickshellConfig}"
        "QUICKSHELL_THEME_PATH=${quickshellConfig}/theme"
      ];
      systemd.user.services.quickshell.Service.ExecStartPre = "-${lib.getExe shellConfigSync}";
      systemd.user.services.quickshell.Service.UMask = "0077";
      systemd.user.services.quickshell.Unit.X-Restart-Triggers = [ quickshellConfig ];
    };
  };
}
