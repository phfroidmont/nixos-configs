{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../configs/system.nix
    ../../configs/network.nix
    ../../configs/virtualisation.nix
    ../../configs/games.nix
  ];

  # Required, otherwise the kernel freezes on boot
  boot.kernelParams = [ "nomodeset" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "froidmpa-laptop";
    networkmanager.enable = true;
  };

  networking.interfaces.enp2s0.useDHCP = true;
  networking.interfaces.wlo1.useDHCP = true;

  console = {
    font = "Lat2-Terminus16";
    keyMap = "fr";
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  time.timeZone = "Europe/Amsterdam";

  environment.systemPackages = with pkgs; [
  ];

  hardware.bluetooth = {
    enable = true;
    # Enable A2DP Sink
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
  hardware.pulseaudio = {
    enable = true;

    # Use full build to have Bluetooth support
    package = pkgs.pulseaudioFull;
  };
  services.blueman.enable = true;

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    imports = [
      ../../configs/home/full.nix
    ];
    programs.git = {
      enable = true;
      userName  = "Paul-Henri Froidmont";
      userEmail = "git.contact-57n2p@froidmont.org";
    };
    services.network-manager-applet.enable = true;
    services.blueman-applet.enable = true;
    services.grobi = {
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
  };
  # Enable touchpad support.
  services.xserver.libinput.enable = true;

  system.stateVersion = "21.05"; # Did you read the comment?
}
