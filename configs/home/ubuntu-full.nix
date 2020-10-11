{ config, lib, pkgs, ... }:
{
  imports = [
    ./cli.nix
    ./xmonad.nix
    ./gui.nix
    ./dev.nix
    ./email.nix
  ];
}
