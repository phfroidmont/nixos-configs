{ config, lib, pkgs, ... }:
{
  hardware.opengl.driSupport32Bit = true;
  home-manager.users.froidmpa = {pkgs, config, ...}: {
    home.packages = with pkgs; [
      steam
      lutris
      vulkan-tools
    ];
  };
}
