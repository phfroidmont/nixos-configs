{ config, lib, pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./xmonad.nix
    ./gui.nix
    ./dev.nix
  ];

  home.packages = with pkgs; [
    i3lock
  ];
}
