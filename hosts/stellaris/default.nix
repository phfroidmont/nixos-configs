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
      work-proxy.enable = true;
    };
    media = {
      mpd.enable = true;
      ncmpcpp.enable = true;
      emulators.gc.enable = true;
      steam.enable = true;
      lutris.enable = true;
    };
  };

  # Monitor backlight control
  programs.light.enable = true;

  services.tlp.enable = true;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.tuxedo-drivers.enable = true;
  hardware.tuxedo-rs = {
    enable = true;
    tailor-gui.enable = true;
  };

  hardware = {
    bluetooth = {
      enable = true;
      # Enable A2DP Sink
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };
  };

  networking.networkmanager.enable = true;

  services.blueman.enable = true;

  services.logind.settings.Login.HandleLidSwitch = "ignore";

  user.name = "phfroidmont";

  home-manager.users.${config.user.name} =
    { ... }:
    {
      services.network-manager-applet.enable = true;
      services.blueman-applet.enable = true;
      wayland.windowManager.hyprland.settings = {
        env = [
          "LIBVA_DRIVER_NAME,nvidia"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        ];

        workspace = [
          "w[tv1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ];
        windowrulev2 = [
          "bordersize 0, floating:0, onworkspace:w[tv1]"
          "rounding 0, floating:0, onworkspace:w[tv1]"
          "bordersize 0, floating:0, onworkspace:f[1]"
          "rounding 0, floating:0, onworkspace:f[1]"
        ];
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

  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    listenAddresses = [
      {
        # Tailscale interface
        addr = "100.64.0.5";
        port = 22;
      }
    ];
  };
  users.users.${config.user.name} = {
    openssh.authorizedKeys.keyFiles = [
      ../../ssh_keys/phfroidmont-desktop.pub
      ../../ssh_keys/phfroidmont-laptop.pub
    ];
    extraGroups = [ "video" ];
  };

  system.stateVersion = "25.05";
}
