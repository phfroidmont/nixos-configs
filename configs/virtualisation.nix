{ config, lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  virtualisation = {
    virtualbox.host.enable = true;
    virtualbox.host.enableExtensionPack = true;
    docker.enable = true;
  };
  users.users.froidmpa.extraGroups = [ "docker" "vboxusers" ];

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    home.packages = with pkgs; [
      docker-compose
    ];
  };
}
