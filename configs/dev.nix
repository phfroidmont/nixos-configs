{ config, lib, pkgs, ... }:
{
  home-manager.users.froidmpa = {pkgs, config, ...}: {
    nixpkgs.config.allowUnfree = true;
    home.packages = with pkgs; [
      jdk
      jetbrains.idea-ultimate
      maven
      geckodriver
    ];
  };
}
