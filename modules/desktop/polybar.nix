{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.desktop.polybar;
in {
  options.modules.desktop.polybar = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    home-manager.users.${config.user.name} = {

      services.polybar = {
        enable = true;

        package = pkgs.polybar.override {
          pulseSupport = true;
          mpdSupport = true;
        };

        script = ''
          export MONITOR=$(polybar -m|tail -1|sed -e 's/:.*$//g')

          polybar main &
        '';

        settings = {
          "colors" = {
            bg = "#282828";
            bg-alt = "#3c3836";
            bg-darker = "#1d2021";
            fg = "#fbf1c7";
            fg-alt = "#928374";

            blue = "#83a598";
            cyan = "#8ec07c";
            green = "#b8bb26";
            orange = "#fe8019";
            purple = "#d3869b";
            red = "#fb4934";
            yellow = "#fabd2f";

            bg-blue = "#458588";
            bg-cyan = "#689d6a";
            bg-green = "#98971a";
            bg-orange = "#d65d0e";
            bg-purple = "#b16268";
            bg-red = "#cc241d";
            bg-yellow = "#d79921";

            black = "#000";
            white = "#FFF";

            trans = "#00000000";
            semi-trans = "#ee282828";
            semi-trans-black = "#aa000000";
            accent = "#83a598";
          };
          "global/wm" = {
            margin-top = 0;
            margin-bottom = 34;
          };
          "bar/main" = {
            monitor = "\${env:MONITOR}";
            background = "\${colors.bg}";
            foreground = "\${colors.fg}";
            enable-ipc = true;

            width = "100%";
            height = "34";
            bottom = true;

            padding = 2;

            font-0 = "MesloLGS Nerd Font Mono:pixelsize=12;3";
            font-1 = "MesloLGS Nerd Font Mono:pixelsize=20;5";

            modules-left = "pulseaudio cpu memory fs xwindow";
            modules-center = "ewmh";
            modules-right = "mpd battery date";

            separator = "  ";

            tray-position = "right";
          };
          "module/ewmh" = {
            type = "internal/xworkspaces";
            pin-workspaces = false;
            enable-click = false;
            enable-scroll = false;

            label-active = "%name%";
            label-active-background = "\${colors.bg-alt}";
            label-active-foreground = "\${colors.fg}";
            label-active-padding = 1;

            label-occupied = "%name%";
            label-occupied-foreground = "\${colors.accent}";
            label-occupied-padding = 1;

            label-urgent-foreground = "\${colors.red}";
            label-urgent-padding = 1;

            label-empty = "%name%";
            label-empty-foreground = "\${colors.fg-alt}";
            label-empty-padding = 1;
          };
          "module/date" = {
            type = "internal/date";
            interval = 5;

            label = "%date%  %time%";
            date = "%A, %d %h";
            date-alt = "%d/%m/%Y";
            time = "%H:%M";
            time-alt = "%H:%M";
            format-foreground = "\${colors.accent}";
            format-prefix = "󰥔";
            format-prefix-font = 2;
            format-prefix-padding = 1;
            format-prefix-foreground = "\${colors.accent}";
          };
          "module/xwindow" = {
            type = "internal/xwindow";
            label = "%title:0:80:...%";
            label-padding-left = 2;

          };
          "module/fs" = {
            type = "internal/fs";
            mount-0 = "/";
            interval = 30;
            format-mounted = "<label-mounted>";
            label-mounted = "%used% of %total%";
            format-mounted-prefix = "";
            format-mounted-prefix-padding = 1;
            format-mounted-prefix-font = 2;
            format-mounted-foreground = "\${colors.accent}";

            format-unmounted = "";
            label-unmounted = "";
            label-unmounted-foreground = "\${colors.fg-alt}";

            bar-used-indicator = "";
            bar-used-width = 10;
            bar-used-foreground-0 = "\${colors.fg}";
            bar-used-foreground-1 = "\${colors.fg}";
            bar-used-foreground-2 = "\${colors.fg}";
            bar-used-foreground-3 = "\${colors.fg}";
            bar-used-foreground-4 = "\${colors.fg}";
            bar-used-foreground-5 = "\${colors.yellow}";
            bar-used-foreground-6 = "\${colors.yellow}";
            bar-used-foreground-7 = "\${colors.yellow}";
            bar-used-foreground-8 = "\${colors.red}";
            bar-used-fill = "|";
            bar-used-empty = "¦";
            bar-used-empty-foreground = "\${colors.fg-alt}";
          };
          "module/cpu" = {
            type = "internal/cpu";
            interval = 2;
            format = "<bar-load>";
            format-prefix = "";
            format-prefix-padding = 1;
            format-prefix-font = 2;
            format-foreground = "\${colors.accent}";

            bar-load-indicator = "";
            bar-load-width = 10;
            bar-load-foreground-0 = "\${colors.fg}";
            bar-load-foreground-1 = "\${colors.fg}";
            bar-load-foreground-2 = "\${colors.fg}";
            bar-load-foreground-3 = "\${colors.fg}";
            bar-load-foreground-4 = "\${colors.fg}";
            bar-load-foreground-5 = "\${colors.yellow}";
            bar-load-foreground-6 = "\${colors.yellow}";
            bar-load-foreground-7 = "\${colors.yellow}";
            bar-load-foreground-8 = "\${colors.red}";
            bar-load-fill = "|";
            bar-load-empty = "¦";
            bar-load-empty-foreground = "\${colors.fg-alt}";
          };
          "module/memory" = {
            type = "internal/memory";
            interval = 3;
            format = "<bar-used>";
            format-prefix = "";
            format-prefix-padding = 1;
            format-prefix-font = 2;
            format-prefix-foreground = "\${colors.accent}";

            bar-used-indicator = "";
            bar-used-width = 10;
            bar-used-foreground-0 = "\${colors.fg}";
            bar-used-foreground-1 = "\${colors.fg}";
            bar-used-foreground-2 = "\${colors.fg}";
            bar-used-foreground-3 = "\${colors.fg}";
            bar-used-foreground-4 = "\${colors.fg}";
            bar-used-foreground-5 = "\${colors.yellow}";
            bar-used-foreground-6 = "\${colors.yellow}";
            bar-used-foreground-7 = "\${colors.yellow}";
            bar-used-foreground-8 = "\${colors.red}";
            bar-used-fill = "|";
            bar-used-empty = "¦";
            bar-used-empty-foreground = "\${colors.fg-alt}";
          };
          "module/pulseaudio" = {
            type = "internal/pulseaudio";

            format-volume = "<ramp-volume> <bar-volume>";
            label-volume-foreground = "\${colors.accent}";

            label-muted = "󰖁";
            label-muted-font = 2;
            format-muted-foreground = "\${colors.red}";
            format-muted = "<label-muted>";

            bar-volume-width = 8;
            bar-volume-gradient = false;
            bar-volume-indicator = "|";
            bar-volume-indicator-foreground = "#ff";
            bar-volume-fill = "─";
            bar-volume-empty = "─";
            bar-volume-empty-foreground = "\${colors.fg-alt}";

            ramp-volume-0 = "󰕿";
            ramp-volume-1 = "󰖀";
            ramp-volume-2 = "󰕾";
            ramp-volume-font = 2;
          };
          "module/mpd" = (mkIf config.modules.media.mpd.enable {
            type = "internal/mpd";
            host = "127.0.0.1";
            port = "6600";

            label-song = "%artist% - %title%";
            format-playing-prefix = "󰎈";
            format-playing-prefix-padding = 1;
            format-playing-prefix-font = 2;
            format-playing-foreground = "\${colors.fg}";
            format-paused-prefix = "󰎊";
            format-paused-prefix-padding = 1;
            format-paused-prefix-font = 2;
            format-paused-foreground = "\${colors.fg-alt}";
          });
          "module/battery" = {
            type = "internal/battery";
            battery = "BAT0";
            adapter = "AC";

            format-charging = "<animation-charging> <label-charging>";
            format-discharging = "<ramp-capacity> <label-discharging>";

            ramp-capacity-0 = "";
            ramp-capacity-1 = "";
            ramp-capacity-2 = "";
            ramp-capacity-3 = "";
            ramp-capacity-4 = "";

            ramp-capacity-font = 2;

            ramp-capacity-0-foreground = "\${colors.red}";
            ramp-capacity-1-foreground = "\${colors.yellow}";
            ramp-capacity-2-foreground = "\${colors.fg-alt}";

            animation-charging-0 = "";
            animation-charging-1 = "";
            animation-charging-2 = "";
            animation-charging-3 = "";
            animation-charging-4 = "";

            animation-charging-font = 2;
          };
        };
      };
    };
  };
}
