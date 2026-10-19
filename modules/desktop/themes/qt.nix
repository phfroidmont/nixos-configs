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
    enable = lib.mkEnableOption "the Qt theme";
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      qt5.qtquickcontrols2
      qt5.qtgraphicaleffects
    ];

    home-manager.users.${config.user.name} = {

      qt = {
        enable = true;
        platformTheme.name = "gtk3";
        style = {
          name = "adwaita-dark";
          package = pkgs.adwaita-qt;
        };
      };
    };
  };
}
