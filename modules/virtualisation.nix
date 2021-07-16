{ config, lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  virtualisation = {
    virtualbox.host.enable = true;
    virtualbox.host.enableExtensionPack = true;
    docker.enable = true;
  };
  users.users.froidmpa.extraGroups = [ "docker" "vboxusers" ];

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
