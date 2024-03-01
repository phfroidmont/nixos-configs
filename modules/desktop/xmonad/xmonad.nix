{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;

let cfg = config.modules.desktop.xmonad;
in {
  options.modules.desktop.xmonad = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    modules = {
      desktop = {
        polybar.enable = true;
        picom.enable = true;
        themes = {
          gtk.enable = true;
          qt.enable = true;
        };
      };
      apps.rofi.enable = true;
    };

    services.xserver = {
      enable = true;
      layout = "fr";
      autoRepeatDelay = 400;
      autoRepeatInterval = 25;
      desktopManager.xterm.enable = false;
      windowManager.xmonad.enable = true;
      displayManager.sddm.enable = true;

    };

    home-manager.users.${config.user.name} = {
      xsession = {
        windowManager.xmonad = {
          enable = true;
          enableContribAndExtras = true;
          config = ./xmonad.hs;
        };
      };

      home = {
        packages = with pkgs.unstable; [
          i3lock

          feh
          scrot
        ];
      };
    };

  };
}
