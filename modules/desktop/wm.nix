{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.wm;
  applications = config.modules.applications.commands;
  herdr = config.modules.desktop.herdr.commands;
  quickshellCommands = config.modules.apps.quickshell.commands;
  btop = lib.getExe config.home-manager.users.${config.user.name}.programs.btop.package;
  kitty = lib.getExe config.home-manager.users.${config.user.name}.programs.kitty.package;
  jellyfinTui = lib.getExe pkgs.jellyfin-tui;
  fos = lib.getExe pkgs.fos;
  captureRegion = lib.getExe' pkgs.fos "fos-internal-capture-region";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  quickshell =
    lib.getExe' inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell
      "qs";
  wallpaper = config.modules.desktop.wallpaper;
  c = (import ./themes/_palette.nix).semantic;
  lua = lib.generators.mkLuaInline;
  toLua = lib.generators.toLua { };
  modKey = key: lua "mod .. ${toLua " + ${key}"}";
  mkBind = key: description: dispatcher: {
    _args = [
      key
      dispatcher
      { inherit description; }
    ];
  };
  mkMouseBind = key: description: dispatcher: {
    _args = [
      key
      dispatcher
      {
        inherit description;
        mouse = true;
      }
    ];
  };
  exec = command: lua "hl.dsp.exec_cmd(${toLua command})";
  notification = method: exec "${quickshell} -c desktop ipc call -- notifications ${method}";
  togglePanel = id: exec "${quickshell} -c desktop ipc call -- shell toggle ${id} '{}'";
  toggleMusic = lua ''
    function()
      hl.exec_cmd(${toLua "${systemctl} --user start jellyfin-tui.service"})
      return hl.dispatch(hl.dsp.workspace.toggle_special("music"))
    end
  '';
  workspaceBinds = lib.concatMap (
    workspace:
    let
      key = toString (lib.mod workspace 10);
      code = toString (workspace + 9);
      moveWorkspace = lua "hl.dsp.workspace.move(${
        toLua {
          inherit workspace;
          monitor = "current";
        }
      })";
      focusWorkspace = lua "hl.dsp.focus(${toLua { inherit workspace; }})";
      moveWindow = lua "hl.dsp.window.move(${toLua { inherit workspace; }})";
    in
    [
      (mkBind (modKey "code:${code}") "Move workspace ${toString workspace} to current monitor"
        moveWorkspace
      )
      (mkBind (modKey "code:${code}") "Focus workspace ${toString workspace}" focusWorkspace)
      (mkBind (modKey key) "Move workspace ${toString workspace} to current monitor" moveWorkspace)
      (mkBind (modKey key) "Focus workspace ${toString workspace}" focusWorkspace)
      (mkBind (modKey "SHIFT + code:${code}") "Move window to workspace ${toString workspace}" moveWindow)
      (mkBind (modKey "SHIFT + ${key}") "Move window to workspace ${toString workspace}" moveWindow)
    ]
  ) (lib.range 1 10);
