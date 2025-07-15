{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.wm;
  term = "${config.home-manager.users.${config.user.name}.programs.kitty.package}/bin/kitty";
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
        file-manager.enable = true;
        zsh.enable = true;
        dunst.enable = true;
        htop.enable = true;
        flameshot.enable = true;
      };
      hardware = {
        audio.enable = true;
      };
      apps.rofi.enable = true;
    };

    home-manager.users.${config.user.name} = {
      wayland.windowManager.sway = {
        enable = true;
        systemd.enable = true;
        xwayland = true;
        config = {
          modifier = "Mod4";
          input = {
            "type:keyboard" = {
              "xkb_layout" = "fr";
              "xkb_variant" = "nodeadkeys";
              "xkb_options" = "caps:escape";
              "xkb_numlock" = "enabled";
            };
          };

          keybindings = {
            "mod4+Return" = "exec ${term}";
            "mod4+c" = "kill";
            "mod4+Shift+r" = "reload";
            "mod4+Shift+c" = "exit";
            "mod4+Shift+a" = "exec ${term} -e pulsemixer";
            "mod4+w" = "exec firefox";
            "mod4+r" = "exec ${term} -e yazi";
            "mod4+e" = "exec emacsclient -c";
            "mod4+n" = "exec emacsclient -c --eval '(elfeed)'";
            "mod4+i" = "exec ${term} -e htop";
            "mod4+m" = "exec ${term} -e ncmpcpp";
            "mod4+v" = "exec ${term} -e ncmpcpp -s visualizer";
            "mod4+t" = "floating toggle";
            "mod4+d" = "exec rofi -show drun -show-icons";
            "mod4+Shift+p" = "exec rofi -show p -modi p:rofi-power-menu";

            "mod4+h" = "focus left";
            "mod4+j" = "focus down";
            "mod4+k" = "focus up";
            "mod4+l" = "focus right";
            "mod4+Shift+h" = "move left";
            "mod4+Shift+j" = "move down";
            "mod4+Shift+k" = "move up";
            "mod4+Shift+l" = "move right";
            "mod4+f" = "fullscreen";

            "XF86AudioRaiseVolume" = "exec pulsemixer --change-volume +1";
            "XF86AudioLowerVolume" = "exec pulsemixer --change-volume -1";
            "XF86AudioMute" = "exec pulsemixer --toggle-mute";
            "XF86AudioPlay" = "exec mpc toggle";
            "XF86AudioPause" = "exec mpc toggle";
            "XF86AudioNext" = "exec mpc next";
            "XF86AudioPrev" = "exec mpc prev";
            "mod4+p" = "exec mpc toggle";
          };

          keycodebindings = {
            "mod4+10" = "workspace number 1";
            "mod4+11" = "workspace number 2";
            "mod4+12" = "workspace number 3";
            "mod4+13" = "workspace number 4";
            "mod4+14" = "workspace number 5";
            "mod4+15" = "workspace number 6";
            "mod4+16" = "workspace number 7";
            "mod4+17" = "workspace number 8";
            "mod4+18" = "workspace number 9";
            "mod4+19" = "workspace number 0";

            "mod4+Shift+10" = "move container to workspace number 1";
            "mod4+Shift+11" = "move container to workspace number 2";
            "mod4+Shift+12" = "move container to workspace number 3";
            "mod4+Shift+13" = "move container to workspace number 4";
            "mod4+Shift+14" = "move container to workspace number 5";
            "mod4+Shift+15" = "move container to workspace number 6";
            "mod4+Shift+16" = "move container to workspace number 7";
            "mod4+Shift+17" = "move container to workspace number 8";
            "mod4+Shift+18" = "move container to workspace number 9";
            "mod4+Shift+19" = "move container to workspace number 0";
          };
        };
      };

      wayland.windowManager.hyprland = {
        enable = true;
        systemd.enable = true;
        xwayland.enable = true;
        settings = {
          "$mod" = "SUPER";

          env = [
            "XCURSOR_SIZE,24"
            "WLR_NO_HARDWARE_CURSORS,1"
          ];

          xwayland = {
            force_zero_scaling = true;
          };

          general = {
            layout = "dwindle";
            gaps_in = 7;
            gaps_out = 14;
            border_size = 2;
            "col.active_border" = "rgb(B28121)";
            "col.inactive_border" = "rgb(504945)";
            no_focus_fallback = false;
            resize_on_border = false;
            hover_icon_on_border = false;
          };

          dwindle = {
            preserve_split = true;
          };

          debug = {
            disable_logs = false;
            enable_stdout_logs = true;
          };

          input = {
            kb_layout = "fr";
            kb_options = "caps:escape";
            numlock_by_default = "true";
            touchpad = {
              natural_scroll = false;
              disable_while_typing = true;
              tap-to-click = false;
              middle_button_emulation = false;
            };
          };

          gestures = {
            workspace_swipe = true;
            workspace_swipe_fingers = 3;
          };

          animations = {
            enabled = true;
            animation = [
              "windows, 1, 2, default, popin 80%"
              "windowsOut, 1, 2, default, popin 85%"
              "windowsMove, 1, 2, default"
              "workspaces, 1, 2, default"
              "specialWorkspace, 1, 2, default"
            ];
          };

          bind = [
            "$mod, Return, exec, ${term}"
            "$mod, C, killactive"
            "$mod SHIFT, Q, exit"
            "$mod SHIFT, A, exec, ${term} -e pulsemixer"
            "$mod, W, exec, firefox"
            "$mod, R, exec, ${term} -e yazi"
            "$mod, E, exec, emacsclient -c"
            "$mod, N, exec, emacsclient -c --eval '(elfeed)'"
            "$mod, I, exec, ${term} -e htop"
            "$mod, M, exec, ${term} -e ncmpcpp"
            "$mod, V, exec, ${term} -e ncmpcpp -s visualizer"
            "$mod, T, togglefloating"
            "$mod, D, exec, rofi -show drun -show-icons"
            "$mod SHIFT, P, exec, rofi -show p -modi p:rofi-power-menu"

            # Layout manipulation
            "$mod SHIFT, O, layoutmsg, togglesplit"
            "$mod, comma, splitratio, -0.1"
            "$mod, semicolon, splitratio, +0.1"

            "$mod, F, fullscreen, 0"
            "$mod, X, exec, swaylock"

            # Move focus
            "$mod, H, movefocus, l"
            "$mod, L, movefocus, r"
            "$mod, K, movefocus, u"
            "$mod, J, movefocus, d"
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"

            # Move window
            "$mod SHIFT, H, movewindow, l"
            "$mod SHIFT, L, movewindow, r"
            "$mod SHIFT, K, movewindow, u"
            "$mod SHIFT, J, movewindow, d"
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, right, movewindow, r"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, down, movewindow, d"

            # Switch workspaces with mainMod + [0-9]
            "$mod, code:10, moveworkspacetomonitor, 1 current"
            "$mod, code:10, workspace, 1"
            "$mod, 1, moveworkspacetomonitor, 1 current"
            "$mod, 1, workspace, 1"
            "$mod, code:11, moveworkspacetomonitor, 2 current"
            "$mod, code:11, workspace, 2"
            "$mod, 2, moveworkspacetomonitor, 2 current"
            "$mod, 2, workspace, 2"
            "$mod, code:12, moveworkspacetomonitor, 3 current"
            "$mod, code:12, workspace, 3"
            "$mod, 3, moveworkspacetomonitor, 3 current"
            "$mod, 3, workspace, 3"
            "$mod, code:13, moveworkspacetomonitor, 4 current"
            "$mod, code:13, workspace, 4"
            "$mod, 4, moveworkspacetomonitor, 4 current"
            "$mod, 4, workspace, 4"
            "$mod, code:14, moveworkspacetomonitor, 5 current"
            "$mod, code:14, workspace, 5"
            "$mod, 5, moveworkspacetomonitor, 5 current"
            "$mod, 5, workspace, 5"
            "$mod, code:15, moveworkspacetomonitor, 6 current"
            "$mod, code:15, workspace, 6"
            "$mod, 6, moveworkspacetomonitor, 6 current"
            "$mod, 6, workspace, 6"
            "$mod, code:16, moveworkspacetomonitor, 7 current"
            "$mod, code:16, workspace, 7"
            "$mod, 7, moveworkspacetomonitor, 7 current"
            "$mod, 7, workspace, 7"
            "$mod, code:17, moveworkspacetomonitor, 8 current"
            "$mod, code:17, workspace, 8"
            "$mod, 8, moveworkspacetomonitor, 8 current"
            "$mod, 8, workspace, 8"
            "$mod, code:18, moveworkspacetomonitor, 9 current"
            "$mod, code:18, workspace, 9"
            "$mod, 9, moveworkspacetomonitor, 9 current"
            "$mod, 9, workspace, 9"
            "$mod, code:19, moveworkspacetomonitor, 10 current"
            "$mod, code:19, workspace, 10"
            "$mod, 0, moveworkspacetomonitor, 10 current"
            "$mod, 0, workspace, 10"

            # Move active window to a workspace with mainMod + SHIFT + [0-9]
            "$mod SHIFT, code:10, movetoworkspace, 1"
            "$mod SHIFT, 1, movetoworkspace, 1"
            "$mod SHIFT, code:11, movetoworkspace, 2"
            "$mod SHIFT, 2, movetoworkspace, 2"
            "$mod SHIFT, code:12, movetoworkspace, 3"
            "$mod SHIFT, 3, movetoworkspace, 3"
            "$mod SHIFT, code:13, movetoworkspace, 4"
            "$mod SHIFT, 4, movetoworkspace, 4"
            "$mod SHIFT, code:14, movetoworkspace, 5"
            "$mod SHIFT, 5, movetoworkspace, 5"
            "$mod SHIFT, code:15, movetoworkspace, 6"
            "$mod SHIFT, 6, movetoworkspace, 6"
            "$mod SHIFT, code:16, movetoworkspace, 7"
            "$mod SHIFT, 7, movetoworkspace, 7"
            "$mod SHIFT, code:17, movetoworkspace, 8"
            "$mod SHIFT, 8, movetoworkspace, 8"
            "$mod SHIFT, code:18, movetoworkspace, 9"
            "$mod SHIFT, 9, movetoworkspace, 9"
            "$mod SHIFT, code:19, movetoworkspace, 10"
            "$mod SHIFT, 0, movetoworkspace, 10"

            # Scroll through existing workspaces with mainMod + scroll
            "$mod, mouse_down, workspace, e-1"
            "$mod, mouse_up, workspace, e+1"

            # Media controls
            ", XF86AudioRaiseVolume, exec, pulsemixer --change-volume +1"
            ", XF86AudioLowerVolume, exec, pulsemixer --change-volume -1"
            # ", XF86AudioMicMute, exec, pulsemixer --toggle-mute"
            ", XF86AudioMute, exec, pulsemixer --toggle-mute"
            ", XF86AudioPlay, exec, mpc toggle"
            ", XF86AudioPause, exec, mpc toggle"
            ", XF86AudioNext, exec, mpc next"
            ", XF86AudioPrev, exec, mpc prev"
            "$mod, P, exec, mpc toggle"

            ", XF86MonBrightnessDown, exec, light -U 5"
            ", XF86MonBrightnessUp, exec, light -A 5"

            # ", Print, exec, flameshot full"
            ", Print, exec, env QT_SCREEN_SCALE_FACTORS=0.66666666 flameshot gui"
          ];

          bindm = [
            # Move/resize windows with mainMod + LMB/RMB and dragging
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];

          exec-once = [
            "${pkgs.swaybg}/bin/swaybg --image ${config.modules.desktop.wallpaper} --mode fill"
            "keepassxc"
          ];

          misc = {
            force_default_wallpaper = 0;
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            animate_manual_resizes = true;
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
              format = "  {usage}%";
              tooltip = false;
            };

            memory = {
              interval = 1;
              format = " {percentage}%";
              tooltip = false;
            };

            disk = {
              interval = 60;
              format = "  {free}";
              tooltip = false;
            };

            clock = {
              format = "󰥔 {:%A, %d %h %H:%M}";
              format-alt = "󰥔 {:%d/%m/%Y %H:%M}";
              tooltip = false;
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
            background: #282828;
            border: 0px solid;
            border-radius: 0px;
          }

          window#waybar {
            background: #282828;
            color: #ebdbb2;
          }

          #workspaces button {
            padding: 0 0.6em;
            color: #a89984;
            border-radius: 0px;
          }

          #workspaces button.active {
            color: #ebdbb2;
            background: #665c54;
          }

          #workspaces button.urgent {
            color: #1d2021;
            background: #fb4934;
          }

          #workspaces button:hover {
            background: #665c54;
          }

          #network,
          #workspaces,
          #bluetooth,
          #tray {
            color: #ebdbb2;
            padding: 0 5px;
            margin: 0 5px;
          }

          #cpu,
          #memory,
          #disk,
          #clock {
            padding: 0 5px;
            margin: 0 5px;
            color: #83a598;
          }
        '';
        package = pkgs.waybar.override { wireplumberSupport = false; };
      };

      home = {
        packages = with pkgs; [
          wlr-randr
          wl-clipboard
          wdisplays
        ];
      };

      programs.swaylock = {
        enable = true;

        package = pkgs.swaylock-effects;

        settings = {
          ignore-empty-password = true;
          daemonize = true;
          # fade-in = 0.5;
          indicator = true;
          clock = true;
          datestr = "%d/%m/%Y";
          screenshots = true;
          hide-keyboard-layout = true;
          indicator-caps-lock = true;
          bs-hl-color = "7daea3cc";
          caps-lock-bs-hl-color = "7daea3cc";
          caps-lock-key-hl-color = "d3869bcc";
          font = "MesloLGS Nerd Font Propo";
          font-size = "35";
          indicator-idle-visible = true;
          indicator-radius = 100;
          indicator-thickness = 7;
          inside-color = "32302f66";
          inside-clear-color = "89b48266";
          inside-caps-lock-color = "e78a4e66";
          inside-ver-color = "7daea366";
          inside-wrong-color = "ea696266";
          key-hl-color = "a9b665cc";
          layout-bg-color = "32302f00";
          layout-text-color = "d4be98";
          line-color = "00000000";
          ring-color = "e78a4ecc";
          ring-clear-color = "89b482cc";
          ring-caps-lock-color = "e78a4ecc";
          ring-ver-color = "7daea3cc";
          ring-wrong-color = "ea6962cc";
          separator-color = "00000000";
          text-color = "d4be98";
          text-clear-color = "d4be98";
          text-caps-lock-color = "d4be98";
          text-ver-color = "d4be98";
          text-wrong-color = "d4be98";
          effect-blur = "9x9";
          effect-greyscale = true;
          # effect-vignette = "0.5:0.5";
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

    security.pam.services.swaylock = { };

  };
}
