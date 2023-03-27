{ inputs, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.themes.qt;
in {
  options.modules.desktop.themes.qt = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {

      xdg.configFile = {
        "Kvantum/kvantum.kvconfig" = { text = "theme=Gruvbox-Dark-Blue"; };

        "Kvantum/Gruvbox-Dark-Blue" = {
          source = "${inputs.gruvbox-kvantum-theme}/Gruvbox-Dark-Blue";
        };
      };

      home.sessionVariables = { QT_STYLE_OVERRIDE = "kvantum-dark"; };

      home.packages = with pkgs.unstable; [ libsForQt5.qtstyleplugin-kvantum ];
    };
  };
}
