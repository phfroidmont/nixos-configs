{ config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.flameshot;
in {
  options.modules.desktop.flameshot = { enable = mkBoolOpt false; };
  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = { config, ... }: {
      services.flameshot = {
        enable = true;
        settings = {
          General = {
            showStartupLaunchMessage = false;
            showHelp = false;
            showDesktopNotification = false;
            filenamePattern = "%F_%T";
            savePath = "${config.home.homeDirectory}/Pictures/Screenshots";
            saveAfterCopy = true;
            uiColor = "#83A598";
          };
        };
      };
    };
  };
}
