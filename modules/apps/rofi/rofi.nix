{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.apps.rofi;
in {
  options.modules.apps.rofi = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      programs.rofi = {
        enable = true;
        package = pkgs.rofi.override { plugins = [ pkgs.rofi-calc ]; };
        terminal = "alacritty";
        extraConfig = {
          icon-theme = "Paper";
          cycle = true;
          disable-history = false;
          monitor = "-4";

          # Vim-esque C-j/C-k as up/down in rofi
          kb-accept-entry = "Return,Control+m,KP_Enter";
          kb-row-down = "Down,Control+n,Control+j";
          kb-remove-to-eol = "";
          kb-row-up = "Up,Control+p,Control+k";
          kb-remove-char-forward = "";
          kb-remove-to-sol = "";
          kb-page-prev = "Control+u";
          kb-page-next = "Control+d";
        };
        theme = ./theme.rasi;
      };
      home.packages = with pkgs.unstable; [ paper-icon-theme rofi-power-menu ];
    };
  };
}
