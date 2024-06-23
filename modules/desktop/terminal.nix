{ config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.terminal;
in {
  options.modules.desktop.terminal = { enable = mkBoolOpt false; };
  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      programs.kitty = {
        enable = true;
        shellIntegration.enableZshIntegration = true;
        settings = {
          scrollback_lines = 65535;
          enable_audio_bell = false;
          font_size = 10;
        };
        keybindings = {
          "ctrl+up" = "change_font_size all +2.0";
          "ctrl+down" = "change_font_size all -2.0";
          "shift+page_up" = "scroll_page_up";
          "shift+page_down" = "scroll_page_down";
          "ctrl+shift+comma" = "scroll_to_prompt -1";
          "ctrl+shift+semicolon" = "scroll_to_prompt 1";
        };
        theme = "Gruvbox Dark";
      };
    };
  };
}
