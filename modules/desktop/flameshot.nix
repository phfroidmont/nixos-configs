{ config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.flameshot;
in {
  options.modules.desktop.flameshot = { enable = mkBoolOpt false; };
  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = { config, ... }: {
      services.flameshot = {
        enable = true;
        package = pkgs.flameshot.overrideAttrs (old: {
          src = inputs.flameshot-git;
          cmakeFlags = [ "-DUSE_WAYLAND_GRIM=1" ];
        });
        settings = {
          General = {
            showStartupLaunchMessage = false;
            disabledTrayIcon = true;
            showHelp = false;
            showDesktopNotification = false;
            filenamePattern = "%F_%T";
            savePath = "${config.home.homeDirectory}/Pictures/Screenshots";
            savePathFixed = true;
            saveAfterCopy = true;
            uiColor = "#83A598";
          };
        };
      };
      home.packages = with pkgs.unstable; [ grim ];

    };
  };
}
