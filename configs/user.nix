{ config, pkgs, ... }:
{
  imports = [
    <home-manager/nixos>
  ];

  home-manager.users.froidmpa = {pkgs, config, ...}: {
    imports = [
      ./cli.nix
      ./xmonad.nix
      ./gui.nix
    ];
  };

  system.stateVersion = "19.09";
}

