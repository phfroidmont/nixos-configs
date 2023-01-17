{ config, lib, pkgs, pkgs-unstable, ... }:
{
  services.pcscd.enable = true;
  environment.systemPackages = with pkgs-unstable; [
    eid-mw
  ];
}
