{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../configs/system.nix
    ../../configs/user.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "froidmpa-linux";
    networkmanager.enable = true;
  };

  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp2s0.useDHCP = true;

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

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";

  services.blueman.enable = true;

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    home.packages = with pkgs; [
      slack-dark
    ];
    services.network-manager-applet.enable = true;
    services.blueman-applet.enable = true;
  };
  # Enable touchpad support.
  services.xserver.libinput.enable = true;
}

