{ config, lib, pkgs, ... }:
{
  services.dunst =
    {
      enable = true;
      settings = {
        global = {
          monitor = 0;
          geometry = "350x5-30+50";
          transparency = 10;
          font = "monospace 14";
          idle_threshold = 120;
          allow_markup = "yes";
          format = "<b>%s</b>\n%b";
          show_age_threshold = 300;
          word_wrap = "yes";
          sticky_history = "yes";
          sort = "yes";
        };
        frame = {
          width = 3;
          color = "#ebdbb2";
        };
        shortcuts = {
          close = "ctrl+space";
          close_all = "ctrl+shift+space";
          history = "ctrl+grave";
          context = "ctrl+shift+period";
        };
        urgency_low = {
          foreground = "#ebdbb2";
          background = "#32302f";
          timeout = 10;
        };
        urgency_normal = {
          foreground = "#ebdbb2";
          background = "#32302f";
          timeout = 10;
        };
        urgency_critical = {
          foreground = "#ebdbb2";
          background = "#32302f";
          timeout = 10;
        };
      };
    };
}
