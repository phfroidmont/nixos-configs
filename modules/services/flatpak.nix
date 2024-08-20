{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.flatpak;
in
{
  options.modules.services.flatpak = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "*";
    };

  };
}
