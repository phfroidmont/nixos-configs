{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.dunst;
  c = (import ./themes/_palette.nix).semantic;
in
{
  options.modules.desktop.dunst = {
    enable = lib.my.mkBoolOpt false;
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      services.dunst = {
        enable = true;
        settings = {
          global = {
            alignment = "left";
            monitor = 0;
            browser = "firefox -new-tab";
            corner_radius = 5;
            dmenu = "${pkgs.rofi}/bin/rofi -dmenu -p dunst";
            follow = "none";
            origin = "top-right";
            width = 440;
            offset = "26x26";
            history_length = 20;
            icon_position = "right";
            horizontal_padding = 16;
            ignore_newline = "no";
            separator_color = "auto";
            separator_height = 4;
            line_height = 0;
            max_icon_size = 64;
            padding = 20;
            shrink = "no";
            transparency = 5;
            font = "MesloLGS Nerd Font 12";
            idle_threshold = 120;
            indicate_hidden = "yes";
            markup = "full";
            format = "<b>%s (%a)</b>\\n%b";
            show_age_threshold = 60;
            show_indicators = "yes";
            word_wrap = "yes";
            sticky_history = "yes";
            sort = "yes";
            frame_width = 1;
            frame_color = c.bgStrong;
          };
          urgency_low = {
            foreground = c.fg;
            background = c.bgAlt;
            timeout = 8;
          };
          urgency_normal = {
            foreground = c.fg;
            background = c.bg;
            timeout = 14;
          };
          urgency_critical = {
            foreground = c.bg;
            background = c.critical;
            timeout = 0;
          };
        };
      };
    };
  };
}
