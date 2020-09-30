{ config, lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    jdk11
    jetbrains.idea-ultimate
    maven
    sbt
    geckodriver
  ];
}
