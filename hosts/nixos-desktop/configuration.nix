{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../configs/system.nix
    ../../configs/user.nix
    ../../configs/network.nix
    ../../configs/virtualisation.nix
    ../../configs/dev.nix
    ../../configs/games.nix
  ];

  fileSystems."/home/froidmpa/Nextcloud" = {
    device = "/dev/disk/by-uuid/a4ba8b21-ea33-4487-b6f6-9bb7470a0acb";
    fsType = "ext4";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-desktop";
  networking.interfaces.enp31s0.useDHCP = true;

  console = {
    font = "Lat2-Terminus16";
    keyMap = "fr";
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  time.timeZone = "Europe/Amsterdam";

  services.xserver.videoDrivers = ["amdgpu"];
  services.sshd.enable = true;
  environment.systemPackages = with pkgs; [
  ];
}
