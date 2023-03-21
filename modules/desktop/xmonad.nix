{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.desktop.xmonad;
in {
  options.modules.desktop.xmonad = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    services.xserver = {
      enable = true;
      layout = "fr";
      desktopManager.xterm.enable = false;
      windowManager.xmonad.enable = true;
      displayManager.lightdm = {
        enable = true;
        background = ./files/wallpaper.png;
        greeters.mini.enable = true;
      };
    };

    home-manager.users.${config.user.name} = {
      xsession = {
        windowManager.xmonad = {
          enable = true;
          enableContribAndExtras = true;
          config = ./files/xmonad.hs;
        };
      };
      home.packages = with pkgs.unstable; [
        haskellPackages.xmobar
        i3lock

        feh
        scrot
      ];
    };

  };
}
