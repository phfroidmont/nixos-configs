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
      displayManager.lightdm = {
        enable = true;
        background = ../wallpaper.png;
        greeters.mini = {
          enable = true;
          user = config.user.name;
          extraConfig = ''
            text-color = "#fbf1c7"
            password-background-color = "#3c3836"
            window-color = "#282828"
            border-color = "#458588"
          '';
        };
      };
    };

    home-manager.users.${config.user.name} = {
      xsession = {
        windowManager.xmonad = {
          enable = true;
          enableContribAndExtras = true;
          config = ./xmonad.hs;
        };
      };

      services.picom.enable = true;

      home = {
        file.".xmonad/scripts" = {
          source = ./scripts;
          recursive = true;
        };

        packages = with pkgs.unstable; [
          i3lock

          feh
          scrot
        ];
      };
    };

  };
}
