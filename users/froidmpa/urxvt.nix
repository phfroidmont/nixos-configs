{ pkgs, ... }:
{
  enable = true;
  package = pkgs.rxvt_unicode-with-plugins;
  fonts = [ "xft:monospace:size=12:antialias=true" ];
  scroll = {
    bar.enable = false;
    lines = 65535;
  };
  keybindings = {
    "Shift-Control-C" = "eval:selection_to_clipboard";
    "Shift-Control-V" = "eval:paste_clipboard";
  };
  extraConfig = {
    "perl-ext-common" = "default,clipboard,matcher,resize-font";
    "background" = "rgba:28ff/28ff/28ff/cf00";
    "foreground" = "#ebdbb2";
    "color0" = "#282828";
    "color8" = "#928374";
    "color1" = "#cc241d";
    "color9" = "#fb4934";
    "color2" = "#98971a";
    "color10" = "#b8bb26";
    "color3" = "#d79921";
    "color11" = "#fabd2f";
    "color4" = "#458588";
    "color12" = "#83a598";
    "color5" = "#b16286";
    "color13" = "#d3869b";
    "color6" = "#689d6a";
    "color14" = "#8ec07c";
    "color7" = "#a89984";
    "color15" = "#ebdbb2";
    "termName" = "rxvt-256color";
    "letterSpace" = "-1";
    "internalBorder" = "10";
    "depth" = "32";
    "resize-font.smaller" = "C-Down";
    "resize-font.bigger" = "C-Up";
  };
}
