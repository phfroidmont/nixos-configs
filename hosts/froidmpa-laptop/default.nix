{ pkgs, config, lib, ... }: {
  imports = [ ./hardware-configuration.nix ];

  modules = {
    desktop.hyprland.enable = true;
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
  };

  system.stateVersion = "21.05";
}
