{ config, lib, ... }:

let
  cfg = config.modules.desktop.terminal;
in
{
  options.modules.desktop.terminal = {
    enable = lib.my.mkBoolOpt false;
  };
  config = lib.mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      programs.kitty = {
        enable = true;
        shellIntegration.enableZshIntegration = true;
        settings = {
          scrollback_lines = 65535;
          enable_audio_bell = false;
          font_family = "Meslo LG S";
          font_size = 10;
          symbol_map = "U+e000-U+e00a,U+ea60-U+ebeb,U+e0a0-U+e0c8,U+e0ca,U+e0cc-U+e0d4,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b1,U+e700-U+e7c5,U+f000-U+f2e0,U+f300-U+f372,U+f400-U+f532,U+f0001-U+f1af0 Symbols Nerd Font Mono";
        };
        keybindings = {
          "ctrl+up" = "change_font_size all +2.0";
          "ctrl+down" = "change_font_size all -2.0";
          "shift+page_up" = "scroll_page_up";
          "shift+page_down" = "scroll_page_down";
          "ctrl+shift+comma" = "scroll_to_prompt -1";
          "ctrl+shift+semicolon" = "scroll_to_prompt 1";
          "ctrl+shift+t" = "new_tab_with_cwd";
        };
        theme = "Gruvbox Dark";
      };
    };
  };
}
