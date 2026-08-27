{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.wm;
  applications = config.modules.applications.commands;
  herdr = config.modules.desktop.herdr.commands;
  btop = lib.getExe config.home-manager.users.${config.user.name}.programs.btop.package;
  wallpaper = config.modules.desktop.wallpaper;
  c = (import ./themes/_palette.nix).semantic;
  lua = lib.generators.mkLuaInline;
  toLua = lib.generators.toLua { };
  modKey = key: lua "mod .. ${toLua " + ${key}"}";
  mkBind = key: dispatcher: {
    _args = [
      key
      dispatcher
    ];
  };
  mkMouseBind = key: dispatcher: {
    _args = [
      key
      dispatcher
      { mouse = true; }
    ];
  };
  exec = command: lua "hl.dsp.exec_cmd(${toLua command})";
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
      (mkBind (modKey "code:${code}") moveWorkspace)
      (mkBind (modKey "code:${code}") focusWorkspace)
      (mkBind (modKey key) moveWorkspace)
      (mkBind (modKey key) focusWorkspace)
      (mkBind (modKey "SHIFT + code:${code}") moveWindow)
      (mkBind (modKey "SHIFT + ${key}") moveWindow)
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
        dunst.enable = true;
        btop.enable = true;
      };
      editor.vim.enable = true;
      hardware = {
        audio.enable = true;
      };
      apps = {
        rofi.enable = true;
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

            bind = [
              (mkBind (modKey "Return") (exec applications.terminal))
              (mkBind (modKey "SHIFT + Return") (exec herdr.launch))
              (mkBind (modKey "CTRL + K") (exec herdr.showKeybindings))
              (mkBind (modKey "C") (lua "hl.dsp.window.close()"))
              (mkBind (modKey "SHIFT + A") (exec "${applications.terminal} -e pulsemixer"))
              (mkBind (modKey "W") (exec applications.browser))
              (mkBind (modKey "R") (exec applications.fileManager))
              (mkBind (modKey "E") (exec applications.editor))
              (mkBind (modKey "N") (exec "${applications.terminal} -e newsboat"))
              (mkBind (modKey "SHIFT + T") (exec "${applications.terminal} -e ${btop}"))
              (mkBind (modKey "M") (exec "${applications.terminal} -e ncmpcpp"))
              (mkBind (modKey "V") (exec "${applications.terminal} -e ncmpcpp -s visualizer"))
              (mkBind (modKey "T") (lua ''hl.dsp.window.float({ action = "toggle" })''))
              (mkBind (modKey "D") (exec "rofi -show drun -show-icons"))
              (mkBind (modKey "SHIFT + P") (exec "rofi -show p -modi p:rofi-power-menu"))

              # Layout manipulation
              (mkBind (modKey "SHIFT + O") (lua ''hl.dsp.layout("togglesplit")''))
              (mkBind (modKey "comma") (lua ''hl.dsp.layout("splitratio -0.1")''))
              (mkBind (modKey "semicolon") (lua ''hl.dsp.layout("splitratio +0.1")''))

              (mkBind (modKey "F") (lua ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })''))
              (mkBind (modKey "X") (exec "hyprlock"))

              # Move focus
              (mkBind (modKey "H") (lua ''hl.dsp.focus({ direction = "left" })''))
              (mkBind (modKey "L") (lua ''hl.dsp.focus({ direction = "right" })''))
              (mkBind (modKey "K") (lua ''hl.dsp.focus({ direction = "up" })''))
              (mkBind (modKey "J") (lua ''hl.dsp.focus({ direction = "down" })''))
              (mkBind (modKey "left") (lua ''hl.dsp.focus({ direction = "left" })''))
              (mkBind (modKey "right") (lua ''hl.dsp.focus({ direction = "right" })''))
              (mkBind (modKey "up") (lua ''hl.dsp.focus({ direction = "up" })''))
              (mkBind (modKey "down") (lua ''hl.dsp.focus({ direction = "down" })''))

              # Move window
              (mkBind (modKey "SHIFT + H") (lua ''hl.dsp.window.move({ direction = "left" })''))
              (mkBind (modKey "SHIFT + L") (lua ''hl.dsp.window.move({ direction = "right" })''))
              (mkBind (modKey "SHIFT + K") (lua ''hl.dsp.window.move({ direction = "up" })''))
              (mkBind (modKey "SHIFT + J") (lua ''hl.dsp.window.move({ direction = "down" })''))
              (mkBind (modKey "SHIFT + left") (lua ''hl.dsp.window.move({ direction = "left" })''))
              (mkBind (modKey "SHIFT + right") (lua ''hl.dsp.window.move({ direction = "right" })''))
              (mkBind (modKey "SHIFT + up") (lua ''hl.dsp.window.move({ direction = "up" })''))
              (mkBind (modKey "SHIFT + down") (lua ''hl.dsp.window.move({ direction = "down" })''))
            ]
            ++ workspaceBinds
            ++ [

              # Scroll through existing workspaces with mainMod + scroll
              (mkBind (modKey "mouse_down") (lua ''hl.dsp.focus({ workspace = "e-1" })''))
              (mkBind (modKey "mouse_up") (lua ''hl.dsp.focus({ workspace = "e+1" })''))

              # Media controls
              (mkBind "XF86AudioRaiseVolume" (exec "pulsemixer --change-volume +1"))
              (mkBind "XF86AudioLowerVolume" (exec "pulsemixer --change-volume -1"))
              (mkBind "XF86AudioMute" (exec "pulsemixer --toggle-mute"))
              (mkBind "XF86AudioPlay" (exec "mpc toggle"))
              (mkBind "XF86AudioPause" (exec "mpc toggle"))
              (mkBind "XF86AudioNext" (exec "mpc next"))
              (mkBind "XF86AudioPrev" (exec "mpc prev"))
              (mkBind (modKey "P") (exec "mpc toggle"))

              (mkBind "XF86MonBrightnessDown" (exec "xbacklight -ctrl amdgpu_bl1 -dec 5"))
              (mkBind "XF86MonBrightnessUp" (exec "xbacklight -ctrl amdgpu_bl1 -inc 5"))

              (mkBind "Print" (exec ''grim -g "$(slurp)" - | satty -f -''))
              (mkBind "SHIFT + Print" (exec "grim - | satty -f -"))

              # Move/resize windows with mainMod + LMB/RMB and dragging
              (mkMouseBind (modKey "mouse:272") (lua "hl.dsp.window.drag()"))
              (mkMouseBind (modKey "mouse:273") (lua "hl.dsp.window.resize()"))
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
        };

        programs.waybar = {
          enable = true;
          systemd.enable = true;
          settings = {
            mainBar = {
              layer = "top";
              position = "bottom";
              height = 25;
              spacing = 2;
              reload-style-on-change = true;
              modules-left = [
                "cpu"
                "memory"
                "disk"
                "hyprland/window"
              ];
              modules-center = [ "hyprland/workspaces" ];
              modules-right = [
                "mpd"
                "battery"
                "clock"
                "tray"
              ];

              tray = {
                icon-size = 14;
                spacing = 5;
                show-passive-items = true;
              };

              cpu = {
                interval = 1;
                states = {
                  warning = 60;
                  critical = 85;
                };
                format = "<span size=\"120%\" rise=\"0\">󰍛</span> {usage}%";
                tooltip = false;
              };

              memory = {
                interval = 1;
                states = {
                  warning = 70;
                  critical = 90;
                };
                format = "<span size=\"120%\" rise=\"-80\">󰘚</span> {percentage}%";
                tooltip = false;
              };

              disk = {
                interval = 60;
                states = {
                  warning = 75;
                  critical = 90;
                };
                format = "<span size=\"120%\" rise=\"0\">󰋊</span> {free}";
                tooltip = false;
              };

              clock = {
                format = "󰥔 {:%A, %d %h %H:%M}";
                format-alt = "󰥔 {:%d/%m/%Y %H:%M}";
                tooltip = false;
              };

              battery = {
                states = {
                  warning = 30;
                  critical = 15;
                };
                format = "<span size=\"120%\" rise=\"0\">{icon}</span> {capacity}%";
                format-charging = "<span size=\"120%\" rise=\"0\">󱐋</span> {capacity}%";
                format-plugged = "<span size=\"120%\" rise=\"0\"></span> {capacity}%";
                format-full = "<span size=\"120%\" rise=\"0\"></span>";
                format-icons = [
                  ""
                  ""
                  ""
                  ""
                  ""
                ];
                tooltip-format = "{timeTo}";
              };

            };
          };
          style = ''
            * {
              border: none;
              font-family: MesloLGS Nerd Font;
              font-size: 12px;
              min-height: 0;
            }

            tooltip {
              background: ${c.bg};
              border: 0px solid;
              border-radius: 0px;
            }

            window#waybar {
              background: ${c.bg};
              color: ${c.fg};
            }

            #workspaces button {
              padding: 0 0.6em;
              color: ${c.fgMuted};
              border-radius: 0px;
            }

            #workspaces button.active {
              color: ${c.fg};
              background: ${c.bgHover};
            }

            #workspaces button.urgent {
              color: ${c.bgStrong};
              background: ${c.critical};
            }

            #workspaces button:hover {
              background: ${c.bgHover};
            }

            #network,
            #workspaces,
            #bluetooth,
            #tray {
              color: ${c.fg};
              padding: 0 5px;
              margin: 0 5px;
            }

            #cpu,
            #memory,
            #disk,
            #battery,
            #clock {
              padding: 0 5px;
              margin: 0 5px;
              color: ${c.info};
            }

            #battery.charging,
            #battery.plugged,
            #battery.full {
              color: ${c.success};
            }

            #battery.warning:not(.charging) {
              color: ${c.warning};
            }

            #cpu.warning,
            #memory.warning,
            #disk.warning {
              color: ${c.warning};
            }

            #battery.critical:not(.charging) {
              color: ${c.critical};
            }

            #cpu.critical,
            #memory.critical,
            #disk.critical {
              color: ${c.critical};
            }
          '';
          package = pkgs.waybar.override { wireplumberSupport = false; };
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
