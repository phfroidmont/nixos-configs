{ config, lib, pkgs, ... }:
{
  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
  users.users.froidmpa.extraGroups = [ "docker" "libvirtd" ];

  environment.systemPackages = with pkgs; [
    docker-compose
    virt-manager
  ];
}
