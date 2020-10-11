{ config, lib, pkgs, ... }:
{
  imports = [
    <home-manager/nixos>
    ./hardware-configuration.nix
    ../../configs/system.nix
    ../../configs/network.nix
    ../../configs/virtualisation.nix
  ];

  # Use older kernel thanks to Intel
  boot.kernelPackages = pkgs.linuxPackages_4_19;
  boot.kernelParams = [ "intel_idle.max_cstate=1" ];
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
  services.blueman.enable = true;

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    imports = [
      ../../configs/home/full.nix
    ];
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

  fileSystems."/home/froidmpa/Projectlib" = {
    device = "//fs-common.aris-lux.lan/projectlib";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
  };
  fileSystems."/home/froidmpa/Projectlib2" = {
    device = "//fs-projects.aris-lux.lan/projectlib2";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
  };
  fileSystems."/home/froidmpa/NetworkDrive" = {
    device = "//fs-users.aris-lux.lan/users/froidmpa";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=/etc/nixos/smb-secrets"];
  };

  system.stateVersion = "19.09";
}

