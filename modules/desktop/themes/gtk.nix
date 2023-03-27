{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.themes.gtk;
in {
  options.modules.desktop.themes.gtk = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    systemd.packages = [ pkgs.dconf ];

    services.dbus.packages = with pkgs; [ dconf ];

    home-manager.users.${config.user.name} = {

      gtk = {
        enable = true;
        theme = { name = "gruvbox-dark"; };
        iconTheme = { name = "gruvbox-dark"; };
      };

      home = {

        pointerCursor = {
          package = pkgs.paper-icon-theme;
          name = "Paper";
          size = 24;
          gtk.enable = true;
          x11.enable = true;
        };

        file = {
          ".themes/gruvbox-dark" = {
            source = "${inputs.gruvbox-gtk-theme}/themes/Gruvbox-Dark-BL";
          };
          ".icons/gruvbox-dark" = {
            source = "${inputs.gruvbox-gtk-theme}/icons/Gruvbox-Dark";
          };
        };
      };
    };
  };
}
