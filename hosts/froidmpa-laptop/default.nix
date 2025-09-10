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
    };
  };

  user.name = "froidmpa";

  # Monitor backlight control
  programs.light.enable = true;

  services.tlp.enable = true;

  home-manager.users.${config.user.name} =
    { ... }:
    {
      services.network-manager-applet.enable = true;
      services.blueman-applet.enable = true;
      wayland.windowManager.hyprland.settings = {
        monitor = [
          "eDP-1, 1920x1080, 0x720, 1.5"
          "DP-1, 1920x1080, 0x0, 1.5"
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
        addr = "100.64.0.1";
        port = 22;
      }
    ];
  };
  users.users.${config.user.name} = {
    openssh.authorizedKeys.keyFiles = [
      ../../ssh_keys/phfroidmont-desktop.pub
      ../../ssh_keys/phfroidmont-stellaris.pub
    ];
    extraGroups = [ "video" ];
  };

  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "hel1.banditlair.com";
        sshUser = "nix-ssh";
        system = "x86_64-linux";
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
      }
    ];
    settings = {
      substituters = [ "ssh://nix-ssh@hel1.banditlair.com" ];
      trusted-public-keys = [ "hel1.banditlair.com:stzB4xe5QTFvSABoP11ZpNzLDCRZ93PExk0Z/gOzW3g=" ];
      builders-use-substitutes = true;
    };
  };
  system.stateVersion = "21.05";
}
