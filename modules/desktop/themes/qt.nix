{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.themes.qt;

in
{
  options.modules.desktop.themes.qt = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      libsForQt5.qt5.qtquickcontrols2
      libsForQt5.qt5.qtgraphicaleffects
    ];

    home-manager.users.${config.user.name} = {

      qt = {
        enable = true;
        platformTheme.name = "gtk";
        style = {
          name = "adwaita-dark";
          package = pkgs.adwaita-qt;
        };
      };
    };
  };
}
