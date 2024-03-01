{ pkgs, config, lib, ... }: {
  imports = [ ./hardware-configuration.nix ];

  modules = {
    hardware = { audio.enable = true; };
    desktop = {
      xmonad.enable = true;
      alacritty.enable = true;
      zsh.enable = true;
      vscode.enable = true;
      dunst.enable = true;
      htop.enable = true;
      flameshot.enable = true;
    };
    editor = {
      vim.enable = true;
      emacs.enable = true;
    };
    services = {
      flatpak.enable = true;
      belgian-eid.enable = true;
      docker.enable = true;
      libvirt.enable = true;
      languagetool.enable = true;
    };
    media = {
      mpd.enable = true;
      ncmpcpp.enable = true;
    };
  };

  # Monitor backlight control
  programs.light.enable = true;
  users.users.${config.user.name}.extraGroups = [ "video" ];

  services.tlp.enable = true;

  home-manager.users.${config.user.name} = { pkgs, config, ... }: {
    services.network-manager-applet.enable = true;
    services.blueman-applet.enable = true;
    services.grobi = {
      enable = true;
      executeAfter = [ "${pkgs.feh}/bin/feh --bg-fill ~/.wallpaper.jpg" ];
      rules = [
        {
          name = "External HDMI";
          outputs_connected = [ "HDMI-1" ];
          configure_single = "HDMI-1";
          primary = true;
          atomic = true;
        }
        {
          name = "Primary";
          configure_single = "eDP";
        }
      ];
    };
  };

  system.stateVersion = "21.05";
}
