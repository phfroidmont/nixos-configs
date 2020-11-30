{ config, lib, pkgs, ... }:
{
  imports = [
    <home-manager/nixos>
    ./hardware-configuration.nix
    ../../configs/system.nix
    ../../configs/network.nix
    ../../configs/virtualisation.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices = {
    crypted = {
      device = "/dev/disk/by-uuid/50f8d5be-eabc-4b80-a36f-b8e5646c4fc1";
      preLVM = true;
    };
  };

  networking = {
    hostName = "enix016";
    networkmanager.enable = true;
  };

  networking.interfaces.wlp59s0.useDHCP = true;

  console = {
    font = "Lat2-Terminus16";
    keyMap = "fr";
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  time.timeZone = "Europe/Amsterdam";

  environment.etc."openfortivpn/config" = {
    text = ''
      host = devsslvpn.global.ingenico.com
      port = 443
      trusted-cert = e09de6da3902e58b9061f28e13d33088d929f3451367d21f1721a0ed6361a883
      trusted-cert = 33069b6d904330b3fde5c002ca4964b7f413003665e78963d73098fe5f6f7c05
      trusted-cert = 599dba9bee8a920836b68ca5603a11ceee5ec0450201c7a7651f5575d6bbcd3a
      set-dns = 0
      set-routes = 1
      insecure-ssl = 0
      cipher-list = HIGH:!aNULL:!kRSA:!PSK:!SRP:!MD5:!RC4
    '';
  };

  hardware.bluetooth = {
    enable = true;
    # Enable A2DP Sink
    extraConfig = "
      [General]
      Enable=Source,Sink,Media,Socket
    ";
  };
  hardware.pulseaudio = {
    enable = true;

    # Use full build to have Bluetooth support
    package = pkgs.pulseaudioFull;
  };

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    imports = [
      ../../configs/home/full.nix
    ];
    services = {
      network-manager-applet.enable = true;
      blueman-applet.enable = true;
      grobi = {
        enable = true;
        executeAfter = ["${pkgs.systemd}/bin/systemctl --user restart stalonetray" "${pkgs.feh}/bin/feh --bg-fill ~/.wallpaper.png"];
        rules = [
          {
            name = "Work HDMI";
            outputs_connected = [ "HDMI-1" ];
            configure_single = "HDMI-1";
            primary = true;
            atomic = true;
          }
          {
            name = "Work USBC";
            outputs_connected = [ "DP-1" ];
            configure_single = "DP-1";
            primary = true;
            atomic = true;
          }
          {
            name = "Fallback";
            configure_single = "eDP-1";
          }
        ];
      };
      gpg-agent = {
        enable = true;
        enableSshSupport = true;
        #pinentryFlavor = "tty";
      };
    };

    programs = {
      git = {
        enable = true;
        userName  = "Paul-Henri Froidmont";
        userEmail = "paul-henri.froidmont@ingenico.com";
        signing = {
          key = "589ECB6FAA8FF1F40E579C9E1479473F99393013";
          signByDefault = true;
        };
      };
      gpg.enable = true;
    };
  };
  # Enable touchpad support.
  services.xserver.libinput.enable = true;

  system.stateVersion = "20.09";
}