in
{
  options.modules.desktop.wm = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    modules = {
      desktop = {
        themes = {
          gtk.enable = true;
          qt.enable = true;
        };
        terminal.enable = true;
        herdr.enable = true;
        file-manager.enable = true;
        zsh.enable = true;
        btop.enable = true;
      };
      editor.vim.enable = true;
      hardware = {
        audio.enable = true;
      };
      apps = {
        quickshell.enable = true;
        newsboat.enable = true;
      };
    };

    home-manager.users.${config.user.name} =
      { config, ... }:
      {
        wayland.windowManager.hyprland = {
          enable = true;
          configType = "lua";
          systemd.enable = true;
          xwayland.enable = true;
          settings = {
            mod._var = "SUPER";

            env = [
              {
                _args = [
                  "XCURSOR_SIZE"
                  "24"
                ];
              }
              {
                _args = [
                  "WLR_NO_HARDWARE_CURSORS"
                  "1"
                ];
              }
            ];

            config = {
              xwayland.force_zero_scaling = true;

              general = {
                layout = "dwindle";
                gaps_in = 7;
                gaps_out = 14;
                border_size = 2;
                col = {
                  active_border = c.borderActiveRgb;
                  inactive_border = c.borderInactiveRgb;
                };
                no_focus_fallback = false;
                resize_on_border = false;
                hover_icon_on_border = false;
              };

              dwindle.preserve_split = true;

              debug = {
                disable_logs = false;
                enable_stdout_logs = true;
              };

              input = {
                kb_layout = "fr";
                kb_options = "caps:escape";
                numlock_by_default = true;
                touchpad = {
                  natural_scroll = false;
                  disable_while_typing = true;
                  tap_to_click = false;
                  middle_button_emulation = false;
                };
              };

              animations.enabled = true;

              misc = {
                force_default_wallpaper = 0;
                disable_hyprland_logo = true;
                disable_splash_rendering = true;
                animate_manual_resizes = true;
              };
            };

            gesture = {
              fingers = 3;
              direction = "horizontal";
              action = "workspace";
            };

            animation = [
              {
                leaf = "windows";
                enabled = true;
                speed = 2;
                bezier = "default";
                style = "popin 80%";
              }
              {
                leaf = "windowsOut";
                enabled = true;
                speed = 2;
                bezier = "default";
                style = "popin 85%";
              }
              {
                leaf = "windowsMove";
                enabled = true;
                speed = 2;
                bezier = "default";
              }
              {
                leaf = "workspaces";
                enabled = true;
                speed = 2;
                bezier = "default";
              }
              {
                leaf = "specialWorkspace";
                enabled = true;
                speed = 2;
                bezier = "default";
              }
            ];

            window_rule = [
              {
                name = "floating-tui";
                match.class = "TUI.float";
                float = true;
                center = true;
                size = "875 600";
              }
              {
                name = "jellyfin-tui-workspace";
                match.class = "jellyfin-tui";
                workspace = "special:music silent";
              }
            ];

            bind = [
              (mkBind (modKey "Return") "Terminal" (exec applications.terminal))
              (mkBind (modKey "SHIFT + Return") "Herdr" (exec herdr.launch))
              (mkBind (modKey "C") "Close window" (lua "hl.dsp.window.close()"))
              (mkBind (modKey "SHIFT + A") "Audio mixer" (exec "${applications.terminal} -e pulsemixer"))
              (mkBind (modKey "W") "Browser" (exec applications.browser))
              (mkBind (modKey "SHIFT + F") "File manager" (exec applications.fileManager))
              (mkBind (modKey "E") "Editor" (exec applications.editor))
              (mkBind (modKey "SHIFT + R") "Newsboat" (exec "${applications.terminal} -e newsboat"))
              (mkBind (modKey "SHIFT + T") "System monitor" (exec "${applications.terminal} -e ${btop}"))
              (mkBind (modKey "M") "Music player" toggleMusic)
              (mkBind (modKey "V") "Clipboard" (exec "${quickshell} -c desktop ipc call -- clipboard toggle"))
              (mkBind (modKey "N") "Dismiss notification" (notification "dismissOne"))
              (mkBind (modKey "SHIFT + N") "Dismiss all notifications" (notification "dismissAll"))
              (mkBind (modKey "CTRL + N") "Toggle do not disturb" (notification "toggleDnd"))
              (mkBind (modKey "ALT + N") "Invoke last notification" (notification "invokeLast"))
              (mkBind (modKey "SHIFT + ALT + N") "Notification history" (notification "showHistory"))
              (mkBind (modKey "T") "Toggle window floating" (lua ''hl.dsp.window.float({ action = "toggle" })''))
              (mkBind (modKey "SPACE") "Command menu" (exec "${fos} menu"))
              (mkBind (modKey "CTRL + C") "Capture menu" (exec "${fos} menu capture"))
              (mkBind (modKey "ALT + SPACE") "Applications" (exec "${fos} menu apps"))
              (mkBind (modKey "ESCAPE") "System menu" (exec "${fos} menu system"))
              (mkBind (modKey "B") "Keybindings" (exec quickshellCommands.keybindings))
              (mkBind (modKey "CTRL + A") "Audio controls" (togglePanel "omarchy.audio"))
              (mkBind (modKey "CTRL + W") "Wifi controls" (togglePanel "omarchy.network"))
              (mkBind (modKey "CTRL + B") "Bluetooth controls" (togglePanel "omarchy.bluetooth"))
              (mkBind (modKey "CTRL + D") "Display controls" (togglePanel "omarchy.monitor"))
              (mkBind (modKey "CTRL + P") "Power controls" (togglePanel "omarchy.power"))
              (mkBind (modKey "CTRL + ALT + D") "Clock" (togglePanel "omarchy.clock"))

              # Layout manipulation
              (mkBind (modKey "SHIFT + O") "Toggle split direction" (lua ''hl.dsp.layout("togglesplit")''))
              (mkBind (modKey "comma") "Shrink split" (lua ''hl.dsp.layout("splitratio -0.1")''))
              (mkBind (modKey "semicolon") "Grow split" (lua ''hl.dsp.layout("splitratio +0.1")''))

              (mkBind (modKey "F") "Full screen" (
                lua ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })''
              ))
              (mkBind (modKey "X") "Lock system" (exec "hyprlock"))

              # Move focus
              (mkBind (modKey "H") "Focus left" (lua ''hl.dsp.focus({ direction = "left" })''))
              (mkBind (modKey "L") "Focus right" (lua ''hl.dsp.focus({ direction = "right" })''))
              (mkBind (modKey "K") "Focus up" (lua ''hl.dsp.focus({ direction = "up" })''))
              (mkBind (modKey "J") "Focus down" (lua ''hl.dsp.focus({ direction = "down" })''))
              (mkBind (modKey "left") "Focus left" (lua ''hl.dsp.focus({ direction = "left" })''))
              (mkBind (modKey "right") "Focus right" (lua ''hl.dsp.focus({ direction = "right" })''))
              (mkBind (modKey "up") "Focus up" (lua ''hl.dsp.focus({ direction = "up" })''))
              (mkBind (modKey "down") "Focus down" (lua ''hl.dsp.focus({ direction = "down" })''))

              # Move window
              (mkBind (modKey "SHIFT + H") "Move window left" (
                lua ''hl.dsp.window.move({ direction = "left" })''
              ))
              (mkBind (modKey "SHIFT + L") "Move window right" (
                lua ''hl.dsp.window.move({ direction = "right" })''
              ))
              (mkBind (modKey "SHIFT + K") "Move window up" (lua ''hl.dsp.window.move({ direction = "up" })''))
              (mkBind (modKey "SHIFT + J") "Move window down" (
                lua ''hl.dsp.window.move({ direction = "down" })''
              ))
              (mkBind (modKey "SHIFT + left") "Move window left" (
                lua ''hl.dsp.window.move({ direction = "left" })''
              ))
              (mkBind (modKey "SHIFT + right") "Move window right" (
                lua ''hl.dsp.window.move({ direction = "right" })''
              ))
              (mkBind (modKey "SHIFT + up") "Move window up" (lua ''hl.dsp.window.move({ direction = "up" })''))
              (mkBind (modKey "SHIFT + down") "Move window down" (
                lua ''hl.dsp.window.move({ direction = "down" })''
              ))
            ]
            ++ workspaceBinds
            ++ [

              # Scroll through existing workspaces with mainMod + scroll
              (mkBind (modKey "mouse_down") "Previous workspace" (lua ''hl.dsp.focus({ workspace = "e-1" })''))
              (mkBind (modKey "mouse_up") "Next workspace" (lua ''hl.dsp.focus({ workspace = "e+1" })''))

              # Media controls
              (mkBind "XF86AudioRaiseVolume" "Volume up" (exec "pulsemixer --change-volume +1"))
              (mkBind "XF86AudioLowerVolume" "Volume down" (exec "pulsemixer --change-volume -1"))
              (mkBind "XF86AudioMute" "Toggle mute" (exec "pulsemixer --toggle-mute"))
              (mkBind "XF86AudioPlay" "Play or pause music" (exec "${fos} media play-pause jellyfin-tui"))
              (mkBind "XF86AudioPause" "Play or pause music" (exec "${fos} media play-pause jellyfin-tui"))
              (mkBind "XF86AudioNext" "Next track" (exec "${fos} media next jellyfin-tui"))
              (mkBind "XF86AudioPrev" "Previous track" (exec "${fos} media previous jellyfin-tui"))
              (mkBind (modKey "P") "Play or pause music" (exec "${fos} media play-pause jellyfin-tui"))

              (mkBind "XF86MonBrightnessDown" "Brightness down" (exec "xbacklight -ctrl amdgpu_bl1 -dec 5"))
              (mkBind "XF86MonBrightnessUp" "Brightness up" (exec "xbacklight -ctrl amdgpu_bl1 -inc 5"))

              (mkBind "Print" "Screenshot" (exec "${fos} capture screenshot smart"))
              (mkBind "SHIFT + Print" "Screenshot focused monitor" (exec "${fos} capture screenshot screen"))
              (mkBind "ALT + Print" "Screen recording" (exec "${fos} menu recording"))
              (mkBind (modKey "Print") "Color picker" (exec "${fos} capture color"))
              (mkBind (modKey "CTRL + Print") "Extract text from screenshot" (exec "${fos} capture ocr region"))

              # Move/resize windows with mainMod + LMB/RMB and dragging
              (mkMouseBind (modKey "mouse:272") "Move window" (lua "hl.dsp.window.drag()"))
              (mkMouseBind (modKey "mouse:273") "Resize window" (lua "hl.dsp.window.resize()"))
            ];

            on = {
              _args = [
                "hyprland.start"
                (lua ''
                  function()
                    hl.exec_cmd(${toLua "${pkgs.swaybg}/bin/swaybg --image ${wallpaper} --mode fill"})
                    hl.exec_cmd("keepassxc")
                  end
                '')
              ];
            };
          };
          extraConfig = ''
            hl.layer_rule({ match = { namespace = "selection" }, no_anim = true, animation = "none" })

            local selection_layers = 0
            local selection_binds = {}

            hl.on("layer.opened", function(layer)
              if layer.namespace == "selection" then
                selection_layers = selection_layers + 1
                if selection_layers == 1 then
                  selection_binds = {
                    hl.bind("RETURN", hl.dsp.exec_cmd(${toLua "${captureRegion} --take-window"}), { description = "Capture highlighted window" }),
                    hl.bind("CTRL + RETURN", hl.dsp.exec_cmd(${toLua "${captureRegion} --take-fullscreen"}), { description = "Capture focused monitor" }),
                    hl.bind("TAB", hl.dsp.exec_cmd(${toLua "${captureRegion} --select-window next"}), { description = "Select next window to capture" }),
                    hl.bind("CTRL + TAB", hl.dsp.exec_cmd(${toLua "${captureRegion} --select-window prev"}), { description = "Select previous window to capture" }),
                  }
                  for _, direction in ipairs({ "left", "right", "up", "down" }) do
                    table.insert(
                      selection_binds,
                      hl.bind(direction:upper(), hl.dsp.exec_cmd(${toLua captureRegion} .. " --select-window " .. direction), { description = "Select window to capture" })
                    )
                  end
                end
              end
            end)

            hl.on("layer.closed", function(layer)
              if layer.namespace == "selection" and selection_layers > 0 then
                selection_layers = selection_layers - 1
                if selection_layers == 0 then
                  for _, keybind in ipairs(selection_binds) do
                    keybind:unbind()
                  end
                  selection_binds = {}
                end
              end
            end)
          '';
        };

        programs.satty = {
          enable = true;
          settings = {
            general = {
              output-filename = "${config.home.homeDirectory}/Pictures/Screenshots/satty_%Y-%m-%d_%H-%M-%S.png";
              copy-command = "wl-copy";
              actions-on-enter = [
                "save-to-clipboard"
                "save-to-file"
                "exit"
              ];
              early-exit = true;
              save-after-copy = true;
            };
          };
        };

        home.activation.ensureScreenshotsDir = ''
          ${pkgs.coreutils}/bin/mkdir -p "$HOME/Pictures/Screenshots"
        '';

        home = {
          packages = with pkgs; [
            wlr-randr
            wl-clipboard
            wdisplays
            grim
            slurp
          ];
        };

        programs.hyprlock = {
          enable = true;
          settings = {
            general = {
              hide_cursor = true;
              ignore_empty_input = true;
            };

            background = [
              {
                monitor = "";
                path = "screenshot";
                blur_passes = 3;
                blur_size = 8;
              }
            ];

            input-field = [
              {
                monitor = "";
                size = "320, 58";
                position = "0, -80";
                halign = "center";
                valign = "center";
                dots_center = true;
                fade_on_empty = false;
                outline_thickness = 3;
                inner_color = c.lockInnerRgb;
                outer_color = c.lockOuterRgb;
                font_color = c.lockTextRgb;
                placeholder_text = "Password...";
              }
            ];

            label = [
              {
                monitor = "";
                text = "$TIME";
                color = c.lockTextRgb;
                font_size = 42;
                font_family = "MesloLGS Nerd Font Propo";
                position = "0, 160";
                halign = "center";
                valign = "center";
              }
              {
                monitor = "";
                text = "cmd[update:1000] date +%d/%m/%Y";
                color = c.lockTextRgb;
                font_size = 18;
                font_family = "MesloLGS Nerd Font Propo";
                position = "0, 120";
                halign = "center";
                valign = "center";
              }
            ];
          };
        };

        services.hypridle = {
          enable = true;
          settings = {
            general = {
              lock_cmd = "pidof hyprlock || hyprlock";
              before_sleep_cmd = "loginctl lock-session";
              after_sleep_cmd = "hyprctl dispatch dpms on";
              ignore_systemd_inhibit = false;
              inhibit_sleep = 3;
            };

            listener = [
              {
                timeout = 600;
                on-timeout = "hyprctl dispatch dpms off";
                on-resume = "hyprctl dispatch dpms on";
              }
            ];
          };
        };

        systemd.user.services.fos-stay-awake = {
          Unit.Description = "Manually inhibit idle handling";
          Service.ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=fos-stay-awake --why='Stay awake requested' ${pkgs.coreutils}/bin/sleep infinity";
        };

        systemd.user.services.jellyfin-tui = {
          Unit = {
            Description = "Jellyfin terminal music player";
            After = [ "hyprland-session.target" ];
            PartOf = [ "hyprland-session.target" ];
          };
          Service = {
            ExecStart = "${kitty} --class jellyfin-tui -e ${jellyfinTui} --no-splash";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ "hyprland-session.target" ];
        };
      };

    xdg.portal = {
      enable = true;
      config.preferred = {
        default = "gtk";
        "org.freedesktop.impl.portal.Screencast" = "hyprland";
      };
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
      ];
    };

    hardware.graphics.enable = true;

    security.pam.services.hyprlock = { };

  };
}
