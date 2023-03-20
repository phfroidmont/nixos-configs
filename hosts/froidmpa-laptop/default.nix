{ pkgs, config, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../users
  ];

  home-manager.users.froidmpa = { pkgs, config, ... }: {
    services.network-manager-applet.enable = true;
    services.blueman-applet.enable = true;
    services.grobi = {
      enable = true;
      executeAfter = [ "${pkgs.systemd}/bin/systemctl --user restart stalonetray" "${pkgs.feh}/bin/feh --bg-fill ~/.wallpaper.png" ];
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
