{ config, lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    jdk14
    jetbrains.idea-community
    jetbrains.idea-ultimate
    maven
    sbt
    geckodriver
  ];
}
