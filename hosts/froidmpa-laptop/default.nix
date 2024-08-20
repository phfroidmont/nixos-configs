{ config, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  modules = {
    desktop.wm.enable = true;
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

  home-manager.users.${config.user.name} =
    { _ }:
    {
      services.network-manager-applet.enable = true;
      services.blueman-applet.enable = true;
      wayland.windowManager.hyprland.settings = {
        dwindle.no_gaps_when_only = 1;
      };
    };

  services.pipewire.wireplumber.extraConfig = {
    "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.roles" = [
        "hsp_hs"
        "hsp_ag"
        "hfp_hf"
        "hfp_ag"
      ];
    };
  };
  system.stateVersion = "21.05";
}
