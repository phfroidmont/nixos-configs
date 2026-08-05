{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.applications;
  desktopEnabled = config.modules.desktop.wm.enable;
  editorEnabled = config.modules.editor.vim.enable;
  fileManagerEnabled = config.modules.desktop.file-manager.enable;
  rolesEnabled =
    desktopEnabled || editorEnabled || fileManagerEnabled || config.modules.desktop.terminal.enable;

  firefox =
    if config.modules.services.belgian-eid.enable then
      pkgs.firefox.override { pkcs11Modules = [ pkgs.eid-mw ]; }
    else
      pkgs.firefox;

  # Brave GPU acceleration triggers AMDGPU page faults on stellaris under heavy
  # Chromium workloads, causing a GPU reset and Hyprland crash.
  brave = pkgs.symlinkJoin {
    name = "brave-no-gpu-${pkgs.brave.version}";
    paths = [ pkgs.brave ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/brave"
      makeWrapper ${lib.getExe pkgs.brave} "$out/bin/brave" \
        --add-flags "--disable-gpu"

      desktopFile="$out/share/applications/brave-browser.desktop"
      rm "$desktopFile"
      cp ${pkgs.brave}/share/applications/brave-browser.desktop "$desktopFile"
      substituteInPlace "$desktopFile" \
        --replace-fail "${lib.getExe pkgs.brave}" "$out/bin/brave"
    '';
  };

  browsers = {
    firefox = {
      package = firefox;
      executable = "${firefox}/bin/firefox";
      desktopId = "firefox.desktop";
    };
    brave = {
      package = brave;
      executable = "${brave}/bin/brave";
      desktopId = "brave-browser.desktop";
    };
  };
  terminals.kitty = {
    executable = lib.getExe pkgs.kitty;
  };
  editors.neovim = {
    executable =
      if editorEnabled then
        lib.getExe config.home-manager.users.${config.user.name}.programs.neovim.finalPackage
      else
        lib.getExe pkgs.neovim;
  };
  fileManagers.yazi = {
    executable = lib.getExe pkgs.yazi;
  };

  browser = browsers.${cfg.browser};
  terminal = terminals.${cfg.terminal};
  editor = editors.${cfg.editor};
  fileManager = fileManagers.${cfg.fileManager};

  launchBrowser = pkgs.writeShellScriptBin "launch-browser" ''
    exec ${browser.executable} "$@"
  '';
  launchTerminal = pkgs.writeShellScriptBin "launch-terminal" ''
    exec ${terminal.executable} "$@"
  '';
  launchEditor = pkgs.writeShellScriptBin "launch-editor" ''
    exec ${terminal.executable} -e ${editor.executable} "$@"
  '';
  launchFileManager = pkgs.writeShellScriptBin "launch-file-manager" ''
    exec ${terminal.executable} -e ${fileManager.executable} "$@"
  '';

  commands = {
    browser = lib.getExe launchBrowser;
    terminal = lib.getExe launchTerminal;
    editor = lib.getExe launchEditor;
    editorInline = editor.executable;
    fileManager = lib.getExe launchFileManager;
  };
in
{
  options.modules.applications = {
    browser = lib.mkOption {
      type = lib.types.enum [
        "firefox"
        "brave"
      ];
      default = "firefox";
      description = "Application used for web links and browser launches.";
    };
    terminal = lib.mkOption {
      type = lib.types.enum [ "kitty" ];
      default = "kitty";
      description = "Application used for terminal launches.";
    };
    editor = lib.mkOption {
      type = lib.types.enum [ "neovim" ];
      default = "neovim";
      description = "Application used for text editing.";
    };
    fileManager = lib.mkOption {
      type = lib.types.enum [ "yazi" ];
      default = "yazi";
      description = "Application used for directory browsing.";
    };
    commands = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Resolved launch commands for application-role consumers.";
    };
  };

  config = lib.mkMerge [
    {
      modules.applications.commands = commands;
    }

    (lib.mkIf rolesEnabled {
      home-manager.users.${config.user.name} = {
        home.packages = [
          launchTerminal
        ]
        ++ lib.optionals desktopEnabled [
          browser.package
          launchBrowser
        ]
        ++ lib.optionals editorEnabled [ launchEditor ]
        ++ lib.optionals fileManagerEnabled [ launchFileManager ];

        home.sessionVariables = {
          TERMINAL = commands.terminal;
        }
        // lib.optionalAttrs desktopEnabled {
          BROWSER = commands.browser;
        }
        // lib.optionalAttrs editorEnabled {
          EDITOR = commands.editorInline;
          VISUAL = commands.editorInline;
          SUDO_EDITOR = commands.editorInline;
        };
      };
    })

    (lib.mkIf desktopEnabled {
      home-manager.users.${config.user.name} = {
        xdg.desktopEntries = {
          default-editor = {
            name = "Default text editor";
            genericName = "Text Editor";
            exec = "${commands.editor} %F";
            icon = "nvim";
            mimeType = [ "text/plain" ];
            terminal = false;
          };
          default-file-manager = {
            name = "Default file manager";
            genericName = "File Manager";
            exec = "${commands.fileManager} %F";
            icon = "yazi";
            mimeType = [ "inode/directory" ];
            terminal = false;
          };
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "inode/directory" = "default-file-manager.desktop";
            "text/plain" = "default-editor.desktop";
            "text/*" = "default-editor.desktop";
            "text/html" = browser.desktopId;
            "x-scheme-handler/http" = browser.desktopId;
            "x-scheme-handler/https" = browser.desktopId;
            "x-scheme-handler/about" = browser.desktopId;
          };
        };
      };
    })
  ];
}
