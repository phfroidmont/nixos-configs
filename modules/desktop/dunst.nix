{ config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.dunst;
in {
  options.modules.desktop.dunst = { enable = mkBoolOpt false; };
  config = mkIf cfg.enable {
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
            font = "monospace 14";
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
            frame_color = "#1d2021";
          };
          urgency_low = {
            foreground = "#ebdbb2";
            background = "#3c3836";
            timeout = 8;
          };
          urgency_normal = {
            foreground = "#ebdbb2";
            background = "#32302f";
            timeout = 14;
          };
          urgency_critical = {
            foreground = "#32302f";
            background = "#cc241d";
            timeout = 0;
          };
        };
      };
    };
  };
}
