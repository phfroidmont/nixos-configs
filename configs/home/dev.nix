{ config, lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    openjdk15
    jetbrains.idea-community
    jetbrains.idea-ultimate
    maven
    sbt
    geckodriver
  ];
}
